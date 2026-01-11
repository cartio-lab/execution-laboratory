#!/bin/bash
# -------------------------------------------------------------------------
# Autor:       Wagner P Calazans
# Versão:      6.1 (HDD Edition - Standard Path Fix)
# Descrição:   Gerenciador OpenLDAP Master SSL.
#              - Executa como ROOT (para evitar erros de permissão de arquivo).
#              - Usa caminhos PADRÃO (/var/lib/ldap) para passar pelo AppArmor.
# -------------------------------------------------------------------------

# --- CONFIGURAÇÕES ---
# USANDO CAMINHOS PADRÃO (AppArmor Whitelist)
CERT_DIR="/etc/ldap/ssl"
CERT_FILE="$CERT_DIR/server.crt"
KEY_FILE="$CERT_DIR/server.key"

CONF_FILE="/etc/ldap/slapd.root.conf"

# MUDANÇA CRÍTICA: Voltamos para a pasta padrão que o AppArmor confia
DATA_DIR="/var/lib/ldap"

# Credenciais
SUFFIX="dc=carto,dc=org"
ROOT_DN="cn=admin,dc=carto,dc=org"
ROOT_PW="33028729"

# Diretórios do Sistema
SCHEMA_DIR="/etc/ldap/schema"
MODULE_DIR="/usr/lib/ldap"

log_msg() { echo -e "\033[1;32m[$(date +'%H:%M:%S')] $1\033[0m"; }
err_msg() { echo -e "\033[1;31m[ERRO] $1\033[0m"; }

if [ "$EUID" -ne 0 ]; then err_msg "Precisa ser root."; exit 1; fi

# ============================================================
# 1. PREPARAÇÃO
# ============================================================
stop_services() {
    systemctl stop slapd
    pkill -9 slapd >/dev/null 2>&1
    sleep 2
}

prepare_dirs() {
    log_msg "Limpando diretórios..."
    
    # Limpa diretório de dados PADRÃO
    # ATENÇÃO: Isso apaga qualquer banco anterior
    rm -rf "$DATA_DIR"/*
    if [ ! -d "$DATA_DIR" ]; then mkdir -p "$DATA_DIR"; fi
    
    # Limpa e recria diretório de certificados
    rm -rf "$CERT_DIR"
    mkdir -p "$CERT_DIR"
    
    # DB_CONFIG
    echo "set_cachesize 0 2097152 0" > "$DATA_DIR/DB_CONFIG"
}

generate_certs() {
    log_msg "Gerando certificados..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=BR/ST=RJ/L=Saquarema/O=IME/CN=carto.org" 2>/dev/null

    # Permissões (Root Mode)
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
}

generate_config() {
    log_msg "Gerando configuração..."
    
    cat > "$CONF_FILE" <<EOF
include $SCHEMA_DIR/core.schema
include $SCHEMA_DIR/cosine.schema
include $SCHEMA_DIR/nis.schema
include $SCHEMA_DIR/inetorgperson.schema

pidfile     /var/run/slapd_root.pid
argsfile    /var/run/slapd_root.args

modulepath $MODULE_DIR
moduleload back_mdb

# --- SSL ---
TLSCertificateFile    $CERT_FILE
TLSCertificateKeyFile $KEY_FILE
TLSCipherSuite        NORMAL
TLSVerifyClient       never
TLSCRLCheck           none

access to *
    by dn.exact="$ROOT_DN" write
    by * read

# --- DATABASE ---
database    mdb
maxsize     1073741824
suffix      "$SUFFIX"
rootdn      "$ROOT_DN"
rootpw      "$ROOT_PW"
directory   "$DATA_DIR"   # Agora aponta para /var/lib/ldap (Permitido pelo AppArmor)

index objectClass eq
index cn,uid eq
index uidNumber,gidNumber eq
index member,memberUid eq
EOF
}

# ============================================================
# 2. INICIALIZAÇÃO
# ============================================================
start_master() {
    stop_services
    prepare_dirs
    generate_certs
    generate_config
    
    log_msg "Iniciando SLAPD como ROOT (Portas 389 + 636)..."
    
    # Roda como root, usando a pasta padrão
    slapd -f "$CONF_FILE" -h "ldap:/// ldaps:///"
    
    sleep 2
    
    if pgrep -f "$CONF_FILE" >/dev/null; then
        log_msg "Servidor Online!"
        check_ssl
    else
        err_msg "Falha na inicialização."
        echo "LOG DE DEBUG:"
        slapd -d 1 -f "$CONF_FILE" -h "ldap:/// ldaps:///"
    fi
}

check_ssl() {
    log_msg "Testando SSL..."
    echo | timeout 2 openssl s_client -connect localhost:636 2>/dev/null | grep -q "BEGIN CERTIFICATE"
    if [ $? -eq 0 ]; then
         log_msg "SUCESSO: SSL OK!"
         populate_base
    else
         err_msg "SSL Falhou."
    fi
}

populate_base() {
    log_msg "Populando base..."
    LDAPTLS_REQCERT=allow ldapadd -x -H ldaps://localhost -D "$ROOT_DN" -w "$ROOT_PW" <<EOF >/dev/null 2>&1
dn: $SUFFIX
objectClass: top
objectClass: dcObject
objectClass: organization
o: Carto Org
dc: carto

dn: ou=People,$SUFFIX
objectClass: organizationalUnit
ou: People
EOF
}

# ============================================================
# MENU
# ============================================================
clear
echo "========================================================"
echo "   GERENCIADOR MASTER HDD (v6.1 Fix)"
echo "========================================================"
echo "1) INICIAR (Wipe + Root + SSL)"
echo "2) Parar"
echo "0) Sair"
echo "========================================================"
read -p "Opção: " OPT
case $OPT in
    1) start_master ;;
    2) stop_services ;;
    0) exit 0 ;;
esac
