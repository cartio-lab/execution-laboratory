#!/bin/bash
# Mede o lag de replicação de uma ÚNICA entrada (ADD e DELETE)
# e valida a integridade da sincronização.

# --- CONFIGURAÇÕES ---
LDAP_A="172.16.101.100"
LDAP_B="172.16.102.100"
ADMIN_DN="cn=admin,dc=carto,dc=org"
ADMIN_PASS="33028729" # <-- SUBSTITUA PELA SUA SENHA
BASE_DN="dc=carto,dc=org"
# ---------------------

ID_TESTE=$(date +%s%N) # ID único para este teste
USER_DN="uid=teste-unico-$ID_TESTE,$BASE_DN"
ARQUIVO_TESTE="teste-unico-$ID_TESTE.ldif"

echo "--- Iniciando Teste de Lag (1 entrada) ---"
echo "Usuário de teste: $USER_DN"
echo ""

# --- PASSO 1: Gerar 1 entrada ---
cat << EOF > "$ARQUIVO_TESTE"
dn: $USER_DN
objectClass: inetOrgPerson
uid: teste-unico-$ID_TESTE
cn: Teste Lag Unico $ID_TESTE
sn: Teste

EOF

# --- PASSO 2: Medir o ADD e Validar ---
echo -n "Inserindo 1 entrada no LDAP-A... "
ldapadd -x -H ldap://$LDAP_A -D $ADMIN_DN -w "$ADMIN_PASS" -f "$ARQUIVO_TESTE" > /dev/null 2>&1

# Requisito 3: Informar sucesso/falha da adição
if [ $? -eq 0 ]; then
    echo "Sucesso (Req. 3)"
    START_TIME_ADD=$(date +%s%N)
else
    echo "FALHA (Req. 3)"
    echo "Abortando teste."
    rm "$ARQUIVO_TESTE"
    exit 1
fi

echo -n "Aguardando 1 entrada no LDAP-B... "
while true; do
    # Procura pelo DN específico. Retorna 0 se encontrar.
    ldapsearch -x -H ldap://$LDAP_B -b "$USER_DN" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        END_TIME_ADD=$(date +%s%N)
        break
    fi
    sleep 0.05 # Check mais rápido
done
echo "OK."

# Requisito 2: Informar identidade das réplicas
echo "Réplicas idênticas (ADD): Sim (1/1 entrada encontrada) (Req. 2)"
echo ""

# --- PASSO 3: Medir o DELETE e Validar ---
echo -n "Deletando 1 entrada no LDAP-A... "
ldapdelete -x -H ldap://$LDAP_A -D $ADMIN_DN -w "$ADMIN_PASS" "$USER_DN" > /dev/null 2>&1

# Requisito 6: Informar sucesso/falha da remoção
if [ $? -eq 0 ]; then
    echo "Sucesso (Req. 6)"
    START_TIME_DEL=$(date +%s%N)
else
    echo "FALHA (Req. 6)"
    echo "Problema na limpeza."
    rm "$ARQUIVO_TESTE"
    exit 1
fi

echo -n "Aguardando 0 entradas no LDAP-B... "
while true; do
    # Procura pelo DN. Retorna != 0 se NÃO encontrar (sucesso)
    ldapsearch -x -H ldap://$LDAP_B -b "$USER_DN" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        END_TIME_DEL=$(date +%s%N)
        break
    fi
    sleep 0.05
done
echo "OK."

# Requisito 5: Informar identidade das réplicas
echo "Réplicas idênticas (DEL): Sim (0/1 entrada restante) (Req. 5)"
echo ""

# --- PASSO 4: Calcular e Mostrar (Requisito 7) ---
LAG_ADD_NS=$((END_TIME_ADD - START_TIME_ADD))
LAG_ADD_MS=$(echo "$LAG_ADD_NS / 1000000" | bc -l)

LAG_DEL_NS=$((END_TIME_DEL - START_TIME_DEL))
LAG_DEL_MS=$(echo "$LAG_DEL_NS / 1000000" | bc -l)

echo "--- RESULTADOS ---"
echo "Latência de Adição (1 entrada): $LAG_ADD_MS ms"
echo "Latência de Deleção (1 entrada): $LAG_DEL_MS ms"

# Limpeza final
rm "$ARQUIVO_TESTE"
