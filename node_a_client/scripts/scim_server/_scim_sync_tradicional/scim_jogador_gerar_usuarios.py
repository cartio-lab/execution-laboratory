#!/usr/bin/env python3
# ============================================================
# Projeto CARTO
# Autoria: Wagner P Calazans
# Ano de criação: 2025
# Versao: 1.3 (Idempotente)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_jogador_gerar_usuarios.py
# Descrição: Carga massiva SCIM com tratamento de duplicidade
# ============================================================

import asyncio
import aiohttp
import time
import sys

# CONFIGURACAO
SERVER_URL = "http://172.16.102.100:5000/Users"
TOTAL_USERS = 5000
CONCURRENCY_LIMIT = 100

async def create_user(session, user_id):
    payload = {
        "id": f"user{user_id}",
        "userName": f"Utilizador Teste {user_id}",
        "description": "Carga Inicial SCIM"
    }
    try:
        async with session.post(SERVER_URL, json=payload) as response:
            # 201 = Created (Sucesso Limpo)
            if response.status == 201:
                return user_id, "SUCCESS"
            
            # 400 = Bad Request. No nosso servidor, isso geralmente eh
            # "duplicate key value violates unique constraint".
            # Se ja existe, consideramos que o objetivo foi atingido.
            elif response.status == 400:
                return user_id, "ALREADY_EXISTS"
            
            # Outros erros (500, 502) sao falhas reais de servidor
            else:
                return user_id, "SERVER_ERROR"

    except Exception:
        # Erro de rede/socket
        return user_id, "CONN_ERROR"

async def main():
    print("------------------------------------------------------------")
    print(f"INICIO DA CARGA SCIM (MODO IDEMPOTENTE)")
    print(f"Alvo: {SERVER_URL}")
    print("------------------------------------------------------------")
    
    start_time = time.time()
    
    # Lista inicial: Todos os usuarios
    pending_users = list(range(1, TOTAL_USERS + 1))
    
    rounds = 0
    failures_retryable = 0
    already_exists_count = 0
    
    connector = aiohttp.TCPConnector(limit=CONCURRENCY_LIMIT)
    timeout = aiohttp.ClientTimeout(total=5) 
    
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        
        while pending_users:
            rounds += 1
            print(f"\n>>> INICIANDO RONDA {rounds}")
            print(f"    Alvos restantes: {len(pending_users)}")
            
            tasks = []
            for uid in pending_users:
                tasks.append(create_user(session, uid))
            
            results = await asyncio.gather(*tasks)
            
            pending_users = []
            round_failures = 0
            
            for uid, status in results:
                if status == "SUCCESS":
                    pass # Sucesso pleno
                elif status == "ALREADY_EXISTS":
                    already_exists_count += 1
                    # Nao adicionamos em pending_users, pois ja esta la
                else:
                    # SERVER_ERROR ou CONN_ERROR -> Tenta de novo
                    pending_users.append(uid)
                    round_failures += 1
                    failures_retryable += 1
            
            if pending_users:
                print(f"    [FALHA] {round_failures} erros recuperaveis. Aguardando...")
                await asyncio.sleep(2)
            else:
                print("    [SUCESSO] Todos os usuarios desta ronda resolvidos.")

    end_time = time.time()
    duration = end_time - start_time
    
    print("------------------------------------------------------------")
    print(f"RELATORIO FINAL (CARGA):")
    print(f"[STATUS]  Carga finalizada.")
    print(f"[DETALHE] Criados novos...: {TOTAL_USERS - already_exists_count}")
    print(f"[DETALHE] Ja existiam.....: {already_exists_count} (Duplicatas/Recuperados)")
    print(f"[RODADAS] Necessarias.....: {rounds}")
    print(f"[RETRYS]  Falhas de Rede..: {failures_retryable}")
    print("------------------------------------------------------------")
    print(f"Tempo Total: {duration:.2f} segundos")
    print("------------------------------------------------------------")

if __name__ == "__main__":
    if sys.version_info < (3, 7):
        sys.exit(1)
    asyncio.run(main())
