#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
# Projeto CARTO
# Versao: 2.0 (LDAPS/SSL - Security Mode)
# ============================================================
import sys, os, time, threading, queue, subprocess, ssl
from ldap3 import Server, Connection, ALL, MODIFY_REPLACE, Tls

# --- AUTO-VERIFICAÇÃO ---
TARGET_PYTHON = "/opt/scim_client/venv/bin/python3"
if os.path.exists(TARGET_PYTHON) and sys.executable != TARGET_PYTHON:
    os.execv(TARGET_PYTHON, [TARGET_PYTHON] + sys.argv)

# --- CONFIGURACOES SSL ---
LDAP_HOST = '172.16.102.100'
LDAP_PORT = 636  # Porta Segura
BIND_DN   = 'cn=admin,dc=carto,dc=org'
BIND_PASS = '33028729'
BASE_DN   = 'dc=carto,dc=org'
TOTAL_USERS = 5000
NUM_THREADS = 50 

# CONFIGURACAO TLS (Ignora erro de certificado auto-assinado)
tls_conf = Tls(validate=ssl.CERT_NONE, version=ssl.PROTOCOL_TLSv1_2)

def get_active_interface():
    try:
        interfaces = os.listdir('/sys/class/net/')
        interfaces = [iface for iface in interfaces if iface != 'lo']
        if len(interfaces) == 1: return interfaces[0]
        cmd = "ip route | grep default | awk '{print $5}'"
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, encoding='utf-8')
        d = res.stdout.strip()
        if d and d in interfaces: return d
        return interfaces[0]
    except: return "ens38"

NET_INTERFACE = get_active_interface()
user_queue = queue.Queue()
success_count = 0
fail_count = 0
lock = threading.Lock()

# --- REDE ---
def run_shell(c): subprocess.run(c, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def apply_network(delay, loss, desc):
    print(f"   [REDE] Limpando {NET_INTERFACE}...")
    run_shell(f"tc qdisc del dev {NET_INTERFACE} root")
    if delay > 0 or loss > 0:
        print(f"   [REDE] Aplicado: {desc}")
        subprocess.run(f"tc qdisc add dev {NET_INTERFACE} root netem delay {delay}ms loss {loss}%", shell=True)
    
    res = subprocess.run(f"tc qdisc show dev {NET_INTERFACE}", shell=True, stdout=subprocess.PIPE, encoding='utf-8')
    if res.stdout: print(f"   [KERNEL] {res.stdout.strip()}")

# --- WORKER GENERICO COM SSL ---
def worker_generic(mode, timeout_val):
    global success_count, fail_count
    # Define Servidor com SSL ativo
    server = Server(LDAP_HOST, port=LDAP_PORT, use_ssl=True, tls=tls_conf, get_info=ALL, connect_timeout=timeout_val)
    conn = Connection(server, BIND_DN, BIND_PASS, auto_bind=False)
    
    while not user_queue.empty():
        try:
            item = user_queue.get(block=False)
            uid = item[0] if isinstance(item, tuple) else item
            
            if not conn.bound:
                if not conn.bind(): raise Exception("Bind Fail")

            dn = f"uid={uid},{BASE_DN}"
            res = False
            
            if mode == 'insert':
                attrs = {
                    'objectClass': ['top', 'person', 'organizationalPerson', 'inetOrgPerson', 'posixAccount'],
                    'cn': item[1], 'sn': 'SSL', 'uid': uid, 'userPassword': '123',
                    'uidNumber': str(10000 + int(uid.split('_')[-1])), 'gidNumber': '500', 'homeDirectory': f'/home/{uid}'
                }
                res = conn.add(dn, attributes=attrs)
            elif mode == 'update':
                res = conn.modify(dn, {'description': [(MODIFY_REPLACE, [item[1]])]})
            elif mode == 'delete':
                res = conn.delete(dn)
                
            with lock:
                if res: success_count += 1
                else: fail_count += 1
            user_queue.task_done()
            
        except queue.Empty: break
        except Exception: 
            with lock: fail_count += 1
            try: conn.unbind()
            except: pass
    try: conn.unbind()
    except: pass

def run_test(mode, timeout):
    with user_queue.mutex: user_queue.queue.clear()
    global success_count, fail_count
    success_count = 0; fail_count = 0
    
    print(f"Populando fila {mode}...")
    for i in range(TOTAL_USERS):
        if mode == 'insert': user_queue.put((f"user_ldap_{i}", f"User SSL {i}"))
        elif mode == 'update': user_queue.put((f"user_ldap_{i}", f"Modificado SSL"))
        else: user_queue.put(f"user_ldap_{i}")
        
    print(f"Iniciando Threads (LDAPS)...")
    start = time.time()
    threads = []
    for _ in range(NUM_THREADS):
        t = threading.Thread(target=worker_generic, args=(mode, timeout))
        t.start(); threads.append(t)
    for t in threads: t.join()
    
    total = time.time() - start
    print(f"FIM | Tempo: {total:.2f}s | Sucesso: {success_count} | Falha: {fail_count}")
    input("Enter...")

def main_menu():
    if os.geteuid() != 0: print("ROOT necessario"); sys.exit(1)
    while True:
        os.system('clear')
        print("="*60)
        print(f"   MASTER JOGADOR LDAP (LDAPS/SSL) - Interface: {NET_INTERFACE}")
        print("="*60)
        print("1) Inserir | 2) Modificar | 3) Deletar | 0) Sair")
        opt = input("Opcao: ")
        
        if opt == '0': apply_network(0,0,"Clean"); sys.exit(0)
        elif opt in ['1','2','3']:
            mode = "insert" if opt == '1' else "update" if opt == '2' else "delete"
            print("\nCenarios: 0)Baseline 1)Sat 2)Radio 3)Desastre 4)Caos 5)DegParcial 6)DegTotal")
            try: r = int(input("Cenario Rede (0-6): "))
            except: r = 0
            sc = {0:(0,0,"Base"), 1:(600,1,"Sat"), 2:(100,5,"Radio"), 3:(200,15,"Desastre"), 
                  4:(500,40,"Caos"), 5:(800,70,"DegP"), 6:(1200,95,"DegT")}
            d, l, desc = sc.get(r, (0,0,"Base"))
            
            t = 1000
            apply_network(d, l, desc)
            run_test(mode, t)
            apply_network(0,0,"Clean")

if __name__ == "__main__":
    try: main_menu()
    except KeyboardInterrupt: apply_network(0,0,"Clean"); print("\nSaindo...")
