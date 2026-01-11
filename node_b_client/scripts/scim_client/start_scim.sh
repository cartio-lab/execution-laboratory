#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.0
# IME - Instituto Militar de Engenharia
#
# Arquivo: start_scim.sh
# Descrição: Inicia o servidor da API SCIM (Flask)
# ============================================================

APP_DIR="/opt/scim_server"

echo "[INFO] Iniciando Servidor SCIM na porta 5000..."
cd "$APP_DIR"
source venv/bin/activate

# Usamos Gunicorn para uma performance mais realista de producao (multithread)
# Ou pode usar 'python3 server.py' para teste simples.
# Aqui vamos usar python direto para ver logs na tela se necessario.

python3 server.py
