#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
# Projeto CARTO
# Autoria: Wagner P Calazans
# Versao: 1.6 (Auto-Detecção de Interface de Rede)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_py_jogador_master.py
# Descrição: Orquestrador SCIM Completo.
#            1. Detecta Interface de Rede ativa Automaticamente.
#            2. Auto-VENV.
#            3. Carga, Modificação e Deleção Persistente.
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

# --- A PARTIR DAQUI, ESTAMOS NO AMBIENTE SEGURO ---
import time
import subprocess
import asyncio
import aiohttp
from datetime import datetime

# --- CONFIGURAÇÕES SCIM ---
SERVER_BASE = "http://172.16.102.100:5000/Users"
TOTAL_USERS = 5000
CONCURRENCY_LIMIT = 50 

# ============================================================
# FUNÇÃO INTELIGENTE DE DETECÇÃO DE REDE
# ============================================================
def get_active_interface():
    """ Tenta descobrir qual interface tem o IP da rede local """
    try:
        # Pega todas as interfaces exceto Loopback
        interfaces = os.listdir('/sys/class/net/')
        interfaces = [iface for iface in interfaces if iface != 'lo']
        
        # Se só tem uma, usa ela
        if len(interfaces) == 1:
            return interfaces[0]
            
        # Se tem mais de uma, tenta achar a que tem rota padrão ou IP configurado
        cmd = "ip route | grep default | awk '{print $5}'"
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, encoding='utf-8')
        detected = res.stdout.strip()
        
        if detected and detected in interfaces:
            return detected
            
        # Fallback: Retorna a primeira da lista (geralmente ens33/ens38)
        return interfaces[0]
        
    except Exception:
        return "ens38" # Default inseguro

# Define a interface automaticamente ao iniciar
INTERFACE = get_active_interface()

# ============================================================
# MÓDULO DE REDE (TRAFFIC SHAPING)
# ============================================================
def run_shell(command):
    try:
        subprocess.run(command, shell=True, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def verificar_regra_ativa():
    cmd = f"tc qdisc show dev {INTERFACE}"
    try:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding='utf-8')
        if res.stdout:
            print(f"   [KERNEL CONFIRMA] {res.stdout.strip()}")
        else:
            print(f"   [KERNEL] Nenhuma regra ativa (Padrão).")
    except Exception:
        pass

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
        try:
            subprocess.run(cmd, shell=True, check=True)
        except subprocess.CalledProcessError:
            print("\n" + "!"*60)
            print(f"[ERRO] Falha ao aplicar regra na interface '{INTERFACE}'.")
            print("Verifique se o nome da interface está correto.")
            print(f"Sugestão: Rode 'ip a' e edite a variável INTERFACE no script.")
            print("!"*60 + "\n")
            input("Pressione ENTER para continuar sem rede degradada...")
            return

    verificar_regra_ativa()

# ============================================================
# WORKERS SCIM (ASYNC)
# ============================================================
async def create_user(session, user_id):
    payload = {
        "id": f"user{user_id}",
        "userName": f"Utilizador Teste {user_id}",
        "description": "Carga Inicial SCIM"
    }
    try:
        async with session.post(SERVER_BASE, json=payload) as response:
            if response.status == 201: return user_id, "SUCCESS"
            elif response.status == 400: return user_id, "ALREADY_EXISTS"
            else: return user_id, "SERVER_ERROR"
    except Exception: return user_id, "CONN_ERROR"

async def update_user(session, user_id):
    ts = datetime.now().strftime("%H:%M:%S")
    url = f"{SERVER_BASE}/user{user_id}"
    payload = {"description": f"Modificado em {ts} via SCIM (Ronda Persistente)"}
    try:
        async with session.put(url, json=payload) as response:
            if response.status == 200: return user_id, "SUCCESS"
            else: return user_id, "SERVER_ERROR"
    except Exception: return user_id, "CONN_ERROR"

async def delete_user(session, user_id):
    url = f"{SERVER_BASE}/user{user_id}"
    try:
        async with session.delete(url) as response:
            if response.status in [204, 404]: return user_id, "SUCCESS"
            else: return user_id, "SERVER_ERROR"
    except Exception: return user_id, "CONN_ERROR"

