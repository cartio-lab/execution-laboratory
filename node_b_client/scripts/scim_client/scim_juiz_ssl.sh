#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Versão: 3.1 (Juiz SCIM SSL - HTTPS)
# Descrição: Auditoria Unificada SCIM sobre HTTPS.
#            - Monitoriza Porta 5000 (Criptografada).
#            - Salva em pastas separadas (_SSL) para organização.
# ============================================================

# --- CONFIGURACAO ---
IP_CLIENT="172.16.101.100" 
LISTEN_INTERFACE="any"
PORT="5000"                 # Porta do Flask (agora com TLS)
DB_NAME="scim_db"

# --- MUDANÇA CRÍTICA: PASTA SEPARADA ---
BASE_OUTPUT="/opt/resultados/scim_ssl"

trap cleanup SIGINT SIGTERM

cleanup() {
    if [ -n "$TCPDUMP_PID" ]; then
        echo ""
        echo "[!] Interrupção detectada. A parar a captura..."
        kill "$TCPDUMP_PID" 2>/dev/null
        wait "$TCPDUMP_PID" 2>/dev/null
    fi
    exit 0
}

# ============================================================
# SELEÇÃO DE CENÁRIO
# ============================================================
selecionar_cenario() {
    echo ""
    echo "--------------------------------------------------------"
    echo "ORGANIZAÇÃO DOS RESULTADOS (SCIM SSL/HTTPS)"
    echo "Qual o cenário de rede atual?"
    echo "--------------------------------------------------------"
    echo "0) Baseline (00_Baseline)"
    echo "1) Satélite (01_Satelite)"
    echo "2) Rádio Tático (02_Radio_Tatico)"
    echo "3) Desastre (03_Desastre)"
    echo "4) Caos Extremo (04_Caos)"
    echo "5) Degradação Parcial (05_Degradacao_parcial)"
    echo "6) Degradação Total (06_Degradacao_total)"
    echo "--------------------------------------------------------"
    read -p "Opção: " CEN_OPT

    FOLDER_NAME=""
    case $CEN_OPT in
        0) FOLDER_NAME="00_Baseline" ;;
        1) FOLDER_NAME="01_Satelite" ;;
        2) FOLDER_NAME="02_Radio_Tatico" ;;
        3) FOLDER_NAME="03_Desastre" ;;
        4) FOLDER_NAME="04_Caos" ;;
        5) FOLDER_NAME="05_Degradacao_parcial" ;;
        6) FOLDER_NAME="06_Degradacao_total" ;;
        *) echo "Inválido. A usar '99_Geral'"; FOLDER_NAME="99_Geral" ;;
    esac

    FINAL_PATH="$BASE_OUTPUT/$FOLDER_NAME"

    if [ ! -d "$FINAL_PATH" ]; then
        echo "[SISTEMA] A criar diretório: $FINAL_PATH"
        mkdir -p "$FINAL_PATH"
    fi

    echo "[SISTEMA] Ficheiros serão guardados em: $FINAL_PATH"
    return 0
}

# ============================================================
# FUNCOES DE CAPTURA
# ============================================================
iniciar_captura() {
    local NOME_ARQUIVO=$1
    FULL_PCAP_PATH="$FINAL_PATH/$NOME_ARQUIVO"

    echo "------------------------------------------------------------"
    echo "A INICIAR CAPTURA (SCIM HTTPS/TCP 5000)"
    echo "Ficheiro: $FULL_PCAP_PATH"
    
    tcpdump -i "$LISTEN_INTERFACE" "port $PORT and host $IP_CLIENT" -U -w "$FULL_PCAP_PATH" > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    echo "[INFO] Captura iniciada. PID: $TCPDUMP_PID"
    echo "------------------------------------------------------------"
}

