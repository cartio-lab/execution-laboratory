#!/usr/bin/env python3
# ============================================================
# Projeto CARTO
# Autoria: Wagner Calazans
# Ano de criação: 2025
# Versao: 1.2 (Auto-Retry)
# IME - Instituto Militar de Engenharia
#
# Arquivo: scim_jogador_deletar_usuarios.py
# Descrição: Delecao persistente com re-tentativas automáticas
# ============================================================

import asyncio
import aiohttp
import time

# CONFIGURACAO
SERVER_BASE = "http://172.16.102.100:5000/Users"
TOTAL_USERS = 5000
CONCURRENCY_LIMIT = 50 # Mantemos a pressao alta

async def delete_user(session, user_id):
    url = f"{SERVER_BASE}/user{user_id}"
    try:
        async with session.delete(url) as response:
            # 204 = Deletado, 404 = Ja nao existe (Sucesso)
            if response.status in [204, 404]:
                return user_id, "SUCCESS"
            else:
                return user_id, "SERVER_ERROR"
    except Exception:
        return user_id, "CONN_ERROR"

async def main():
    print("------------------------------------------------------------")
    print(f"INICIO DA DELECAO SCIM (MODO PERSISTENTE)")
    print(f"Alvo: {SERVER_BASE}/<uid>")
    print("------------------------------------------------------------")
    
    start_time = time.time()
    
    # Lista inicial: Todos os usuarios de 1 a 5000
    pending_users = list(range(1, TOTAL_USERS + 1))
    
    rounds = 0
    total_failures_accumulated = 0
    
    connector = aiohttp.TCPConnector(limit=CONCURRENCY_LIMIT)
    timeout = aiohttp.ClientTimeout(total=5) # Timeout curto para falhar rapido e tentar de novo
    
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        
        # Loop enquanto houver usuarios pendentes
        while pending_users:
            rounds += 1
            print(f"\n>>> INICIANDO RONDA {rounds}")
            print(f"    Alvos restantes: {len(pending_users)}")
            
            tasks = []
            for uid in pending_users:
                tasks.append(delete_user(session, uid))
            
            # Dispara a bateria de tentativas
            results = await asyncio.gather(*tasks)
            
            # Limpa a lista para verificar quem ainda sobra
            pending_users = []
            round_failures = 0
            
            for uid, status in results:
                if status != "SUCCESS":
                    pending_users.append(uid) # Adiciona na lista para a proxima volta
                    round_failures += 1
                    total_failures_accumulated += 1
            
            if pending_users:
                print(f"    [FALHA] {round_failures} erros nesta ronda.")
                print("    A aguardar 2 segundos para o servidor recuperar...")
                await asyncio.sleep(2)
            else:
                print("    [SUCESSO] Todos os usuarios da ronda foram processados.")

    end_time = time.time()
    duration = end_time - start_time
    
    print("------------------------------------------------------------")
    print(f"RELATORIO FINAL (PERSISTENCIA):")
    print(f"[STATUS]  Todos os {TOTAL_USERS} usuarios foram deletados.")
    print(f"[RODADAS] Necessarias....: {rounds}")
    print(f"[FALHAS]  Erros superados: {total_failures_accumulated}")
    print("------------------------------------------------------------")
    print(f"Tempo Total: {duration:.2f} segundos")
    print("------------------------------------------------------------")

if __name__ == "__main__":
    asyncio.run(main())