# ============================================================
# CORE DO TESTE (LOOP PERSISTENTE)
# ============================================================
async def run_persistent_test(mode, timeout_val):
    print("-" * 60)
    print(f"INICIANDO: SCIM {mode.upper()} (MODO PERSISTENTE/RETRY)")
    print(f"Workers: {CONCURRENCY_LIMIT} | Timeout: {timeout_val}s | Alvo: {SERVER_BASE}")
    print("-" * 60)
    
    start_time = time.time()
    pending_users = list(range(1, TOTAL_USERS + 1))
    rounds = 0
    stats = {"SUCCESS": 0, "ALREADY_EXISTS": 0, "RETRIES": 0}
    
    connector = aiohttp.TCPConnector(limit=CONCURRENCY_LIMIT)
    timeout = aiohttp.ClientTimeout(total=timeout_val)
    
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        while pending_users:
            rounds += 1
            print(f"\n>>> RONDA {rounds}: {len(pending_users)} itens pendentes...")
            
            tasks = []
            for uid in pending_users:
                if mode == 'insert': tasks.append(create_user(session, uid))
                elif mode == 'update': tasks.append(update_user(session, uid))
                else: tasks.append(delete_user(session, uid))
            
            results = await asyncio.gather(*tasks)
            pending_users = [] 
            round_failures = 0
            
            for uid, status in results:
                if status == "SUCCESS": stats["SUCCESS"] += 1
                elif status == "ALREADY_EXISTS": stats["ALREADY_EXISTS"] += 1
                else:
                    pending_users.append(uid)
                    round_failures += 1
                    stats["RETRIES"] += 1
            
            if pending_users:
                print(f"    [FALHA] {round_failures} erros. Aguardando recuperação...")
                await asyncio.sleep(2)
            else:
                print("    [SUCESSO] Ronda limpa.")

    total_time = time.time() - start_time
    
    print("-" * 60)
    print(f"RELATORIO FINAL ({mode.upper()}):")
    print(f"[STATUS]  Todos os {TOTAL_USERS} usuários processados.")
    print(f"[RODADAS] Necessárias....: {rounds}")
    if mode == 'insert':
        print(f"[CRIADOS] Novos..........: {stats['SUCCESS']}")
        print(f"[EXISTE]  Já existiam....: {stats['ALREADY_EXISTS']}")
    print(f"[RETRYS]  Falhas de Rede.: {stats['RETRIES']}")
    print("-" * 60)
    print(f"Tempo Total: {total_time:.2f} s")
    print("-" * 60)
    input("\nPressione Enter para continuar...")

# ============================================================
# MENU
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
            0: (0, 0, "Baseline"), 1: (600, 1, "Satélite"), 2: (100, 5, "Rádio Tático"),
            3: (200, 15, "Desastre"), 4: (500, 40, "Caos Extremo"), 5: (800, 70, "Degradação Parcial"),
            6: (1200, 95, "Degradação Total")
        }
        return scenarios.get(opt, (0, 0, "Baseline"))
    except: return (0, 0, "Baseline")

def main_menu():
    if os.geteuid() != 0:
        print("ERRO: Execute como ROOT (sudo).")
        sys.exit(1)
        
    print(f"[SISTEMA] Interface detectada: {INTERFACE}")

    while True:
        os.system('clear')
        print("="*60)
        print(f"   MASTER JOGADOR SCIM - IME (Interface: {INTERFACE})")
        print("="*60)
        print("1) Inserir Usuários (Persistente)")
        print("2) Modificar Usuários (Persistente)")
        print("3) Deletar Usuários (Persistente)")
        print("0) Sair e Limpar Rede")
        print("="*60)
        
        opt = input("Selecione a atividade: ")
        
        if opt == '0':
            reset_network()
            print("Saindo...")
            sys.exit(0)
        
        elif opt in ['1', '2', '3']:
            mode = "insert" if opt == '1' else "update" if opt == '2' else "delete"
            
            delay, loss, desc = get_network_scenario()
            timeout = 3 if loss >= 90 else 5
            
            apply_network(delay, loss, desc)
            
            print(f"\nIniciando bateria SCIM ({mode.upper()})...")
            time.sleep(1)
            try:
                if sys.version_info >= (3, 7): asyncio.run(run_persistent_test(mode, timeout))
                else: loop = asyncio.get_event_loop(); loop.run_until_complete(run_persistent_test(mode, timeout))
            except KeyboardInterrupt: print("\n[!] Interrompido.")
            
            reset_network()
        else:
            print("Opção inválida.")
            time.sleep(1)

if __name__ == "__main__":
    try: main_menu()
    except KeyboardInterrupt: reset_network(); print("\nSaindo...")
