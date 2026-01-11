#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 2.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: ldap_jogador_modificar_usuarios.sh
# Descrição: Alteração de atributo em lote
# ============================================================

BINDDN="cn=admin,dc=carto,dc=org"
PASS="33028729"
BASE_DN="dc=carto,dc=org"
LDIF_FILE="/tmp/modificacao_usuarios.ldif"
TOTAL_USERS=5000

echo "------------------------------------------------------------"
echo "INICIO DO PROCESSO DE MODIFICACAO"
echo "Alvo: $TOTAL_USERS usuarios"
echo "------------------------------------------------------------"

start_time=$(date +%s)
CURRENT_TIME=$(date +%H:%M:%S)

echo "[INFO] Gerando instrucoes de modificacao..."

(
for ((i=1; i<=TOTAL_USERS; i++)); do
    echo "dn: uid=user$i,$BASE_DN"
    echo "changetype: modify"
    echo "replace: description"
    echo "description: Modificado as $CURRENT_TIME - Teste CARTO"
    echo ""
done
) > "$LDIF_FILE"

echo "[INFO] Aplicando alteracoes (Bulk Modify)..."
ldapmodify -x -D "$BINDDN" -w "$PASS" -f "$LDIF_FILE" > /dev/null 2>&1
STATUS=$?

rm "$LDIF_FILE"

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "------------------------------------------------------------"
if [ $STATUS -eq 0 ]; then
    echo "[SUCESSO] Modificacao concluida."
else
    echo "[ERRO] Falha na aplicacao das modificacoes."
fi
echo "Tempo Total: $duration segundos"
echo "------------------------------------------------------------"
