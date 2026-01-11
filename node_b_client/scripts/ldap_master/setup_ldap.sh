#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: setup_ldap-b.sh
# Descrição: Sobe a instalação do LDAP toda para a memória RAM
# ============================================================
set -e

echo "--- 1. Parando LDAP (B) ---"
systemctl stop slapd

echo "--- 2. Limpando CONFIGURAÇÃO Antiga ---"
rm -rf /etc/ldap/slapd.d/*
mkdir -p /etc/ldap/slapd.d
chown -R openldap:openldap /etc/ldap/slapd.d

echo "--- 3. Limpando DADOS na RAM ---"
rm -rf /var/lib/ldap/*
# O Consumer NÃO precisa da pasta accesslog, pois ele só lê.
chown -R openldap:openldap /var/lib/ldap

echo "--- 4. Restaurando Configuração Básica ---"
# ATENÇÃO: Aqui carregamos SÓ a config. NÃO carregamos usuários.
# Os usuários virão pela rede da Máquina A.
sudo -u openldap slapadd -n 0 -F /etc/ldap/slapd.d -l /opt/ldap_backups/backup_config.ldif

echo "--- 5. Iniciando LDAP ---"
systemctl start slapd
sleep 3

echo "--- 6. Conectando na Máquina A (Ativando Syncrepl) ---"
ldapmodify -Y EXTERNAL -H ldapi:/// -f /opt/ldap_backups/config_consumer.ldif

echo "--- 7. Ajustando Performance (SizeLimit 10.000) ---"
# Aplica o aumento do limite de pesquisa para evitar travamento em 500
cat <<EOF | ldapmodify -Y EXTERNAL -H ldapi:/// > /dev/null
dn: cn=config
changetype: modify
replace: olcSizeLimit
olcSizeLimit: 10000
EOF

echo "--- PRONTO: MÁQUINA B (Sincronizando...) ---"
