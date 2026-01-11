#!/bin/bash
# Mede o lag de replicação entre dois servidores LDAP

# IPs do laboratório
LDAP_A="172.16.101.100"
LDAP_B="172.16.102.100"

# DN do Admin (para escrever)
ADMIN_DN="cn=admin,dc=carto,dc=org"
ADMIN_PASS="33028729"

# Gera um ID único para o teste
ID_TESTE=$(date +%s%N)
USER_DN="uid=teste-$ID_TESTE,dc=carto,dc=org"

echo "--- Iniciando Teste de Lag de Replicação ---"
echo "Usuário de teste: $USER_DN"

# --- PASSO 1: Adicionar usuário no LDAP-A ---
# Criar um mini-ldif para o teste
cat << EOF > teste-$ID_TESTE.ldif
dn: $USER_DN
objectClass: inetOrgPerson
uid: teste-$ID_TESTE
cn: Teste Lag $ID_TESTE
sn: Teste
EOF

echo "Inserindo no LDAP-A ($LDAP_A)..."
# Inserir e capturar o tempo de início *depois* do comando terminar
#ldapadd -x -H ldap://$LDAP_A -D $ADMIN_DN -W -f teste-$ID_TESTE.ldif  # <- Linha sem adição de senha
ldapadd -x -H ldap://$LDAP_A -D $ADMIN_DN -w "$ADMIN_PASS" -f teste-$ID_TESTE.ldif
START_TIME=$(date +%s%N)

# --- PASSO 2: Procurar usuário no LDAP-B ---
echo "Iniciando loop de busca no LDAP-B ($LDAP_B)..."
while true; do
    # -x = simple auth (anon)
    # -H = host
    # -b = base DN
    # O comando ldapsearch retorna 0 se encontrar, e não-zero se não encontrar
    ldapsearch -x -H ldap://$LDAP_B -b "$USER_DN" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        # Encontrado!
        END_TIME=$(date +%s%N)
        break
    fi
    # Espera um pouco antes de tentar de novo
    sleep 0.1
done

# --- PASSO 3: Calcular e Mostrar ---
LAG_NS=$((END_TIME - START_TIME))
LAG_MS=$(echo "$LAG_NS / 1000000" | bc -l)

echo ""
echo "--- RESULTADO ---"
echo "Usuário replicado com sucesso!"
echo "Latência de Replicação: $LAG_MS ms"
echo ""

# Limpeza
rm teste-$ID_TESTE.ldif
#ldapdelete -x -H ldap://$LDAP_A -D $ADMIN_DN -W "$USER_DN" > /dev/null # <- linha antiga que pedia a senha
ldapdelete -x -H ldap://$LDAP_A -D $ADMIN_DN -w "$ADMIN_PASS" "$USER_DN" > /dev/null
echo "Usuário de teste removido."
