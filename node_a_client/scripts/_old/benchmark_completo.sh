#!/bin/bash
# ==============================================================================
# SCRIPT MESTRE DE BENCHMARK LDAP - VERSÃO ACADÊMICA (CSV + ALTA PRECISÃO)
# ==============================================================================

# --- CONFIGURAÇÕES ---
LDAP_A="172.16.101.100"
LDAP_B="172.16.102.100"
ADMIN_DN="cn=admin,dc=carto,dc=org"
ADMIN_PASS="33028729"
BASE_DN="dc=carto,dc=org"
NUM_RODADAS=100
LOTE_TAMANHO=10

# Arquivos de saída
FILE_CSV="resultados_benchmark_$(date +%Y%m%d_%H%M).csv"
FILE_ADD="temp_res_add.txt"
FILE_DEL="temp_res_del.txt"
FILE_MOD="temp_res_mod.txt"

# Usuário "Âncora"
USER_MOD_DN="uid=anchor-mod,dc=carto,dc=org"

# Limpeza e Cabeçalho do CSV
rm -f $FILE_ADD $FILE_DEL $FILE_MOD
echo "rodada,tipo,tempo_ms" > "$FILE_CSV"

# ==============================================================================
# FUNÇÕES
# ==============================================================================

setup_ambiente() {
    echo "[INFO] Preparando ambiente..."
    ldapsearch -x -H ldap://$LDAP_A -b "$USER_MOD_DN" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        ldapadd -x -H ldap://$LDAP_A -D "$ADMIN_DN" -w "$ADMIN_PASS" <<EOF > /dev/null 2>&1
dn: $USER_MOD_DN
objectClass: inetOrgPerson
uid: anchor-mod
cn: Usuario Ancora
sn: Teste
description: original
EOF
    fi
    sleep 2
}

executar_teste_lote() {
    local RODADA=$1
    local ID_LOTE=$(date +%s%N)
    local ARQUIVO_LOTE="lote_$ID_LOTE.ldif"
    local DN_LIST=""

    # 1. Gerar Lote em Memória
    > "$ARQUIVO_LOTE"
    for k in $(seq 1 $LOTE_TAMANHO); do
        local U_DN="uid=teste-$ID_LOTE-$k,$BASE_DN"
        DN_LIST="$DN_LIST $U_DN"
        echo -e "dn: $U_DN\nobjectClass: inetOrgPerson\nuid: teste-$ID_LOTE-$k\ncn: Teste $k\nsn: Lote\n" >> "$ARQUIVO_LOTE"
    done

    # 2. Medir ADIÇÃO
    ldapadd -x -H ldap://$LDAP_A -D "$ADMIN_DN" -w "$ADMIN_PASS" -f "$ARQUIVO_LOTE" > /dev/null 2>&1
    local T_START=$(date +%s%N)
    
    while true; do
        local COUNT=$(ldapsearch -x -H ldap://$LDAP_B -b "$BASE_DN" "(uid=teste-$ID_LOTE-*)" uid | grep 'uid:' | wc -l)
        if [ "$COUNT" -eq "$LOTE_TAMANHO" ]; then
            local T_END=$(date +%s%N)
            break
        fi
        sleep 0.01 # Alta precisão: 10ms
    done
    local T_MS=$(( (T_END - T_START) / 1000000 ))
    echo "$T_MS" >> "$FILE_ADD"
    echo "$RODADA,add_lote,$T_MS" >> "$FILE_CSV"

    # 3. Medir DELEÇÃO
    ldapdelete -x -H ldap://$LDAP_A -D "$ADMIN_DN" -w "$ADMIN_PASS" $DN_LIST > /dev/null 2>&1
    local T_START=$(date +%s%N)

    while true; do
        local COUNT=$(ldapsearch -x -H ldap://$LDAP_B -b "$BASE_DN" "(uid=teste-$ID_LOTE-*)" uid | grep 'uid:' | wc -l)
        if [ "$COUNT" -eq 0 ]; then
            local T_END=$(date +%s%N)
            break
        fi
        sleep 0.01
    done
    local T_MS=$(( (T_END - T_START) / 1000000 ))
    echo "$T_MS" >> "$FILE_DEL"
    echo "$RODADA,del_lote,$T_MS" >> "$FILE_CSV"

    rm -f "$ARQUIVO_LOTE"
}

executar_teste_modify() {
    local RODADA=$1
    local NEW_VAL=$(date +%s%N)

    ldapmodify -x -H ldap://$LDAP_A -D "$ADMIN_DN" -w "$ADMIN_PASS" <<EOF > /dev/null 2>&1
dn: $USER_MOD_DN
changetype: modify
replace: description
description: $NEW_VAL
EOF

    local T_START=$(date +%s%N)
    while true; do
        if ldapsearch -x -H ldap://$LDAP_B -b "$USER_MOD_DN" description | grep -q "$NEW_VAL"; then
            local T_END=$(date +%s%N)
            break
        fi
        sleep 0.01
    done
    local T_MS=$(( (T_END - T_START) / 1000000 ))
    echo "$T_MS" >> "$FILE_MOD"
    echo "$RODADA,modify,$T_MS" >> "$FILE_CSV"
}

calcular_estatisticas() {
    local ARQUIVO=$1
    local NOME=$2
    sort -n "$ARQUIVO" | awk -v nome="$NOME" '
    { arr[NR] = $1; sum += $1 }
    END {
        if (NR == 0) exit;
        count = NR;
        p50 = arr[int(count*0.50)];
        p95 = arr[int(count*0.95)];
        p99 = arr[int(count*0.99)];
        avg = sum / count;
        printf "| %-15s | %8.2f ms | %8.2f ms | %8.2f ms | %8.2f ms |\n", nome, avg, p50, p95, p99
    }'
}

# ==============================================================================
# EXECUÇÃO
# ==============================================================================
setup_ambiente
echo "Iniciando $NUM_RODADAS rodadas..."

for i in $(seq 1 $NUM_RODADAS); do
    printf "\rProgresso: [%d/%d]" $i $NUM_RODADAS
    executar_teste_lote $i
    executar_teste_modify $i
    sleep 0.2
done

echo -e "\n\nRelatório Final:"
echo "=============================================================================="
echo "| TIPO DE TESTE   | MÉDIA      | P50 (Mediana)| P95          | P99          |"
echo "|-----------------|------------|--------------|--------------|--------------|"
calcular_estatisticas "$FILE_ADD" "ADIÇÃO (10)"
calcular_estatisticas "$FILE_DEL" "REMOÇÃO (10)"
calcular_estatisticas "$FILE_MOD" "MODIFY (1)"
echo "=============================================================================="
echo "Arquivo CSV gerado: $FILE_CSV"
