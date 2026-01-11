#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 2.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: ldap_jogador_gerar_usuarios.sh
# Descrição: Carga massiva de 5.000 usuarios via LDIF unico
# ============================================================

BINDDN="cn=admin,dc=carto,dc=org"
PASS="33028729"
BASE_DN="dc=carto,dc=org"
LDIF_FILE="/tmp/carga_usuarios.ldif"
TOTAL_USERS=5000

echo "------------------------------------------------------------"
echo "INICIO DO PROCESSO DE CARGA"
echo "Alvo: $TOTAL_USERS usuarios"
echo "------------------------------------------------------------"

start_time=$(date +%s)

echo "[INFO] Gerando arquivo LDIF temporario..."

(
for ((i=1; i<=TOTAL_USERS; i++)); do
    echo "dn: uid=user$i,$BASE_DN"
    echo "objectClass: inetOrgPerson"
    echo "objectClass: posixAccount"
    echo "objectClass: top"
    echo "uid: user$i"
    echo "sn: Silva"
    echo "givenName: Utilizador $i"
    echo "cn: Utilizador Teste $i"
    echo "displayName: Utilizador Teste $i"
    echo "uidNumber: $((10000 + i))"
    echo "gidNumber: 5000"
    echo "homeDirectory: /home/user$i"
    echo "loginShell: /bin/bash"
    echo "userPassword: 123"
    echo "" 
done
) > "$LDIF_FILE"

echo "[INFO] Inserindo dados no LDAP (Bulk Add)..."
ldapadd -x -D "$BINDDN" -w "$PASS" -f "$LDIF_FILE" > /dev/null 2>&1
STATUS=$?

rm "$LDIF_FILE"

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "------------------------------------------------------------"
if [ $STATUS -eq 0 ]; then
    echo "[SUCESSO] Carga finalizada."
else
    echo "[AVISO] Carga finalizada com alertas (verifique duplicatas)."
fi
echo "Tempo Total: $duration segundos"
echo "------------------------------------------------------------"
