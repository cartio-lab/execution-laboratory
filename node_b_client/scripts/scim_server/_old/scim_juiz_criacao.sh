#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.0 (SCIM)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_juiz_criacao.sh
# Descrição: Auditoria de carga SCIM (Monitoramento SQL)
# ============================================================

# --- CONFIGURACAO ---
IP_CLIENT="172.16.101.100" 
PCAP_FILE="/root/resultado_criacao_scim.pcap"
TARGET_COUNT=5000
LISTEN_INTERFACE="any"
PORT="5000"

# ============================================================
# 1. INICIAR CAPTURA DE TRAFEGO (TCPDUMP)
# ============================================================
echo "------------------------------------------------------------"
echo "INICIANDO CAPTURA DE PACOTES (SCIM/HTTP)"
echo "Filtro: Porta $PORT e Origem $IP_CLIENT"

# Filtra porta 5000 (Flask)
tcpdump -i "$LISTEN_INTERFACE" "port $PORT and host $IP_CLIENT" -U -w "$PCAP_FILE" > /dev/null 2>&1 &

TCPDUMP_PID=$!
echo "[INFO] Captura iniciada. PID: $TCPDUMP_PID"
echo "------------------------------------------------------------"

# ============================================================
# 2. MONITORAMENTO DE CONTAGEM (POSTGRESQL)
# ============================================================
echo "INICIANDO MONITORAMENTO DE BANCO DE DADOS (SQL)"
echo "Alvo: >= $TARGET_COUNT registros"
START_TIME=$(date +%s)

while true; do
    # Consulta SQL para contar linhas na tabela users
    # -t: Tuples only (sem cabecalho)
    # -A: Unaligned (sem formatacao visual)
    CURRENT_COUNT=$(sudo -u postgres psql -d scim_db -t -A -c "SELECT count(*) FROM users;" 2>/dev/null)
    
    # Se o banco estiver vazio ou comando falhar, assume 0
    if [ -z "$CURRENT_COUNT" ]; then CURRENT_COUNT=0; fi

    printf "[INFO] Registros no DB: %-5s / %-5s\r" "$CURRENT_COUNT" "$TARGET_COUNT"

    if [ "$CURRENT_COUNT" -ge "$TARGET_COUNT" ]; then
        echo ""
        echo "------------------------------------------------------------"
        echo "[SUCESSO] Carga SCIM concluida e persistida no Banco."
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
echo "[INFO] Evidencia salva em: $PCAP_FILE"

if command -v capinfos &> /dev/null; then
    echo "------------------------------------------------------------"
    echo "ANALISE DE TEMPO REAL (PCAP)"
    REAL_DURATION=$(LC_ALL=C capinfos -uM "$PCAP_FILE" | grep "Capture duration" | awk '{print $3}')
    echo "[FORENSE] Duracao real do trafego HTTP: ${REAL_DURATION} segundos"
else
    echo "------------------------------------------------------------"
    echo "[DICA] Instale 'tshark' para ver a duracao exata."
fi
echo "------------------------------------------------------------"
