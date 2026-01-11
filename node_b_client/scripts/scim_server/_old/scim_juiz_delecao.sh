#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.0 (SCIM)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_juiz_delecao.sh
# Descrição: Auditoria de delecao SCIM (Monitoramento SQL)
# ============================================================

IP_CLIENT="172.16.101.100"
PCAP_FILE="/root/resultado_delecao_scim.pcap"
TARGET_COUNT=0
LISTEN_INTERFACE="any"
PORT="5000"

echo "------------------------------------------------------------"
echo "INICIANDO CAPTURA DE PACOTES (SCIM/HTTP)"
echo "Filtro: Porta $PORT e Origem $IP_CLIENT"

tcpdump -i "$LISTEN_INTERFACE" "port $PORT and host $IP_CLIENT" -U -w "$PCAP_FILE" > /dev/null 2>&1 &
TCPDUMP_PID=$!
echo "[INFO] Captura iniciada. PID: $TCPDUMP_PID"
echo "------------------------------------------------------------"

echo "INICIANDO MONITORAMENTO DE LIMPEZA (SQL)"
echo "Alvo: 0 registros"

START_TIME=$(date +%s)

while true; do
    CURRENT_COUNT=$(sudo -u postgres psql -d scim_db -t -A -c "SELECT count(*) FROM users;" 2>/dev/null)
    if [ -z "$CURRENT_COUNT" ]; then CURRENT_COUNT=0; fi
    
    printf "[INFO] Registros restantes: %-5s \r" "$CURRENT_COUNT"

    if [ "$CURRENT_COUNT" -le "$TARGET_COUNT" ]; then
        echo ""
        echo "------------------------------------------------------------"
        echo "[SUCESSO] Tabela de usuarios vazia."
        break
    fi
    sleep 0.5
done

END_TIME=$(date +%s)

# ============================================================
# 3. FINALIZACAO E FORENSE
# ============================================================
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null
DURATION=$((END_TIME - START_TIME))

echo "[INFO] Processo finalizado."
echo "[INFO] Tempo de execucao (Script): ${DURATION} segundos"

if command -v capinfos &> /dev/null; then
    echo "------------------------------------------------------------"
    echo "ANALISE DE TEMPO REAL (PCAP)"
    REAL_DURATION=$(LC_ALL=C capinfos -uM "$PCAP_FILE" | grep "Capture duration" | awk '{print $3}')
    echo "[FORENSE] Duracao real do trafego HTTP: ${REAL_DURATION} segundos"
fi
echo "------------------------------------------------------------"
