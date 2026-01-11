#!/bin/bash
# Mede o lag de replicação de uma MODIFICAÇÃO (modify)

# --- CONFIGURAÇÕES ---
LDAP_A="172.16.101.100"
LDAP_B="172.16.102.100"
ADMIN_DN="cn=admin,dc=carto,dc=org"
ADMIN_PASS="33028729" # <-- SUBSTITUA PELA SUA SENHA
# ---------------------

# --- Alvo do Teste ---
TARGET_DN="uid=alou-som,dc=carto,dc=org"
ARQUIVO_LDIF="modify_temp.ldif"

# 1. Gera o novo valor (timestamp com milissegundos)
# O formato será "2025-11-17-17-59-00-123"
NEW_VALUE=$(date +'%Y-%m-%d-%H-%M-%S-%3N')

# 2. Cria o arquivo .ldif para a modificação
cat << EOF > "$ARQUIVO_LDIF"
dn: $TARGET_DN
changetype: modify
replace: description
description: $NEW_VALUE
EOF

echo "--- Iniciando Teste de Lag (Modify) ---"
echo "Alvo: $TARGET_DN"
echo "Novo Valor: $NEW_VALUE"
echo ""

# 3. Executa a modificação no LDAP-A
echo -n "Modificando no LDAP-A... "
ldapmodify -x -H ldap://$LDAP_A -D $ADMIN_DN -w "$ADMIN_PASS" -f "$ARQUIVO_LDIF" > /dev/null 2>&1

# Verifica se o ldapmodify falhou (ex: usuário não existe)
if [ $? -ne 0 ]; then
    echo "FALHA!"
    echo "Erro: O ldapmodify falhou. Verifique se o DN '$TARGET_DN' existe."
    rm "$ARQUIVO_LDIF"
    exit 1
fi

# Inicia o cronômetro *depois* da escrita local
START_TIME=$(date +%s%N)
echo "OK."

# 4. Aguarda a propagação da modificação no LDAP-B
echo -n "Aguardando propagação no LDAP-B... "
while true; do
    # Faz um ldapsearch no LDAP-B e procura (grep) pelo novo valor
    # A flag -q do grep significa "quiet" (silencioso), só retorna 0 se encontrar
    ldapsearch -x -H ldap://$LDAP_B -b "$TARGET_DN" description | grep -q "description: $NEW_VALUE"
    
    if [ $? -eq 0 ]; then
        # Encontrado!
        END_TIME=$(date +%s%N)
        break
    fi
    sleep 0.05 # Espera 50ms antes de tentar de novo
done
echo "OK."

# 5. Calcula e mostra o tempo
LAG_MOD_NS=$((END_TIME - START_TIME))
LAG_MOD_MS=$(echo "$LAG_MOD_NS / 1000000" | bc -l)

echo ""
echo "--- RESULTADO (Fim do Script) ---"
echo "Tempo total da operação (propagação): $LAG_MOD_MS ms"

# Limpeza
rm "$ARQUIVO_LDIF"
