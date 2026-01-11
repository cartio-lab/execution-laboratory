#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
# Projeto CARTO
# Autoria: Wagner P Calazans
# Versao: 2.0 (SSL/HTTPS - Security Mode)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_py_jogador_master.py
# Descrição: Cliente SCIM via HTTPS (Porta 5000).
#            - Ignora validação de certificado (Self-Signed).
# ============================================================

import sys
import os
import socket

# --- AUTO-VERIFICAÇÃO DE AMBIENTE VIRTUAL ---
VENV_PYTHON = "/opt/scim_client/venv/bin/python3"
if sys.executable != VENV_PYTHON:
    if os.path.exists(VENV_PYTHON):
        print(f"[BOOT] Reiniciando no VENV: {VENV_PYTHON}...")
        os.execv(VENV_PYTHON, [VENV_PYTHON] + sys.argv)

import time
import subprocess
import asyncio
import aiohttp
from datetime import datetime

# --- CONFIGURAÇÕES SCIM (SSL ATIVO) ---
# Note o 'https'
SERVER_BASE = "https://172.16.102.100:5000/Users"
TOTAL_USERS = 5000
CONCURRENCY_LIMIT = 50 

def get_active_interface():
    try:
        interfaces = os.listdir('/sys/class/net/')
        interfaces = [iface for iface in interfaces if iface != 'lo']
        if len(interfaces) == 1: return interfaces[0]
        cmd = "ip route | grep default | awk '{print $5}'"
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, encoding='utf-8')
        detected = res.stdout.strip()
        if detected and detected in interfaces: return detected
        return interfaces[0]
    except: return "ens38"

INTERFACE = get_active_interface()