finalizar_captura() {
    local START=$1
    local END=$(date +%s)
    local DURATION=$((END - START))

    kill "$TCPDUMP_PID"
    wait "$TCPDUMP_PID" 2>/dev/null
    
    echo ""
    echo "------------------------------------------------------------"
    echo "[INFO] Processo finalizado."
    echo "[INFO] Tempo (Script): ${DURATION} segundos"

    if command -v capinfos &> /dev/null; then
        echo "------------------------------------------------------------"
        echo "ANÁLISE FORENSE (PCAP)"
        REAL_DURATION=$(LC_ALL=C capinfos -uM "$FULL_PCAP_PATH" | grep "Capture duration" | awk '{print $3}')
        echo "[FORENSE] Duração real do tráfego: ${REAL_DURATION} s"
    fi
    echo "------------------------------------------------------------"
    read -p "Pressione [ENTER] para voltar ao menu..."
}

# ============================================================
# MODULOS DE MONITORIZAÇÃO (SQL)
# ============================================================

modo_criacao() {
    selecionar_cenario
    TARGET_COUNT=5000
    iniciar_captura "resultado_criacao_scim_ssl.pcap"
    
    echo "A INICIAR MONITORIZAÇÃO (PostgreSQL)"
    START_TIME=$(date +%s)
    while true; do
        CURRENT_COUNT=$(sudo -u postgres psql -d $DB_NAME -t -A -c "SELECT count(*) FROM users;" 2>/dev/null)
        if [ -z "$CURRENT_COUNT" ]; then CURRENT_COUNT=0; fi
        printf "[INFO] Registos: %-5s / %-5s\r" "$CURRENT_COUNT" "$TARGET_COUNT"

        if [ "$CURRENT_COUNT" -ge "$TARGET_COUNT" ]; then
            echo ""; echo "[SUCESSO] Carga SCIM SSL concluída."
            break
        fi
        sleep 0.5
    done
    finalizar_captura $START_TIME
}

modo_modificacao() {
    selecionar_cenario
    TARGET_USER="user5000"
    EXPECTED_VALUE="Modificado"
    iniciar_captura "resultado_modificacao_scim_ssl.pcap"
    
    echo "A INICIAR MONITORIZAÇÃO (PostgreSQL)"
    START_TIME=$(date +%s)
    while true; do
        RESULT=$(sudo -u postgres psql -d $DB_NAME -t -A -c "SELECT description FROM users WHERE uid='$TARGET_USER';" 2>/dev/null)
        if echo "$RESULT" | grep -q "$EXPECTED_VALUE"; then
            echo ""; echo "[SUCESSO] Atualização SSL detetada."
            break
        fi
        printf "[INFO] A aguardar commit... \r"
        sleep 0.5
    done
    finalizar_captura $START_TIME
}

modo_delecao() {
    selecionar_cenario
    iniciar_captura "resultado_delecao_scim_ssl.pcap"
    
    echo "A INICIAR MONITORIZAÇÃO (PostgreSQL)"
    START_TIME=$(date +%s)
    while true; do
        CURRENT_COUNT=$(sudo -u postgres psql -d $DB_NAME -t -A -c "SELECT count(*) FROM users;" 2>/dev/null)
        if [ -z "$CURRENT_COUNT" ]; then CURRENT_COUNT=0; fi
        printf "[INFO] Restantes: %-5s \r" "$CURRENT_COUNT"

        if [ "$CURRENT_COUNT" -le 0 ]; then
            echo ""; echo "[SUCESSO] Tabela vazia."
            break
        fi
        sleep 0.5
    done
    finalizar_captura $START_TIME
}

# ============================================================
# MENU
# ============================================================
while true; do
    clear
    echo "========================================================"
    echo "   JUIZ SCIM SSL (HTTPS/5000) - HDD"
    echo "   Guarda em: $BASE_OUTPUT/<Cenario>"
    echo "========================================================"
    echo "1) Auditoria de INSERÇÃO"
    echo "2) Auditoria de MODIFICAÇÃO"
    echo "3) Auditoria de DELEÇÃO"
    echo "0) Sair"
    echo "========================================================"
    read -p "Selecione: " OPTION
    case $OPTION in
        1) modo_criacao ;;
        2) modo_modificacao ;;
        3) modo_delecao ;;
        0) exit 0 ;;
        *) echo "Opção inválida."; sleep 1 ;;
    esac
done
