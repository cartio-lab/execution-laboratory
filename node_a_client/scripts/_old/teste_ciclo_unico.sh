#!/bin/bash
# ==============================================================================
# SCRIPT: TESTE DE CICLO ÚNICO (ADD -> MOD -> DEL) - REFINADO
# ==============================================================================

# --- CONFIGURAÇÕES ---
LDAP_A="172.16.101.100"
LDAP_B="172.16.102.100"
ADMIN_DN="cn=admin,dc=carto,dc=org"
ADMIN_PASS="33028729"
BASE_DN="dc=carto,dc=org"

ID_TESTE=$(date +%s)
USER_UID="ciclo-unico-$ID_TESTE"
USER_DN="uid=$USER_UID,$BASE_DN"

echo "============================================================"
echo "   TESTE DE CICLO DE VIDA ÚNICO (LDAP A -> B)"
echo "   Alvo: $USER_DN"
echo "============================================================"

# 1. ADIÇÃO
echo -n "--- 1. ADIÇÃO: Inserindo no LDAP-A... "
ldapadd -x -H ldap://$LDAP_A -D "$ADMIN_DN" -w "$ADMIN_PASS" <<EOF > /dev/null 2>&1
dn: $USER_DN
objectClass: inetOrgPerson
uid: $USER_UID
cn: Teste Ciclo $ID_TESTE
sn: Teste
description: original
EOF

START_ADD=$(date +%s%N)
while true; do
    ldapsearch -x -H ldap://$LDAP_B -b "$USER_DN" -LLL uid > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        END_ADD=$(date +%s%N)
        break
    fi
    sleep 0.01
done
LAG_ADD=$(echo "scale=2; ($END_ADD - $START_ADD) / 1000000" | bc -l)
printf "OK na Réplica (%.2f ms)\n" $LAG_ADD

# 2. MODIFICAÇÃO
NOVO_VALOR="modificado-$ID_TESTE-$(date +%s%N)"
echo -n "--- 2. MODIFICAÇÃO: Alterando no LDAP-A... "
ldapmodify -x -H ldap://$LDAP_A -D "$ADMIN_DN" -w "$ADMIN_PASS" <<EOF > /dev/null 2>&1
dn: $USER_DN
changetype: modify
replace: description
description: $NOVO_VALOR
EOF

START_MOD=$(date +%s%N)
while true; do
    if ldapsearch -x -H ldap://$LDAP_B -b "$USER_DN" -LLL description | grep -q "$NOVO_VALOR"; then
        END_MOD=$(date +%s%N)
        break
    fi
    sleep 0.01
done
LAG_MOD=$(echo "scale=2; ($END_MOD - $START_MOD) / 1000000" | bc -l)
printf "OK na Réplica (%.2f ms)\n" $LAG_MOD

# 3. REMOÇÃO
echo -n "--- 3. REMOÇÃO: Deletando no LDAP-A... "
ldapdelete -x -H ldap://$LDAP_A -D "$ADMIN_DN" -w "$ADMIN_PASS" "$USER_DN" > /dev/null 2>&1
START_DEL=$(date +%s%N)

while true; do
    ldapsearch -x -H ldap://$LDAP_B -b "$USER_DN" -LLL uid > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        END_DEL=$(date +%s%N)
        break
    fi
    sleep 0.01
done
LAG_DEL=$(echo "scale=2; ($END_DEL - $START_DEL) / 1000000" | bc -l)
printf "Sumiu na Réplica (%.2f ms)\n" $LAG_DEL

echo "============================================================"
echo "   RESUMO DO CICLO"
echo "============================================================"
printf "ADIÇÃO:      %8.2f ms\n" $LAG_ADD
printf "MODIFICAÇÃO: %8.2f ms\n" $LAG_MOD
printf "REMOÇÃO:     %8.2f ms\n" $LAG_DEL
echo "============================================================"
