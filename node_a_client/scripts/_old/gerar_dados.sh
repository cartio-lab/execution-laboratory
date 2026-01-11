#!/bin/bash
# Um script shell para gerar dados de teste em LDIF e JSON

QTD=15000 # Quantidade de usuários para gerar
LDIF_FILE="users.ldif"
JSON_FILE="users.json"
BASE_DN="dc=carto,dc=org"

# Limpa arquivos antigos
> $LDIF_FILE
> $JSON_FILE

# Listas de valores aleatórios
ROLES=("Medico" "Engenheiro" "Infantaria" "Comunicações")
BLOODS=("A+" "O+" "B-" "AB+")
CLEARS=("CONFIDENCIAL" "SECRETO" "OSTENSIVO")

echo "Gerando $QTD usuários..."

# Inicia o JSON
echo "[" >> $JSON_FILE

for i in $(seq 1 $QTD); do
    # Pega valores aleatórios
    ROLE=${ROLES[$RANDOM % ${#ROLES[@]}]}
    BLOOD=${BLOODS[$RANDOM % ${#BLOODS[@]}]}
    CLEAR=${CLEARS[$RANDOM % ${#CLEARS[@]}]}

    # --- Gera o Bloco LDIF ---
    echo "dn: uid=user$i,$BASE_DN" >> $LDIF_FILE
    echo "objectClass: inetOrgPerson" >> $LDIF_FILE
    echo "objectClass: cartoPerson" >> $LDIF_FILE  # <-- Adicionando o Carto Esquema
    # Assumindo que você adicionou seus schemas CARTO:
    # echo "objectClass: cartoPerson" >> $LDIF_FILE 
    echo "uid: user$i" >> $LDIF_FILE
    echo "cn: Usuario $i" >> $LDIF_FILE
    echo "sn: Generico" >> $LDIF_FILE
    echo "missionRole: $ROLE" >> $LDIF_FILE
    echo "bloodType: $BLOOD" >> $LDIF_FILE
    echo "securityClearance: $CLEAR" >> $LDIF_FILE
    echo "" >> $LDIF_FILE # Linha em branco para separar entradas

    # --- Gera o Bloco JSON ---
    echo "  {" >> $JSON_FILE
    echo "    \"uid\": \"user$i\"," >> $JSON_FILE
    echo "    \"cn\": \"Usuario $i\"," >> $JSON_FILE
    echo "    \"missionRole\": \"$ROLE\"," >> $JSON_FILE
    echo "    \"bloodType\": \"$BLOOD\"," >> $JSON_FILE
    echo "    \"securityClearance\": \"$CLEAR\"" >> $JSON_FILE
    
    if [ $i -lt $QTD ]; then
        echo "  }," >> $JSON_FILE
    else
        echo "  }" >> $JSON_FILE # Última entrada, sem vírgula
    fi
done

# Fecha o JSON
echo "]" >> $JSON_FILE

echo "Arquivos '$LDIF_FILE' e '$JSON_FILE' gerados com $QTD usuários."
