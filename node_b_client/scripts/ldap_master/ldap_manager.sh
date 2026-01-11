#!/bin/bash
# -------------------------------------------------------------------------
# Autor:       Wagner P Calazans
# Versão:      4.0 (Com Função de Limpeza/Reset)
# Descrição:   Gerenciador OpenLDAP.
#              - Alterna entre Standalone e Systemd.
#              - Verifica dbnosync e permissões.
#              - Auto-população da base (dc=carto,dc=org).
#              - NOVO: Opção de limpar a base (Reset) para novos testes.
# -------------------------------------------------------------------------

# --- Configurações e Credenciais ---
LDAP_CONF="/etc/ldap/slapd.standalone.conf"
LDAP_URLS="ldap://0.0.0.0/ ldaps:///"
SUFFIX="dc=carto,dc=org"
ROOT_DN="cn=admin,dc=carto,dc=org"
ROOT_PW="33028729"
DATA_DIR="/var/lib/ldap"

# Função para logs formatados
log_msg() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# Verificação de Root
if [ "$EUID" -ne 0 ]; then
  echo "ERRO: Este script precisa ser executado como root."
  exit 1
fi

# Função: Inserir Dados Iniciais se Necessário
check_and_populate_base() {
    log_msg "Verificando existência do objeto raiz ($SUFFIX)..."
    
    # Tenta ler o objeto raiz
    ldapsearch -x -H ldap://localhost -D "$ROOT_DN" -w "$ROOT_PW" -b "$SUFFIX" -s base "(objectClass=*)" > /dev/null 2>&1
    RET=$?

    if [ $RET -eq 32 ]; then
        log_msg "AVISO: Base vazia (Erro 32). Criando estrutura inicial..."
        
        # Cria ficheiro LDIF temporário
        cat > /tmp/base_init.ldif <<EOF
dn: $SUFFIX
objectClass: top
objectClass: dcObject
objectClass: organization
o: Carto Org
dc: carto
EOF

        # Adiciona ao LDAP
        ldapadd -x -H ldap://localhost -D "$ROOT_DN" -w "$ROOT_PW" -f /tmp/base_init.ldif > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            log_msg "SUCESSO: Estrutura inicial ($SUFFIX) criada!"
        else
            log_msg "ERRO: Falha ao criar estrutura inicial."
        fi
        rm /tmp/base_init.ldif
        
    elif [ $RET -eq 0 ]; then
        log_msg "OK: A estrutura inicial já existe."
    else
        log_msg "ERRO: Problema de conexão (Código de retorno: $RET)."
    fi
}

# Função de Teste Final
test_ldap_connection() {
    echo "-----------------------------------------------------------"
    log_msg "Teste Final de Conectividade:"
    
    ldapsearch -x -H ldap://localhost -D "$ROOT_DN" -w "$ROOT_PW" -b "$SUFFIX" -s base dn > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_msg "SUCESSO TOTAL: Serviço ativo e base populada."
        # Exibe o resultado visualmente
        ldapsearch -x -H ldap://localhost -D "$ROOT_DN" -w "$ROOT_PW" -b "$SUFFIX" -s base dn | grep "dn:"
    else
        log_msg "ERRO FINAL: O serviço roda, mas a busca falhou."
    fi
    echo "-----------------------------------------------------------"
}

# Função para Parar Tudo
stop_services() {
    log_msg "Parando todos os serviços LDAP..."
    systemctl stop slapd
    pkill -9 slapd > /dev/null 2>&1
}

# Função para Limpar Base (WIPE)
wipe_database() {
    log_msg ">>> EXECUTANDO LIMPEZA TOTAL DA BASE DE DADOS <<<"
    stop_services
    
    if [ -d "$DATA_DIR" ]; then
        # Remove arquivos de base de dados (.mdb, .bdb, log.*, __db.*)
        # Mantém a pasta, apaga o conteúdo
        rm -f "$DATA_DIR"/* 2>/dev/null
        log_msg "Arquivos em $DATA_DIR foram apagados."
    else
        mkdir -p "$DATA_DIR"
        log_msg "Diretório $DATA_DIR criado."
    fi
    
    # Ajusta permissões caso necessário (se rodar como openldap)
    # chown -R openldap:openldap "$DATA_DIR"
    
    log_msg "Limpeza concluída. Reiniciando em modo Standalone..."
    start_standalone
}

# Função para Modo Standalone
start_standalone() {
    log_msg ">>> Iniciando configuração para MODO STANDALONE <<<"

    stop_services
    
    if [ ! -f "$LDAP_CONF" ]; then
        log_msg "ERRO CRÍTICO: Arquivo $LDAP_CONF não encontrado."
        return
    fi

    if grep -q "dbnosync" "$LDAP_CONF"; then
        log_msg "CHECK: Diretiva 'dbnosync' detectada."
    else
        log_msg "AVISO: Diretiva 'dbnosync' NÃO encontrada."
    fi

    slapd -f "$LDAP_CONF" -h "$LDAP_URLS"
    
    PID_CHECK=$(pgrep -f "slapd -f $LDAP_CONF")

    if [ -n "$PID_CHECK" ]; then
        log_msg "Processo Slapd iniciado (PID: $PID_CHECK)."
        sleep 2
        check_and_populate_base
        test_ldap_connection
    else
        log_msg "ERRO: O processo slapd não iniciou."
    fi
}

# Função para Modo Padrão
start_standard() {
    log_msg ">>> Iniciando configuração para MODO PADRÃO (Systemd) <<<"

    if pgrep -f "slapd -f" > /dev/null; then
        pkill -f "slapd -f"
    fi

    systemctl start slapd
    
    if systemctl is-active --quiet slapd; then
        log_msg "Serviço Systemd iniciado."
        sleep 2
        check_and_populate_base
        test_ldap_connection
    else
        log_msg "ERRO: Falha ao iniciar Systemd."
    fi
}

# --- Menu Principal ---
clear
echo "========================================================"
echo "   Gerenciador OpenLDAP - Wagner P Calazans"
echo "========================================================"
echo "1) STANDALONE (Iniciar com dados atuais)"
echo "2) PADRÃO (Systemd Default)"
echo "3) LIMPAR BASE (Wipe Total e Reiniciar Standalone)"
echo "0) Sair"
echo "========================================================"
read -p "Opção: " OPTION

case $OPTION in
    1) start_standalone ;;
    2) start_standard ;;
    3) wipe_database ;;
    0) exit 0 ;;
    *) echo "Opção inválida." ;;
esac

ldapadd -x -H ldap://172.16.102.100 -D "cn=admin,dc=carto,dc=org" -w "33028729" <<EOF
dn: ou=People,dc=carto,dc=org
objectClass: organizationalUnit
ou: People
EOF
