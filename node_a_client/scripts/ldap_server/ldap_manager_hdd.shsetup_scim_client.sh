#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: setup_scim_client.sh
# Descrição: Prepara o Cliente SCIM (Python + Aiohttp)
# ============================================================

set -e

echo "[INFO] Instalando dependencias do Cliente..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv

echo "[INFO] Criando ambiente virtual..."
mkdir -p /opt/scim_client
cd /opt/scim_client
python3 -m venv venv
source venv/bin/activate

echo "[INFO] Instalando biblioteca AIOHTTP (Assincrona)..."
pip install aiohttp > /dev/null

echo "------------------------------------------------------------"
echo "[SUCESSO] Maquina A pronta para gerar carga SCIM."
echo "Scripts serao salvos em: /opt/scripts/"
echo "------------------------------------------------------------"
