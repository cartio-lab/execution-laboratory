#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: setup_ldap-a.sh
# Descrição: Sobe a instalação do LDAP toda para a memória RAM
# ============================================================
set -e

echo "--- 1. Parando LDAP ---"
systemctl stop slapd

echo "--- 1.5. Limpando CONFIGURAÇÃO Antiga (O passo que faltava) ---"
# ATENÇÃO: Isto apaga a configuração atual para permitir o restore
rm -rf /etc/ldap/slapd.d/*
# Garante que a pasta existe e pertence ao user certo
mkdir -p /etc/ldap/slapd.d
chown -R openldap:openldap /etc/ldap/slapd.d

echo "--- 2. Limpando DADOS na RAM ---"
rm -rf /var/lib/ldap/*
# Recria pastas necessárias
mkdir -p /var/lib/ldap/accesslog
chown -R openldap:openldap /var/lib/ldap

echo "--- 3. Restaurando Base ---"
# Agora sim, a pasta slapd.d está vazia e o comando vai funcionar
sudo -u openldap slapadd -n 0 -F /etc/ldap/slapd.d -l /opt/ldap_backups/backup_config.ldif
sudo -u openldap slapadd -n 1 -l /opt/ldap_backups/backup_users_base.ldif

echo "--- 4. Iniciando LDAP ---"
systemctl start slapd

# Se for a máquina A, mantenha a parte de aplicar o Provider aqui em baixo.
# Se for a B, mantenha a parte do Consumer.
# Exemplo para a Máquina A (Provider):
sleep 3
# echo "--- 5. Aplicando Configuração de Replicação ---"
ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/ldap_backups/config_provider.ldif

echo "--- 6. Ajustando Performance (SizeLimit 10.000) ---"
# Aplica o aumento do limite de pesquisa para evitar travamento em 500
cat <<EOF | ldapmodify -Y EXTERNAL -H ldapi:/// > /dev/null
dn: cn=config
changetype: modify
replace: olcSizeLimit
olcSizeLimit: 10000
EOF


echo "--- Ambiente Pronto na RAM! ---"
