#!/usr/bin/env python3
# ============================================================
# Projeto CARTO
# Autoria: Wagner P Calazans
# Ano de criação: 2025
# Versao: 1.2 (Auto-Retry)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_jogador_modificar_usuarios.py
# Descrição: Modificacao massiva SCIM com persistência de falhas
# ============================================================

import asyncio
import aiohttp
import time
from datetime import datetime

# CONFIGURACAO
SERVER_BASE = "http://172.16.102.100:5000/Users"
TOTAL_USERS = 5000
CONCURRENCY_LIMIT = 50

async def update_user(session, user_id, timestamp):
    url = f"{SERVER_BASE}/user{user_id}"
    payload = {
        "description": f"Modificado em {timestamp} via SCIM (Ronda Persistente)"
    }
    try:
        async with session.put(url, json=payload) as response:
            if response.status == 200:
                return user_id, "SUCCESS"
            else:
                return user_id, "SERVER_ERROR"
    except Exception:
        return user_id, "CONN_ERROR"

async def main():
    print("------------------------------------------------------------")
    print(f"INICIO DA MODIFICACAO SCIM (MODO PERSISTENTE)")
    print(f"Alvo: {SERVER_BASE}/<uid>")
    print("------------------------------------------------------------")
    
    start_time = time.time()
    current_time = datetime.now().strftime("%H:%M:%S")
    
    pending_users = list(range(1, TOTAL_USERS + 1))
    
    rounds = 0
    total_failures_accumulated = 0
    
    connector = aiohttp.TCPConnector(limit=CONCURRENCY_LIMIT)
    timeout = aiohttp.ClientTimeout(total=5)
    
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        
        while pending_users:
            rounds += 1
            print(f"\n>>> INICIANDO RONDA {rounds}")
            print(f"    Alvos restantes: {len(pending_users)}")
            
            tasks = []
            for uid in pending_users:
                tasks.append(update_user(session, uid, current_time))
            
            results = await asyncio.gather(*tasks)
            
            pending_users = []
            round_failures = 0
            
            for uid, status in results:
                if status != "SUCCESS":
                    pending_users.append(uid)
                    round_failures += 1
                    total_failures_accumulated += 1
            
            if pending_users:
                print(f"    [FALHA] {round_failures} erros. Aguardando recuperacao do servidor...")
                await asyncio.sleep(2)
            else:
                print("    [SUCESSO] Todos processados nesta ronda.")

    end_time = time.time()
    duration = end_time - start_time
    
    print("------------------------------------------------------------")
    print(f"RELATORIO FINAL (MODIFICACAO):")
    print(f"[STATUS]  Todos os {TOTAL_USERS} usuarios foram atualizados.")
    print(f"[RODADAS] Necessarias....: {rounds}")
    print(f"[FALHAS]  Erros superados: {total_failures_accumulated}")
    print("------------------------------------------------------------")
    print(f"Tempo Total: {duration:.2f} segundos")
    print("------------------------------------------------------------")

if __name__ == "__main__":
    asyncio.run(main())
