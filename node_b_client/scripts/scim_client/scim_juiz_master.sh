#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 3.0 (Organização Automática de Diretórios)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_juiz_master.sh
# Descrição: Auditoria Unificada SCIM.
#            - Cria árvore de diretórios baseada no cenário.
#            - Salva PCAP organizado por pasta.
# ============================================================

# --- CONFIGURACAO GERAL ---
IP_CLIENT="172.16.101.100"  # IP da Maquina A
LISTEN_INTERFACE="any"
PORT="5000"
DB_NAME="scim_db"

# --- CAMINHO BASE PARA RESULTADOS ---
# Se não existir, o script cria
BASE_OUTPUT="/opt/resultados/scim"

# Trap para garantir paragem limpa
trap cleanup SIGINT SIGTERM

cleanup() {
    if [ -n "$TCPDUMP_PID" ]; then
        echo ""
        echo "[!] Interrupção detectada. Parando captura..."
        kill "$TCPDUMP_PID" 2>/dev/null
        wait "$TCPDUMP_PID" 2>/dev/null
    fi
    exit 0
}

# ============================================================
# SELEÇÃO DE CENÁRIO (ORGANIZAÇÃO)
# ============================================================
selecionar_cenario() {
    echo ""
    echo "--------------------------------------------------------"
    echo "ORGANIZAÇÃO DOS ARQUIVOS DE RESULTADO"
    echo "Para qual cenário você está rodando este teste?"
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
        *) echo "Opção inválida. Usando 'Lixo_Geral'"; FOLDER_NAME="99_Geral" ;;
    esac

    # Caminho final completo
    FINAL_PATH="$BASE_OUTPUT/$FOLDER_NAME"

    # Cria o diretório se não existir
    if [ ! -d "$FINAL_PATH" ]; then
        echo "[SISTEMA] Criando diretório: $FINAL_PATH"
        mkdir -p "$FINAL_PATH"
    fi

    echo "[SISTEMA] Arquivos serão salvos em: $FINAL_PATH"
    return 0
}

# ============================================================
# FUNCOES DE CAPTURA
# ============================================================

iniciar_captura() {
    local NOME_ARQUIVO=$1
    # Define o caminho completo baseado na seleção anterior
    FULL_PCAP_PATH="$FINAL_PATH/$NOME_ARQUIVO"

    echo "------------------------------------------------------------"
    echo "INICIANDO CAPTURA DE PACOTES (SCIM/HTTP)"
    echo "Arquivo: $FULL_PCAP_PATH"
    
    # Inicia tcpdump (Sobrescreve se existir devido ao -w direto)
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
        echo "ANALISE FORENSE (PCAP)"
        REAL_DURATION=$(LC_ALL=C capinfos -uM "$FULL_PCAP_PATH" | grep "Capture duration" | awk '{print $3}')
        echo "[FORENSE] Duração real do tráfego: ${REAL_DURATION} s"
    else
        echo "[DICA] Instale 'tshark' para analise precisa."
    fi
    echo "------------------------------------------------------------"
    read -p "Pressione [ENTER] para voltar ao menu..."
}

# ============================================================
# MODULOS DE MONITORAMENTO
# ============================================================

modo_criacao() {
    selecionar_cenario
    
    TARGET_COUNT=5000
    iniciar_captura "resultado_criacao_scim.pcap"
    
    echo "INICIANDO MONITORAMENTO DE BANCO DE DADOS (SQL)"
    echo "Aguardando chegar em $TARGET_COUNT registros..."
    
    START_TIME=$(date +%s)
    while true; do
        CURRENT_COUNT=$(sudo -u postgres psql -d $DB_NAME -t -A -c "SELECT count(*) FROM users;" 2>/dev/null)
        if [ -z "$CURRENT_COUNT" ]; then CURRENT_COUNT=0; fi

        printf "[INFO] Registros: %-5s / %-5s\r" "$CURRENT_COUNT" "$TARGET_COUNT"

        if [ "$CURRENT_COUNT" -ge "$TARGET_COUNT" ]; then
            echo ""; echo "[SUCESSO] Carga SCIM concluida."
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
    iniciar_captura "resultado_modificacao_scim.pcap"
    
    echo "INICIANDO MONITORAMENTO DE ATRIBUTO (SQL)"
    echo "Aguardando update em uid='$TARGET_USER'..."
    
    START_TIME=$(date +%s)
    while true; do
        RESULT=$(sudo -u postgres psql -d $DB_NAME -t -A -c "SELECT description FROM users WHERE uid='$TARGET_USER';" 2>/dev/null)
        
        if echo "$RESULT" | grep -q "$EXPECTED_VALUE"; then
            echo ""; echo "[SUCESSO] Atualizacao detectada."
            break
        fi
        printf "[INFO] Aguardando commit... \r"
        sleep 0.5
    done
    finalizar_captura $START_TIME
}

modo_delecao() {
    selecionar_cenario
    
    iniciar_captura "resultado_delecao_scim.pcap"
    
    echo "INICIANDO MONITORAMENTO DE LIMPEZA (SQL)"
    echo "Aguardando esvaziar tabela..."
    
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
# MENU PRINCIPAL
# ============================================================

while true; do
    clear
    echo "========================================================"
    echo "   JUIZ DE AUDITORIA SCIM - v3.0 (Organization Mode)"
    echo "   Salva em: $BASE_OUTPUT/<Cenario>"
    echo "========================================================"
    echo "1) Auditoria de INSERCAO"
    echo "2) Auditoria de MODIFICACAO"
    echo "3) Auditoria de DELECAO"
    echo "0) Sair"
    echo "========================================================"
    read -p "Selecione a atividade: " OPTION

    case $OPTION in
        1) modo_criacao ;;
        2) modo_modificacao ;;
        3) modo_delecao ;;
        0) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida."; sleep 1 ;;
    esac
done
