#!/bin/bash

# --- CONFIGURAÇÕES ---
# O número de vezes que você quer rodar o teste
NUMERO_DE_TESTES=100

# O script que será testado (o seu script de lote)
SCRIPT_DE_TESTE="./medir_lag_completo.sh" # <-- VERIFIQUE ESTE NOME

# Os arquivos que salvarão os resultados
ADD_RESULTS="resultados_add.txt"
DEL_RESULTS="resultados_del.txt"
# ---------------------

# Verifica se o script de teste existe
if [ ! -f "$SCRIPT_DE_TESTE" ]; then
    echo "Erro: Script '$SCRIPT_DE_TESTE' não encontrado."
    exit 1
fi

# Limpa os arquivos de resultados anteriores
> "$ADD_RESULTS"
> "$DEL_RESULTS"

echo "--- INICIANDO COLETA DE DADOS EM LOTE ---"
echo "Rodando o teste $NUMERO_DE_TESTES vezes..."
echo "Resultados de ADD serão salvos em: $ADD_RESULTS"
echo "Resultados de DEL serão salvos em: $DEL_RESULTS"
echo ""

# Loop principal
for i in $(seq 1 $NUMERO_DE_TESTES); do
    echo -n "Rodada $i de $NUMERO_DE_TESTES... "
    
    # 1. Roda o script de teste UMA VEZ e captura TODA a saída
    OUTPUT=$($SCRIPT_DE_TESTE)
    
    # 2. Filtra a saída para encontrar o número do ADD
    #    "Latência de Adição (Lote de 10): 381.02... ms"
    #    O awk '{print $7}' pega o 7º campo, que é o número.
    RESULT_ADD=$(echo "$OUTPUT" | awk '/Latência de Adição/ {print $7}')
    
    # 3. Filtra a saída para encontrar o número do DELETE
    #    "Latência de Deleção (Lote de 10): 136.07... ms"
    RESULT_DEL=$(echo "$OUTPUT" | awk '/Latência de Deleção/ {print $7}')
    
    # 4. Salva os números limpos nos arquivos
    echo "$RESULT_ADD" >> "$ADD_RESULTS"
    echo "$RESULT_DEL" >> "$DEL_RESULTS"
    
    echo "ADD: $RESULT_ADD ms, DEL: $RESULT_DEL ms"
    
    # Espera 1 segundo para o LDAP "respirar" e evitar sobrecarga
    sleep 1
done

echo ""
echo "--- COLETA CONCLUÍDA ---"
