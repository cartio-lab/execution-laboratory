#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
# Projeto CARTO
# Autoria: Wagner P Calazans
# Versao: 7.0 (Com Validação e Confirmação de Rede)
# IME - Instituto Militar de Engenharia
#
# Arquivo: ldap_py_jogador_master.py
# Descrição: Ferramenta unificada para testes de carga LDAP.
#            - Valida existência da interface de rede.
#            - Confirma visualmente a regra aplicada pelo Kernel.
# ============================================================

import sys
import os

# --- [BLINDAGEM] AUTO-CORREÇÃO DE AMBIENTE ---
TARGET_PYTHON = "/opt/scim_client/venv/bin/python3"
if os.path.exists(TARGET_PYTHON) and sys.executable != TARGET_PYTHON:
    print(f"[SISTEMA] Reiniciando no VENV correto: {TARGET_PYTHON}...")
    os.execv(TARGET_PYTHON, [TARGET_PYTHON] + sys.argv)
# ---------------------------------------------

import time
import threading
import queue
import subprocess
from ldap3 import Server, Connection, ALL, MODIFY_REPLACE
from datetime import datetime

# ============================================================
# CONFIGURACOES GERAIS
# ============================================================

# --- REDE ---
# IMPORTANTE: Verifique se é 'ens38', 'eth0', 'enp0s1' usando 'ip a'
NET_INTERFACE = 'ens34'

# --- LDAP ---
LDAP_HOST = '172.16.102.100'
LDAP_PORT = 389
BIND_DN   = 'cn=admin,dc=carto,dc=org'
BIND_PASS = '33028729'
BASE_DN   = 'dc=carto,dc=org'

# --- CARGA ---
TOTAL_USERS = 5000
NUM_THREADS = 50 

# ============================================================
# VARIAVEIS GLOBAIS
# ============================================================
user_queue = queue.Queue()
success_count = 0
fail_count = 0
lock = threading.Lock()

# ============================================================
# MÓDULO DE REDE (TRAFFIC SHAPING) - MELHORADO
# ============================================================
def run_shell(command):
    try:
        subprocess.run(command, shell=True, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def validar_interface():
    """ Verifica se a interface existe no sistema operacional """
    path = f"/sys/class/net/{NET_INTERFACE}"
    if not os.path.exists(path):
        print("\n" + "!"*60)
        print(f"[ERRO CRITICO] A interface de rede '{NET_INTERFACE}' NAO EXISTE!")
        print(f"Por favor, edite o script e corrija a variavel NET_INTERFACE.")
        print(f"Interfaces disponiveis: {os.listdir('/sys/class/net/')}")
        print("!"*60 + "\n")
        return False
    return True

def verificar_regra_ativa():
    """ Consulta o Kernel e mostra a regra atual """
    cmd = f"tc qdisc show dev {NET_INTERFACE}"
    try:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding='utf-8')
        if res.stdout:
            print(f"   [KERNEL CONFIRMA] {res.stdout.strip()}")
        else:
            print(f"   [KERNEL] Nenhuma regra ativa (Padrão).")
    except Exception as e:
        print(f"   [AVISO] Não foi possível ler o estado da rede: {str(e)}")

def reset_network():
    if not validar_interface(): return
    print(f"   [REDE] Limpando regras na interface {NET_INTERFACE}...")
    run_shell(f"tc qdisc del dev {NET_INTERFACE} root")

def apply_network(delay, loss, desc):
    # 1. Validação
    if not validar_interface():
        input("Pressione ENTER para voltar e corrigir o script...")
        return

    # 2. Limpeza
    reset_network()

    # 3. Aplicação
    if delay == 0 and loss == 0:
        print(f"   [REDE] Aplicado: Baseline (Sem degradação)")
    else:
        print(f"   [REDE] Aplicado: {desc} (Delay {delay}ms | Loss {loss}%)")
        cmd = f"tc qdisc add dev {NET_INTERFACE} root netem delay {delay}ms loss {loss}%"
        subprocess.run(cmd, shell=True, check=True)
    
    # 4. Confirmação Real
    verificar_regra_ativa()

