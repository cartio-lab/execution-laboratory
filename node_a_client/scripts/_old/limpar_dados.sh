#!/bin/bash

# --- CONFIGURAÇÕES ---
# Roda a limpeza no LDAP-A (a exclusão será replicada)
LDAP_SERVER="172.16.101.100" 
ADMIN_DN="cn=admin,dc=carto,dc=org"
ADMIN_PASS="33028729" # <-- Coloque sua senha do admin aqui
BASE_DN="dc=carto,dc=org"
# ---------------------

echo "--- Iniciando Limpeza de Usuários de user ---"

# 1. Buscar o DN (Distinguished Name) de todos os usuários
#    Filtro: (uid=user*) - Pega todos que começam com "user"
#    Atributo: 'dn' - Queremos apenas o DN
echo "Buscando DNs dos usuários de user (uid=user*)..."

# ldapsearch ... | grep ... | awk ...
# O 'awk' pega apenas o DN (ex: "uid=user1,dc=carto,dc=org")
# O 'tr' transforma a lista de linhas em uma única linha separada por espaços
DN_LIST=$(ldapsearch -x -D "$ADMIN_DN" -w "$ADMIN_PASS" -H ldap://$LDAP_SERVER -b $BASE_DN "(uid=user*)" dn | grep '^dn:' | awk '{print $2}' | tr '\n' ' ')

if [ -z "$DN_LIST" ]; then
    echo "Nenhum usuário de user (uid=user*) encontrado para limpar."
    echo "Limpeza concluída."
    exit 0
fi

# echo "DNs encontrados: $DN_LIST" # (Descomente esta linha para depurar)

# 2. Executar o ldapdelete em massa
#    Passamos a lista inteira de DNs de uma vez para o comando
echo "Deletando usuários encontrados..."
ldapdelete -x -H ldap://$LDAP_SERVER -D "$ADMIN_DN" -w "$ADMIN_PASS" $DN_LIST

if [ $? -eq 0 ]; then
    echo "Sucesso! Usuários de user removidos."
else
    echo "Erro durante a remoção. Verifique a senha ou os DNs."
fi

echo "Limpeza concluída."