# ============================================================
# REDE
# ============================================================
def run_shell(command):
    try: subprocess.run(command, shell=True, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except: pass

def verificar_regra_ativa():
    try:
        res = subprocess.run(f"tc qdisc show dev {INTERFACE}", shell=True, stdout=subprocess.PIPE, encoding='utf-8')
        if res.stdout: print(f"   [KERNEL CONFIRMA] {res.stdout.strip()}")
        else: print(f"   [KERNEL] Nenhuma regra ativa (Padrão).")
    except: pass

def reset_network():
    print(f"   [REDE] Limpando regras na interface {INTERFACE}...")
    run_shell(f"tc qdisc del dev {INTERFACE} root")

def apply_network(delay, loss, desc):
    reset_network()
    if delay == 0 and loss == 0:
        print(f"   [REDE] Aplicado: Baseline (Sem degradação)")
    else:
        print(f"   [REDE] Aplicado: {desc} (Delay {delay}ms | Loss {loss}%)")
        cmd = f"tc qdisc add dev {INTERFACE} root netem delay {delay}ms loss {loss}%"
        try: subprocess.run(cmd, shell=True, check=True)
        except: print("[ERRO] Falha ao aplicar regra de rede."); return
    verificar_regra_ativa()

# ============================================================
# WORKERS SCIM (COM SSL CONTEXT)
# ============================================================
async def create_user(session, user_id):
    payload = {"id": f"user{user_id}", "userName": f"Utilizador Teste {user_id}", "description": "Carga SSL"}
    try:
        async with session.post(SERVER_BASE, json=payload) as response:
            if response.status == 201: return user_id, "SUCCESS"
            elif response.status == 400: return user_id, "ALREADY_EXISTS"
            else: return user_id, "SERVER_ERROR"
    except: return user_id, "CONN_ERROR"

async def update_user(session, user_id):
    url = f"{SERVER_BASE}/user{user_id}"
    payload = {"description": f"Modificado via SSL em {datetime.now()}"}
    try:
        async with session.put(url, json=payload) as response:
            if response.status == 200: return user_id, "SUCCESS"
            else: return user_id, "SERVER_ERROR"
    except: return user_id, "CONN_ERROR"

async def delete_user(session, user_id):
    url = f"{SERVER_BASE}/user{user_id}"
    try:
        async with session.delete(url) as response:
            if response.status in [204, 404]: return user_id, "SUCCESS"
            else: return user_id, "SERVER_ERROR"
    except: return user_id, "CONN_ERROR"

# ============================================================
# CORE
# ============================================================
async def run_persistent_test(mode, timeout_val):
    print("-" * 60)
    print(f"INICIANDO: SCIM {mode.upper()} (HTTPS/SSL)")
    print(f"Workers: {CONCURRENCY_LIMIT} | Timeout: {timeout_val}s | Alvo: {SERVER_BASE}")
    print("-" * 60)
    
    start_time = time.time()
    pending_users = list(range(1, TOTAL_USERS + 1))
    rounds = 0
    stats = {"SUCCESS": 0, "ALREADY_EXISTS": 0, "RETRIES": 0}
    
    # --- AQUI ESTA A MUDANCA PARA SSL ---
    # ssl=False desativa a verificacao do certificado, mas mantem a criptografia
    connector = aiohttp.TCPConnector(limit=CONCURRENCY_LIMIT, ssl=False)
    timeout = aiohttp.ClientTimeout(total=timeout_val)
    
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        while pending_users:
            rounds += 1
            print(f"\n>>> RONDA {rounds}: {len(pending_users)} pendentes...")
            tasks = []
            for uid in pending_users:
                if mode == 'insert': tasks.append(create_user(session, uid))
                elif mode == 'update': tasks.append(update_user(session, uid))
                else: tasks.append(delete_user(session, uid))
            
            results = await asyncio.gather(*tasks)
            pending_users = []
            
            for uid, status in results:
                if status == "SUCCESS": stats["SUCCESS"] += 1
                elif status == "ALREADY_EXISTS": stats["ALREADY_EXISTS"] += 1
                else: pending_users.append(uid); stats["RETRIES"] += 1
            
            if pending_users: await asyncio.sleep(2)

    total_time = time.time() - start_time
    print("-" * 60)
    print(f"FIM ({mode.upper()}) | Tempo: {total_time:.2f}s | Retries: {stats['RETRIES']}")
    print("-" * 60)
    input("Enter...")

# ============================================================
# MENU
# ============================================================
def main_menu():
    if os.geteuid() != 0: print("Precisa de ROOT"); sys.exit(1)
    
    while True:
        os.system('clear')
        print("="*60)
        print(f"   MASTER JOGADOR SCIM (HTTPS/SSL) - Interface: {INTERFACE}")
        print("="*60)
        print("1) Inserir | 2) Modificar | 3) Deletar | 0) Sair")
        opt = input("Opcao: ")
        
        if opt == '0': reset_network(); sys.exit(0)
        elif opt in ['1', '2', '3']:
            mode = "insert" if opt == '1' else "update" if opt == '2' else "delete"
            
            # Submenu de Rede
            print("\nCenarios: 0)Baseline 1)Sat 2)Radio 3)Desastre 4)Caos 5)DegParcial 6)DegTotal")
            try: rede_opt = int(input("Cenario Rede (0-6): "))
            except: rede_opt = 0
            
            cenarios = {0:(0,0,"Base"), 1:(600,1,"Sat"), 2:(100,5,"Radio"), 3:(200,15,"Desastre"), 
                        4:(500,40,"Caos"), 5:(800,70,"DegP"), 6:(1200,95,"DegT")}
            delay, loss, desc = cenarios.get(rede_opt, (0,0,"Base"))
            
            # Timeout inteligente
            timeout = 3 if loss >= 90 else 5
            
            apply_network(delay, loss, desc)
            
            try:
                if sys.version_info >= (3, 7): asyncio.run(run_persistent_test(mode, timeout))
                else: loop = asyncio.get_event_loop(); loop.run_until_complete(run_persistent_test(mode, timeout))
            except KeyboardInterrupt: pass
            
            reset_network()

if __name__ == "__main__":
    main_menu()