# ============================================================
# WORKERS LDAP (THREADS)
# ============================================================

def worker_add(timeout_val):
    global success_count, fail_count
    server = Server(LDAP_HOST, port=LDAP_PORT, get_info=ALL, connect_timeout=timeout_val)
    conn = Connection(server, BIND_DN, BIND_PASS, auto_bind=False)
    
    while not user_queue.empty():
        try:
            uid, cn, sn = user_queue.get(block=False)
            if not conn.bound:
                if not conn.bind(): raise Exception("Bind Failed")

            dn = f"uid={uid},{BASE_DN}"
            attrs = {
                'objectClass': ['top', 'person', 'organizationalPerson', 'inetOrgPerson', 'posixAccount'],
                'cn': cn, 'sn': sn, 'uid': uid, 'userPassword': 'password123',
                'uidNumber': str(10000 + int(uid.split('_')[-1])), 
                'gidNumber': '500', 'homeDirectory': f'/home/{uid}'
            }

            if conn.add(dn, attributes=attrs):
                with lock: success_count += 1
            else:
                with lock: fail_count += 1
            
            user_queue.task_done()
        except queue.Empty: break
        except Exception: 
            with lock: fail_count += 1
            conn.unbind()
    conn.unbind()

def worker_modify(timeout_val):
    global success_count, fail_count
    server = Server(LDAP_HOST, port=LDAP_PORT, get_info=ALL, connect_timeout=timeout_val)
    conn = Connection(server, BIND_DN, BIND_PASS, auto_bind=False)
    
    while not user_queue.empty():
        try:
            uid, new_desc = user_queue.get(block=False)
            if not conn.bound:
                if not conn.bind(): raise Exception("Bind Failed")

            dn = f"uid={uid},{BASE_DN}"
            changes = {'description': [(MODIFY_REPLACE, [new_desc])]}
            
            if conn.modify(dn, changes):
                with lock: success_count += 1
            else:
                with lock: fail_count += 1
            user_queue.task_done()
        except queue.Empty: break
        except Exception:
            with lock: fail_count += 1
            conn.unbind()
    conn.unbind()

def worker_delete(timeout_val):
    global success_count, fail_count
    server = Server(LDAP_HOST, port=LDAP_PORT, get_info=ALL, connect_timeout=timeout_val)
    conn = Connection(server, BIND_DN, BIND_PASS, auto_bind=False)
    
    while not user_queue.empty():
        try:
            uid = user_queue.get(block=False)
            if not conn.bound:
                if not conn.bind(): raise Exception("Bind Failed")

            dn = f"uid={uid},{BASE_DN}"
            if conn.delete(dn):
                with lock: success_count += 1
            else:
                with lock: fail_count += 1
            user_queue.task_done()
        except queue.Empty: break
        except Exception:
            with lock: fail_count += 1
            conn.unbind()
    conn.unbind()

# ============================================================
# ORQUESTRADOR DO TESTE
# ============================================================

def preparar_fila(mode):
    global success_count, fail_count
    with user_queue.mutex: user_queue.queue.clear()
    success_count = 0
    fail_count = 0
    
    print(f"[INFO] Populando fila para {mode.upper()} ({TOTAL_USERS} itens)...")
    
    if mode == 'insert':
        for i in range(TOTAL_USERS):
            user_queue.put((f"user_ldap_{i}", f"User LDAP {i}", "LDAP Family"))
    elif mode == 'update':
        ts = datetime.now().strftime('%H:%M:%S')
        for i in range(TOTAL_USERS):
            user_queue.put((f"user_ldap_{i}", f"LDAP Modificado em {ts}"))
    elif mode == 'delete':
        for i in range(TOTAL_USERS):
            user_queue.put(f"user_ldap_{i}")

