#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.0
# IME - Instituto Militar de Engenharia
# SCRIPT DE DIAGNOSTICO DE REDE - LADO B
# Origem: Maquina B (172.16.102.100)
# Destino: Maquina A (172.16.101.100)
# ============================================================

TARGET_IP="172.16.101.100"
LOG_DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "------------------------------------------------------------"
echo "INICIO DO TESTE: $LOG_DATE"
echo "Origem (Local):  $(hostname -I | awk '{print $1}')"
echo "Alvo (Remoto):   $TARGET_IP"
echo "------------------------------------------------------------"

# 1. Teste de Conectividade ICMP (Ping)
echo "[INFO] Iniciando teste de ping (4 pacotes)..."
if ping -c 4 -W 2 "$TARGET_IP" > /dev/null 2>&1; then
    echo "[SUCESSO] O host $TARGET_IP esta alcancavel."
    
    # Exibir latencia media
    LATENCY=$(ping -c 1 "$TARGET_IP" | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
    echo "[INFO] Latencia media: ${LATENCY}ms"
else
    echo "[ERRO] Falha ao comunicar com $TARGET_IP. O host esta inacessivel."
    echo "[INFO] Verificando tabela de roteamento para o destino..."
    ip route get "$TARGET_IP"
fi

echo "------------------------------------------------------------"
echo "FIM DO TESTE"
echo "------------------------------------------------------------"
