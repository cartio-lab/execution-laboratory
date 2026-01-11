#!/bin/bash
# -------------------------------------------------------------------------
# Autor:       Wagner P Calazans
# Versão:      1.0
# Descrição:   Este script realiza a parada do serviço systemd do OpenLDAP,
#              inicia o processo em modo standalone utilizando o arquivo
#              /etc/ldap/slapd.standalone.conf, verifica a presença da
#              diretiva dbnosync e valida a conectividade com credenciais.
# -------------------------------------------------------------------------

# Definição de Variáveis
LDAP_CONF="/etc/ldap/slapd.standalone.conf"
LDAP_URLS="ldap:/// ldaps:///"
SUFFIX="dc=carto,dc=org"
ROOT_DN="cn=admin,dc=carto,dc=org"
ROOT_PW="33028729"

# Função para exibir mensagens com formatação simples
log_msg() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# Verificação de privilégios de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script como root."
  exit 1
fi

# 1. Parar o serviço padrão do OpenLDAP (slapd)
log_msg "Parando o serviço systemd do OpenLDAP..."
systemctl stop slapd
if [ $? -eq 0 ]; then
    log_msg "Serviço parado com sucesso."
else
    log_msg "ERRO: Falha ao parar o serviço slapd ou ele já estava parado."
fi

# 2. Verificar se o arquivo de configuração existe
if [ ! -f "$LDAP_CONF" ]; then
    log_msg "ERRO: O arquivo de configuração $LDAP_CONF não foi encontrado."
    exit 1
fi

# 3. Conferir se dbnosync está ativo na configuração
log_msg "Verificando a diretiva 'dbnosync' no arquivo de configuração..."
if grep -q "dbnosync" "$LDAP_CONF"; then
    log_msg "OK: Diretiva 'dbnosync' encontrada em $LDAP_CONF."
else
    log_msg "AVISO: A diretiva 'dbnosync' NÃO foi encontrada no arquivo $LDAP_CONF."
fi

# 4. Subir o LDAP em modo Standalone
log_msg "Iniciando slapd em modo standalone..."
# O comando abaixo inicia o slapd em background com o arquivo específico
slapd -f "$LDAP_CONF" -h "$LDAP_URLS"

# Aguarda alguns segundos para garantir que o processo subiu e fez bind nas portas
sleep 3

# 5. Confirmar se o serviço (processo) está ativo
# Nota: Como subimos manualmente, systemctl status não mostrará 'active'.
# Devemos checar a lista de processos ou a porta.
PID_LDAP=$(pgrep -f "slapd -f $LDAP_CONF")

if [ -n "$PID_LDAP" ]; then
    log_msg "SUCESSO: O processo slapd está rodando (PID: $PID_LDAP)."
else
    log_msg "ERRO CRÍTICO: O processo slapd não está rodando após a tentativa de início."
    log_msg "Verifique os logs do sistema ou a sintaxe do arquivo .conf."
    exit 1
fi

# 6. Teste funcional (ldapsearch)
log_msg "Realizando teste de conexão e busca no diretório..."

ldapsearch -x -H ldap://localhost -D "$ROOT_DN" -w "$ROOT_PW" -b "$SUFFIX" -s base "(objectClass=*)" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    log_msg "TESTE FINAL: Conexão bem-sucedida! O LDAP respondeu corretamente para $ROOT_DN."
    
    # Opcional: Exibir uma busca simples para confirmação visual
    echo "--- Resultado da busca na base (Root DSE) ---"
    ldapsearch -x -H ldap://localhost -D "$ROOT_DN" -w "$ROOT_PW" -b "$SUFFIX" -s base dn
else
    log_msg "ERRO NO TESTE: Não foi possível conectar ou autenticar no LDAP."
    log_msg "Verifique se a senha ou o sufixo estão corretos no arquivo de configuração."
fi

echo "-------------------------------------------------------------------------"
echo "Execução do script finalizada."
