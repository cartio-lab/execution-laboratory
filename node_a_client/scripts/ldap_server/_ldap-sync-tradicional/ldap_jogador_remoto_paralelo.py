#!/usr/bin/env python3
# ============================================================
# Projeto CARTO
# Autoria: Wagner P Calazans
# Ano de criação: 2025
# Versao: 1.0 (LDAP Remote Cannon)
# IME - Instituto Militar de Engenharia
#
# Arquivo: ldap_jogador_remoto_paralelo.py
# Descrição: Provisionamento remoto massivo via LDAP (Paralelo)
# ============================================================

import time
import sys
from concurrent.futures import ThreadPoolExecutor
from ldap3 import Server, Connection, ALL, SUBTREE
from ldap3.core.exceptions import LDAPException

# --- CONFIGURACAO ---
LDAP_HOST = '172.16.102.100' # Maquina B (Alvo)
LDAP_PORT = 389
LDAP_USER = 'cn=admin,dc=carto,dc=com' # Ajuste conforme seu slapd.conf
LDAP_PASS = 'carto123'                 # Ajuste conforme sua senha
BASE_DN   = 'dc=carto,dc=com'
TOTAL_USERS = 5000
CONCURRENCY = 200 # O mesmo nivel de paralelismo do SCIM

def add_ldap_user(user_id):
    # Cria uma conexao dedicada para esta thread (simula clientes distintos)
    server = Server(LDAP_HOST, port=LDAP_PORT, get_info=ALL)
    
    # Monta o DN e os atributos
    # Ajuste a estrutura se voce usa ou=users
    user_dn = f"uid=remoto{user_id},{BASE_DN}"
    
    attributes = {
        'objectClass': ['inetOrgPerson', 'organizationalPerson', 'person', 'top'],
        'cn': f'Usuario Remoto {user_id}',
        'sn': f'Sobrenome {user_id}',
        'uid': f'remoto{user_id}',
        'description': 'Carga Remota Paralela LDAP'
    }

    try:
        # Auto-bind e execucao
        conn = Connection(server, user=LDAP_USER, password=LDAP_PASS, auto_bind=True)
        if conn.add(user_dn, attributes=attributes):
            conn.unbind()
            return "SUCCESS"
        else:
            # Captura erro (ex: ja existe)
            result = conn.result['description']
            conn.unbind()
            if "already exists" in result:
                return "ALREADY_EXISTS"
            return "SERVER_ERROR"
    except Exception as e:
        return "CONN_ERROR"

def main():
    print("------------------------------------------------------------")
    print(f"INICIO DA CARGA REMOTA LDAP (PARALELA)")
    print(f"Alvo: ldap://{LDAP_HOST}:{LDAP_PORT}")
    print(f"Mode: {CONCURRENCY} conexoes simultaneas")
    print("------------------------------------------------------------")

    start_time = time.time()

    # ThreadPoolExecutor gerencia as 200 conexoes simultaneas
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as executor:
        # Mapeia a funcao para os 5000 IDs
        results = list(executor.map(add_ldap_user, range(1, TOTAL_USERS + 1)))

    end_time = time.time()
    duration = end_time - start_time

    success_count = results.count("SUCCESS")
    exists_count = results.count("ALREADY_EXISTS")
    error_count = results.count("SERVER_ERROR")
    conn_error = results.count("CONN_ERROR")

    print("------------------------------------------------------------")
    print(f"RELATORIO FINAL (LDAP REMOTO):")
    print(f"[SUCESSO] Inseridos....: {success_count}")
    print(f"[ALERTA]  Ja existiam..: {exists_count}")
    print(f"[FALHA]   Erro Logico..: {error_count}")
    print(f"[FALHA]   Erro Rede....: {conn_error}")
    print("------------------------------------------------------------")
    print(f"Tempo Total: {duration:.2f} segundos")
    if duration > 0:
        print(f"Throughput: {TOTAL_USERS / duration:.0f} req/segundo")
    print("------------------------------------------------------------")

if __name__ == "__main__":
    main()
