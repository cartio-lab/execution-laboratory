#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 2.0 (Fix: Leitura Direta via Slapcat)
# IME - Instituto Militar de Engenharia
#
# Arquivo: ldap_juiz_master.sh
# Descrição: Auditoria Unificada LDAP.
#            - Usa 'slapcat' para garantir leitura real do DB.
#            - Corrige falha de contagem na criação/modificação.
# ============================================================

# --- CONFIGURACAO GERAL ---
IP_PROVIDER="172.16.101.100" # IP da Maquina A
LISTEN_INTERFACE="any"
PORT="389"
BASE_DN="dc=carto,dc=org"

# --- CAMINHO BASE PARA RESULTADOS ---
BASE_OUTPUT="/opt/resultados/ldap"

# Trap para garantir paragem limpa do tcpdump
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
# SELEÇÃO DE CENÁRIO
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
        *) echo "Opção inválida. Usando '99_Geral'"; FOLDER_NAME="99_Geral" ;;
    esac

    FINAL_PATH="$BASE_OUTPUT/$FOLDER_NAME"

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
    FULL_PCAP_PATH="$FINAL_PATH/$NOME_ARQUIVO"

    echo "------------------------------------------------------------"
    echo "INICIANDO CAPTURA DE PACOTES (LDAP TCP/389)"
    echo "Arquivo: $FULL_PCAP_PATH"
    
    tcpdump -i "$LISTEN_INTERFACE" "port $PORT and host $IP_PROVIDER" -U -w "$FULL_PCAP_PATH" > /dev/null 2>&1 &
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
    fi
    echo "------------------------------------------------------------"
    read -p "Pressione [ENTER] para voltar ao menu..."
}

# ============================================================
# MODULOS DE MONITORAMENTO (USANDO SLAPCAT)
# ============================================================

modo_criacao() {
    selecionar_cenario
    
    # 5000 users + estrutura basica (dc, admin, ou=People)
    # Ajuste este numero se necessário. Se for 5000 users exatos, com a estrutura deve dar ~5003.
    TARGET_COUNT=5000
    iniciar_captura "resultado_criacao_ldap.pcap"
    
    echo "INICIANDO MONITORAMENTO (Leitura Direta DB)"
    echo "Aguardando >= $TARGET_COUNT usuários..."
    
    START_TIME=$(date +%s)
    while true; do
        # Conta quantos UIDs de usuário existem
        CURRENT_COUNT=$(slapcat -b "$BASE_DN" 2>/dev/null | grep -c "^uid: user_ldap_")
        
        printf "[INFO] Usuários Criados: %-5s / %-5s\r" "$CURRENT_COUNT" "$TARGET_COUNT"

        if [ "$CURRENT_COUNT" -ge "$TARGET_COUNT" ]; then
            echo ""; echo "[SUCESSO] Carga LDAP concluída."
            break
        fi
        sleep 1
    done
    finalizar_captura $START_TIME
}

modo_modificacao() {
    selecionar_cenario
    
    EXPECTED_VALUE="Modificado"
    iniciar_captura "resultado_modificacao_ldap.pcap"
    
    echo "INICIANDO MONITORAMENTO (Leitura Direta DB)"
    echo "Aguardando string '$EXPECTED_VALUE' aparecer no banco..."
    
    START_TIME=$(date +%s)
    while true; do
        # Procura a string em todo o banco (é rápido via slapcat)
        # O -m1 faz o grep parar na primeira ocorrência (otimização)
        FOUND=$(slapcat -b "$BASE_DN" 2>/dev/null | grep -m1 "$EXPECTED_VALUE")
        
        if [ -n "$FOUND" ]; then
            echo ""; echo "[SUCESSO] Modificação detectada na base."
            break
        fi
        printf "[INFO] Aguardando replicação/modificação... \r"
        sleep 0.5
    done
    finalizar_captura $START_TIME
}

modo_delecao() {
    selecionar_cenario
    
    iniciar_captura "resultado_delecao_ldap.pcap"
    
    echo "INICIANDO MONITORAMENTO (Leitura Direta DB)"
    echo "Aguardando esvaziar a base..."
    
    START_TIME=$(date +%s)
    while true; do
        # Conta quantos usuários AINDA existem
        CURRENT_COUNT=$(slapcat -b "$BASE_DN" 2>/dev/null | grep -c "^uid: user_ldap_")
        
        printf "[INFO] Usuários Restantes: %-5s \r" "$CURRENT_COUNT"

        if [ "$CURRENT_COUNT" -eq 0 ]; then
            echo ""; echo "[SUCESSO] Base LDAP limpa (0 usuários)."
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
    echo "   JUIZ DE AUDITORIA LDAP - v2.0 (Slapcat Mode)"
    echo "   Salva em: $BASE_OUTPUT/<Cenario>"
    echo "========================================================"
    echo "1) Auditoria de INSERCAO (Carga Massiva)"
    echo "2) Auditoria de MODIFICACAO (Verificar Replicacao)"
    echo "3) Auditoria de DELECAO (Limpeza Total)"
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
