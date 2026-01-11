#!/bin/bash

# --- CONFIGURAÇÕES ---
# O número de vezes que você quer rodar o teste
NUMERO_DE_TESTES=100

# O arquivo que salvará os resultados
ARQUIVO_RESULTADOS="resultados.txt"

# O script que será testado
SCRIPT_DE_LAG="./medir_lag.sh"
# ---------------------

# Verifica se o script de lag existe
if [ ! -f "$SCRIPT_DE_LAG" ]; then
    echo "Erro: Script '$SCRIPT_DE_LAG' não encontrado."
    exit 1
fi

# Limpa o arquivo de resultados anterior
> "$ARQUIVO_RESULTADOS"

echo "--- INICIANDO COLETA DE DADOS ---"
echo "Rodando o teste $NUMERO_DE_TESTES vezes..."
echo "Resultados serão salvos em: $ARQUIVO_RESULTADOS"
echo ""

# Loop principal
for i in $(seq 1 $NUMERO_DE_TESTES); do
    echo -n "Rodada $i de $NUMERO_DE_TESTES... "
    
    # Roda o script e filtra a saída:
    # 1. Roda o script.
    # 2. 'grep' filtra a linha "Latência de Replicação: ..."
    # 3. 'awk' imprime apenas o 4º campo (o número)
    # 4. 'tee -a' joga o resultado no arquivo E na tela
    
    # A flag '-l' no 'bc' no seu medir_lag.sh pode adicionar uma quebra de linha. 
    # Vamos ser robustos e pegar apenas o número, não importa o que.
    
    # O comando awk filtra a linha por "Latência" e imprime o 4º campo (o número)
    RESULTADO=$(./medir_lag.sh | awk '/Latência de Replicação:/ {print $4}')
    
    # Salva o número limpo no arquivo
    echo "$RESULTADO" >> "$ARQUIVO_RESULTADOS"
    
    echo "Resultado: $RESULTADO ms"
    
    # Espera 1 segundo para o LDAP "respirar" e evitar sobrecarga
    sleep 1
done

echo ""
echo "--- COLETA CONCLUÍDA ---"
echo "Resultados salvos em $ARQUIVO_RESULTADOS."
