#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 3.0
# IME - Instituto Militar de Engenharia
#
# SCRIPT DE AUDITORIA: MONITORAMENTO DE DELECAO
# Arquivo: ldap_juiz_delecao.sh
# Objetivo: Validar a replicacao da remocao total de usuarios
# ============================================================

# --- CONFIGURACAO ---
IP_PROVIDER="172.16.101.100"
PCAP_FILE="/root/resultado_delecao_blindado.pcap"
# Alvo: 2 entradas (Geralmente sobra apenas o Root DN e o Admin)
TARGET_COUNT=2 
LISTEN_INTERFACE="any"

# ============================================================
# 1. INICIAR CAPTURA DE TRAFEGO
# ============================================================
echo "------------------------------------------------------------"
echo "INICIANDO CAPTURA DE PACOTES"
echo "Filtro: Porta 389 e Origem $IP_PROVIDER"

# Captura apenas pacotes de replicacao vindos do Provider
tcpdump -i "$LISTEN_INTERFACE" "port 389 and host $IP_PROVIDER" -U -w "$PCAP_FILE" > /dev/null 2>&1 &

TCPDUMP_PID=$!
echo "[INFO] Captura iniciada. PID: $TCPDUMP_PID"
echo "------------------------------------------------------------"

# ============================================================
# 2. MONITORAMENTO DA BASE DE DADOS
# ============================================================
echo "INICIANDO MONITORAMENTO DE LIMPEZA"
echo "Alvo: Reduzir base para <= $TARGET_COUNT entradas"

START_TIME=$(date +%s)

while true; do
    # Utilizamos 'slapcat' para ler diretamente do disco (backend).
    # Isso e mais rapido e preciso durante operacoes de I/O intenso como delecao em massa.
    CURRENT_COUNT=$(slapcat -b "dc=carto,dc=org" 2>/dev/null | grep -c "^dn: ")
    
    # Exibe a contagem regressiva
    printf "[INFO] Objetos restantes: %-5s \r" "$CURRENT_COUNT"

    if [ "$CURRENT_COUNT" -le "$TARGET_COUNT" ]; then
        echo ""
        echo "------------------------------------------------------------"
        echo "[SUCESSO] Base de dados limpa (apenas estrutura basica restante)."
        break
    fi
    
    # Pausa curta para nao saturar CPU
    sleep 0.5
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
    
    # LC_ALL=C: Forca a saida em Ingles para garantir que o grep funcione
    # -u: Human readable (com unidades, mas facil de ler)
    # -M: Machine readable (simplificado)
    REAL_DURATION=$(LC_ALL=C capinfos -uM "$PCAP_FILE" | grep "Capture duration" | awk '{print $3}')
    
    echo "[FORENSE] Duracao real do trafego: ${REAL_DURATION} segundos"
else
    echo "------------------------------------------------------------"
    echo "[DICA] Instale 'tshark' (apt-get install tshark) para ver a duracao exata."
fi
# -------------------------------------------

echo "------------------------------------------------------------"
