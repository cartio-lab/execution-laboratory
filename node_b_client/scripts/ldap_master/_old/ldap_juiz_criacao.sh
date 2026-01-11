#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 3.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: ldap_juiz_criacao.sh
# Descrição: Auditoria de replicacao de CRIACAO (SizeLimit Safe)
# ============================================================

# --- CONFIGURACAO ---
IP_PROVIDER="172.16.101.100" 
PCAP_FILE="/root/resultado_criacao_blindado.pcap"
# 5000 novos usuarios + admin + configs iniciais = ~5001 ou 5002
TARGET_COUNT=5001
LISTEN_INTERFACE="any"

# ============================================================
# 1. INICIAR CAPTURA DE TRAFEGO (TCPDUMP)
# ============================================================
echo "------------------------------------------------------------"
echo "INICIANDO CAPTURA DE PACOTES"
echo "Filtro: Porta 389 e Origem $IP_PROVIDER (Ignorando Loopback)"

# O filtro captura trafego na porta 389 vindo do Provider
# -U: Grava o pacote imediatamente no disco (buffer line)
tcpdump -i "$LISTEN_INTERFACE" "port 389 and host $IP_PROVIDER" -U -w "$PCAP_FILE" > /dev/null 2>&1 &

TCPDUMP_PID=$!
echo "[INFO] Captura iniciada. PID: $TCPDUMP_PID"
echo "------------------------------------------------------------"

# ============================================================
# 2. MONITORAMENTO DE CONTAGEM (LDAP LOCAL)
# ============================================================
echo "INICIANDO MONITORAMENTO DE BANCO DE DADOS"
echo "Alvo: >= $TARGET_COUNT entradas"
START_TIME=$(date +%s)

while true; do
    # -E pr=1000/noprompt: Garante paginacao caso o server nao tenha SizeLimit alto
    # dn: Traz apenas o Distinguished Name (leve)
    CURRENT_COUNT=$(ldapsearch -H ldapi:/// -Y EXTERNAL -E pr=1000/noprompt -b "dc=carto,dc=org" dn 2>/dev/null | grep -c "dn: ")
    
    # Exibe progresso na mesma linha
    printf "[INFO] Contagem atual: %-5s / %-5s\r" "$CURRENT_COUNT" "$TARGET_COUNT"

    if [ "$CURRENT_COUNT" -ge "$TARGET_COUNT" ]; then
        echo ""
        echo "------------------------------------------------------------"
        echo "[SUCESSO] Alvo de replicacao atingido."
        break
    fi
    
    # Pequena pausa para nao saturar a CPU
    sleep 1
done

END_TIME=$(date +%s)

# ============================================================
# 3. FINALIZACAO
# ============================================================
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null

DURATION=$((END_TIME - START_TIME))

echo "[INFO] Processo finalizado."
echo "[INFO] Tempo de execucao (Script): ${DURATION} segundos"
echo "[INFO] Evidencia salva em: $PCAP_FILE"

# --- BLOCO NOVO: ANALISE FORENSE DO PCAP ---
if command -v capinfos &> /dev/null; then
    echo "------------------------------------------------------------"
    echo "ANALISE DE TEMPO REAL (PCAP)"
    
    # LC_ALL=C: Forca ingles para garantir que o grep encontre "Capture duration"
    REAL_DURATION=$(LC_ALL=C capinfos -uM "$PCAP_FILE" | grep "Capture duration" | awk '{print $3}')
    
    echo "[FORENSE] Duracao real do trafego: ${REAL_DURATION} segundos"
else
    echo "------------------------------------------------------------"
    echo "[DICA] Instale 'tshark' (apt-get install tshark) para ver a duracao exata."
fi
# -------------------------------------------

echo "------------------------------------------------------------"
