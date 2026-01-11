#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 2.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: ldap_jogador_deletar_usuarios.sh
# Descrição: Remocao rapida de 5.000 usuarios
# ============================================================

BINDDN="cn=admin,dc=carto,dc=org"
PASS="33028729"
BASE_DN="dc=carto,dc=org"
DN_FILE="/tmp/lista_para_deletar.txt"
TOTAL_USERS=5000

echo "------------------------------------------------------------"
echo "INICIO DO PROCESSO DE DELECAO"
echo "Alvo: $TOTAL_USERS usuarios"
echo "------------------------------------------------------------"

start_time=$(date +%s)

echo "[INFO] Gerando lista de DNs..."

(
for ((i=1; i<=TOTAL_USERS; i++)); do
    echo "uid=user$i,$BASE_DN"
done
) > "$DN_FILE"

echo "[INFO] Removendo usuarios do LDAP..."
# -c: Continua se houver erro (usuario nao encontrado)
ldapdelete -x -D "$BINDDN" -w "$PASS" -c -f "$DN_FILE" > /dev/null 2>&1
STATUS=$?

rm "$DN_FILE"

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "------------------------------------------------------------"
if [ $STATUS -eq 0 ]; then
    echo "[SUCESSO] Limpeza concluida."
else
    echo "[AVISO] Limpeza concluida (alguns usuarios nao existiam)."
fi
echo "Tempo Total: $duration segundos"
echo "------------------------------------------------------------"
