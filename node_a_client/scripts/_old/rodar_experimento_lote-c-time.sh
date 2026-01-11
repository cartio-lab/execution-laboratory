#!/bin/bash

# --- CONFIGURAÇÕES ---
NUMERO_DE_TESTES=100
SCRIPT_DE_TESTE="./medir_lag_unico.sh" # <-- VERIFIQUE O NOME (talvez seja medir_lag_lote.sh)
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

# --- INICIA O CRONÔMETRO GLOBAL ---
START_TIME_GLOBAL=$(date +%s)
# ---------------------------------

# Loop principal
for i in $(seq 1 $NUMERO_DE_TESTES); do
    echo -n "Rodada $i de $NUMERO_DE_TESTES... "
    
    # 1. Roda o script de teste UMA VEZ e captura TODA a saída
    OUTPUT=$($SCRIPT_DE_TESTE)
    
    # 2. Filtra a saída para encontrar o número do ADD
    RESULT_ADD=$(echo "$OUTPUT" | awk '/Latência de Adição/ {print $6}') #voltar para a 7, quando for usar o outro script
    
    # 3. Filtra a saída para encontrar o número do DELETE
    RESULT_DEL=$(echo "$OUTPUT" | awk '/Latência de Deleção/ {print $6}') #voltar para a 7, quando for usar o outro
    
    # 4. Salva os números limpos nos arquivos
    echo "$RESULT_ADD" >> "$ADD_RESULTS"
    echo "$RESULT_DEL" >> "$DEL_RESULTS"
    
    echo "ADD: $RESULT_ADD ms, DEL: $RESULT_DEL ms"
    
    # Espera 1 segundo para o LDAP "respirar"
    sleep 1
done

# --- PARA O CRONÔMETRO GLOBAL ---
END_TIME_GLOBAL=$(date +%s)
# -------------------------------

echo ""
echo "--- COLETA CONCLUÍDA ---"

# --- CALCULA E MOSTRA O TEMPO TOTAL ---
TOTAL_SECONDS=$((END_TIME_GLOBAL - START_TIME_GLOBAL))
echo "================================================="
printf "Tempo Total do Cenário: %dm %ds\n" $((TOTAL_SECONDS / 60)) $((TOTAL_SECONDS % 60))
echo "================================================="
