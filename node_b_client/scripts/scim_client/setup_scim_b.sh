#!/bin/bash
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.1 (FIX PERMISSAO)
# IME - Instituto Militar de Engenharia
#
# Arquivo: setup_scim_b.sh
# Descrição: Prepara o Servidor SCIM (Python + Postgres) e para o LDAP
# ============================================================

set -e

echo "[INFO] 1. Parando e desabilitando servico LDAP..."
systemctl stop slapd 2>/dev/null || true
systemctl disable slapd 2>/dev/null || true

echo "[INFO] 2. Instalando dependencias..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv postgresql libpq-dev

echo "[INFO] 3. Configurando Banco de Dados PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Cria usuario e banco
sudo -u postgres psql -c "CREATE USER scim_user WITH PASSWORD 'carto123';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE scim_db OWNER scim_user;" 2>/dev/null || true

# Cria a tabela de usuarios
echo "[INFO] Criando tabela 'users'..."
sudo -u postgres psql -d scim_db -c "
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    uid VARCHAR(100) PRIMARY KEY,
    username VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE users OWNER TO scim_user;
"

echo "[INFO] 4. Configurando Ambiente Python..."
APP_DIR="/opt/scim_server"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

python3 -m venv venv
source venv/bin/activate
pip install flask psycopg2-binary gunicorn > /dev/null

echo "[INFO] 5. Criando codigo do Servidor SCIM (server.py)..."
cat <<EOF > "$APP_DIR/server.py"
from flask import Flask, request, jsonify
import psycopg2

app = Flask(__name__)

# Configuracao do Banco
DB_HOST = "localhost"
DB_NAME = "scim_db"
DB_USER = "scim_user"
DB_PASS = "carto123"

def get_db_connection():
    conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
    return conn

@app.route('/Users', methods=['POST'])
def create_user():
    data = request.json
    uid = data.get('id')
    username = data.get('userName')
    description = data.get('description', '')

    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO users (uid, username, description) VALUES (%s, %s, %s)",
            (uid, username, description)
        )
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"id": uid, "status": "created"}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 400

@app.route('/Users/<uid>', methods=['PUT', 'PATCH'])
def update_user(uid):
    data = request.json
    description = data.get('description')
    
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "UPDATE users SET description = %s WHERE uid = %s",
            (description, uid)
        )
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"id": uid, "status": "updated"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 400

@app.route('/Users/<uid>', methods=['DELETE'])
def delete_user(uid):
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM users WHERE uid = %s", (uid,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "deleted"}), 204
    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
#    app.run(host='0.0.0.0', port=5000)
    app.run(host='0.0.0.0', port=5000, debug=False, ssl_context=('/opt/certs/cert.pem', '/opt/certs/key.pem'))
EOF

echo "------------------------------------------------------------"
echo "[SUCESSO] Ambiente SCIM corrigido e pronto com ssl"
echo "Execute: /opt/scripts/start_scim.sh"
echo "------------------------------------------------------------"
