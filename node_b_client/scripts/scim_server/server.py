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
