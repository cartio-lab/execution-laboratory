#!/bin/bash
# Mede o lag de replicação de um LOTE (batch) de 10 entradas (ADD e DELETE)
# e valida a integridade da sincronização.

# --- CONFIGURAÇÕES ---
LDAP_A="172.16.101.100"
LDAP_B="172.16.102.100"
ADMIN_DN="cn=admin,dc=carto,dc=org"
ADMIN_PASS="33028729" # <-- SUBSTITUA PELA SUA SENHA
BASE_DN="dc=carto,dc=org"
NUM_ENTRADAS=10
# ---------------------

ID_LOTE=$(date +%s) # ID único para este lote de 10
ARQUIVO_LOTE="lote-$ID_LOTE.ldif"
DN_LIST="" # Lista para guardar os DNs para o delete

echo "--- Iniciando Teste de Lag em Lote ($NUM_ENTRADAS entradas) ---"
echo "ID do Lote: $ID_LOTE"
echo ""

# --- PASSO 1: Gerar 10 entradas ---
> "$ARQUIVO_LOTE" # Limpa o arquivo
for i in $(seq 1 $NUM_ENTRADAS); do
    USER_UID="teste-$ID_LOTE-$i"
    USER_DN="uid=$USER_UID,$BASE_DN"
    
    # Adiciona o DN à lista para o futuro delete
    DN_LIST="$DN_LIST $USER_DN"

    # Escreve a entrada no arquivo .ldif
    cat << EOF >> "$ARQUIVO_LOTE"
dn: $USER_DN
objectClass: inetOrgPerson
uid: $USER_UID
cn: Teste Lote $ID_LOTE-$i
sn: Teste

EOF
done

# --- PASSO 2: Medir o ADD e Validar ---
echo -n "Inserindo $NUM_ENTRADAS entradas no LDAP-A... "
ldapadd -x -H ldap://$LDAP_A -D $ADMIN_DN -w "$ADMIN_PASS" -f "$ARQUIVO_LOTE"

# Requisito 3: Informar sucesso/falha da adição
if [ $? -eq 0 ]; then
    echo "Sucesso (Req. 3)"
    START_TIME_ADD=$(date +%s%N)
else
    echo "FALHA (Req. 3)"
    echo "Abortando teste."
    rm "$ARQUIVO_LOTE"
    exit 1
fi

echo -n "Aguardando $NUM_ENTRADAS entradas no LDAP-B... "
while true; do
    # Conta quantos usuários deste lote existem no LDAP-B
    COUNT_B=$(ldapsearch -x -H ldap://$LDAP_B -b $BASE_DN "(uid=teste-$ID_LOTE-*)" uid | grep 'uid:' | wc -l)
    
    if [ "$COUNT_B" -eq "$NUM_ENTRADAS" ]; then
        END_TIME_ADD=$(date +%s%N)
        break
    fi
    sleep 0.1
done
echo "OK."

# Requisito 2: Informar identidade das réplicas
echo "Réplicas idênticas (ADD): Sim ($COUNT_B/$NUM_ENTRADAS entradas) (Req. 2)"
echo ""

# --- PASSO 3: Medir o DELETE e Validar ---
echo -n "Deletando $NUM_ENTRADAS entradas no LDAP-A... "
ldapdelete -x -H ldap://$LDAP_A -D $ADMIN_DN -w "$ADMIN_PASS" $DN_LIST > /dev/null 2>&1

# Requisito 6: Informar sucesso/falha da remoção
if [ $? -eq 0 ]; then
    echo "Sucesso (Req. 6)"
    START_TIME_DEL=$(date +%s%N)
else
    echo "FALHA (Req. 6)"
    echo "Problema na limpeza."
    rm "$ARQUIVO_LOTE"
    exit 1
fi

echo -n "Aguardando 0 entradas no LDAP-B... "
while true; do
    COUNT_B=$(ldapsearch -x -H ldap://$LDAP_B -b $BASE_DN "(uid=teste-$ID_LOTE-*)" uid | grep 'uid:' | wc -l)
    
    if [ "$COUNT_B" -eq 0 ]; then
        END_TIME_DEL=$(date +%s%N)
        break
    fi
    sleep 0.1
done
echo "OK."

# Requisito 5: Informar identidade das réplicas
echo "Réplicas idênticas (DEL): Sim ($COUNT_B/$NUM_ENTRADAS entradas restantes) (Req. 5)"
echo ""

# --- PASSO 4: Calcular e Mostrar (Requisito 7) ---
LAG_ADD_NS=$((END_TIME_ADD - START_TIME_ADD))
LAG_ADD_MS=$(echo "$LAG_ADD_NS / 1000000" | bc -l)

LAG_DEL_NS=$((END_TIME_DEL - START_TIME_DEL))
LAG_DEL_MS=$(echo "$LAG_DEL_NS / 1000000" | bc -l)

echo "--- RESULTADOS ---"
echo "Latência de Adição (Lote de 10): $LAG_ADD_MS ms"
echo "Latência de Deleção (Lote de 10): $LAG_DEL_MS ms"

# Limpeza final
rm "$ARQUIVO_LOTE"