def run_test_cycle(mode, timeout_val):
    # Verifica se a interface existe antes de gastar tempo preparando fila
    if not validar_interface():
        input("Pressione ENTER para continuar...")
        return

    preparar_fila(mode)
    
    print(f"--- INICIANDO DISPARO LDAP ({mode.upper()}) ---")
    print(f"Threads: {NUM_THREADS} | Timeout: {timeout_val}s")
    
    start_time = time.time()
    
    threads = []
    target_func = None
    
    if mode == 'insert': target_func = worker_add
    elif mode == 'update': target_func = worker_modify
    elif mode == 'delete': target_func = worker_delete
    
    for _ in range(NUM_THREADS):
        t = threading.Thread(target=target_func, args=(timeout_val,))
        t.start()
        threads.append(t)
        
    for t in threads:
        t.join()
        
    end_time = time.time()
    duration = end_time - start_time
    throughput = TOTAL_USERS / duration if duration > 0 else 0

    print("-" * 60)
    print(f"RELATORIO FINAL LDAP ({mode.upper()}):")
    print(f"[SUCESSO] Operações OK..: {success_count}")
    print(f"[FALHA]   Erros.........: {fail_count}")
    print("-" * 60)
    print(f"Tempo Total: {duration:.2f} s")
    print(f"Throughput:  {throughput:.0f} ops/seg")
    print("-" * 60)
    input("\nPressione Enter para continuar...")

# ============================================================
# MENUS INTERATIVOS
# ============================================================

def get_network_scenario():
    print("\n" + "="*50)
    print("SELECIONE O CENÁRIO DE REDE:")
    print("-" * 50)
    print("0) Baseline (0ms, 0% loss)")
    print("1) Satélite (600ms, 1% loss)")
    print("2) Rádio Tático (100ms, 5% loss)")
    print("3) Desastre (200ms, 15% loss)")
    print("4) Caos Extremo (500ms, 40% loss)")
    print("5) Degradação Parcial (800ms, 70% loss)")
    print("6) Degradação Total (1200ms, 95% loss)")
    print("=" * 50)
    try:
        opt = int(input("Opção: "))
        scenarios = {
            0: (0, 0, "Baseline"),
            1: (600, 1, "Satélite"),
            2: (100, 5, "Rádio Tático"),
            3: (200, 15, "Desastre"),
            4: (500, 40, "Caos Extremo"),
            5: (800, 70, "Degradação Parcial"),
            6: (1200, 95, "Degradação Total")
        }
        return scenarios.get(opt, (0, 0, "Baseline"))
    except:
        return (0, 0, "Baseline")

def main_menu():
    if os.geteuid() != 0:
        print("ERRO: Execute este script como ROOT (sudo) para controlar a rede.")
        sys.exit(1)

    # Validacao inicial ao abrir o programa
    validar_interface()

    while True:
        os.system('clear')
        print("="*60)
        print("   MASTER JOGADOR LDAP - IME (Python Threading)")
        print("="*60)
        print("1) Inserir Usuários (Carga Massiva)")
        print("2) Modificar Usuários (Stress Update)")
        print("3) Deletar Usuários (Wipe)")
        print("0) Sair e Limpar Rede")
        print("="*60)
        
        opt = input("Selecione a atividade: ")
        
        if opt == '0':
            reset_network()
            print("Saindo...")
            sys.exit(0)
        
        elif opt in ['1', '2', '3']:
            mode = ""
            if opt == '1': mode = "insert"
            elif opt == '2': mode = "update"
            elif opt == '3': mode = "delete"
            
            # 1. Configurar Rede
            delay, loss, desc = get_network_scenario()
            
            # Timeout inteligente
            timeout = 1000
            

            apply_network(delay, loss, desc)
            
            # 2. Rodar Teste
            print(f"\nPreparando ambiente LDAP ({mode.upper()})...")
            time.sleep(1)
            try:
                run_test_cycle(mode, timeout)
            except KeyboardInterrupt:
                print("\n[!] Interrompido pelo usuário.")
            
            # 3. Limpar Rede
            reset_network()
            
        else:
            print("Opção inválida.")
            time.sleep(1)

if __name__ == "__main__":
    try:
        main_menu()
    except KeyboardInterrupt:
        reset_network()
        print("\nSaindo.")
