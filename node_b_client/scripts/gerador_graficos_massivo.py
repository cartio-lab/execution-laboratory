#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import subprocess
import pandas as pd
import matplotlib.pyplot as plt
import io

# --- CONFIGURAÇÕES DE DIRETÓRIO ---
# Onde estão os arquivos originais (.pcap)
DIR_ORIGEM = "/opt/resultados"

# Onde serão salvos os gráficos e CSVs (Estrutura Espelhada)
DIR_DESTINO = "/opt/resultados_graph"

def processar_pcap(caminho_pcap, pasta_saida):
    nome_arquivo = os.path.basename(caminho_pcap)
    base_name = nome_arquivo.replace('.pcap', '')
    
    print(f" -> Processando: {nome_arquivo}")

    # 1. TShark: Extração
    cmd = [
        "tshark", "-r", caminho_pcap, 
        "-T", "fields", 
        "-e", "frame.time_relative", 
        "-e", "frame.len", 
        "-E", "separator=,", 
        "-E", "header=n"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if not result.stdout:
            print(f"    [AVISO] Arquivo vazio ou inválido: {nome_arquivo}")
            return

        # 2. Pandas: Cálculos
        data = io.StringIO(result.stdout)
        # Tenta ler, se falhar (arquivo vazio ou corrompido), pula
        try:
            df = pd.read_csv(data, names=["time", "bytes"])
        except pd.errors.EmptyDataError:
            print(f"    [PULADO] Sem dados no pcap.")
            return

        df['segundo'] = df['time'].astype(float).astype(int)
        
        # Converte Bytes -> Megabits (Mbps)
        throughput = df.groupby('segundo')['bytes'].sum() * 8 / 1000000
        
        # Preenche buracos de tempo com 0
        if not throughput.empty:
            throughput = throughput.reindex(range(int(throughput.index.min()), int(throughput.index.max()) + 1), fill_value=0)

        # 3. Exportação
        
        # A) CSV (Vetor numérico)
        caminho_csv = os.path.join(pasta_saida, f"{base_name}_vetor.csv")
        throughput.to_csv(caminho_csv, header=["Mbps"])
        
        # B) Gráfico PNG
        plt.figure(figsize=(10, 5))
        plt.plot(throughput.index, throughput.values, label=f'{base_name}', color='#1f77b4', linewidth=1.5)
        plt.fill_between(throughput.index, throughput.values, color='#1f77b4', alpha=0.1) # Um charme visual
        
        plt.title(f"Throughput Network: {base_name}")
        plt.xlabel("Tempo (segundos)")
        plt.ylabel("Throughput (Mbps)")
        plt.grid(True, linestyle='--', alpha=0.5)
        plt.legend()
        plt.tight_layout()
        
        caminho_png = os.path.join(pasta_saida, f"{base_name}_grafico.png")
        plt.savefig(caminho_png, dpi=100)
        plt.close()
        
    except Exception as e:
        print(f"    [ERRO CRÍTICO] Falha em {nome_arquivo}: {e}")

def main():
    print("="*60)
    print(f"INICIANDO PROCESSAMENTO MASSIVO")
    print(f"Origem:  {DIR_ORIGEM}")
    print(f"Destino: {DIR_DESTINO}")
    print("="*60)

    # Caminha recursivamente por todas as pastas
    for root, dirs, files in os.walk(DIR_ORIGEM):
        
        # Ignora a própria pasta de destino se ela estiver dentro da origem (loop infinito)
        if DIR_DESTINO in root:
            continue

        # Calcula o caminho relativo (ex: ldap_ssl/02_Radio_Tatico)
        caminho_relativo = os.path.relpath(root, DIR_ORIGEM)
        
        # Cria o caminho correspondente no destino
        pasta_atual_destino = os.path.join(DIR_DESTINO, caminho_relativo)
        
        if not os.path.exists(pasta_atual_destino):
            os.makedirs(pasta_atual_destino)

        # Filtra apenas arquivos .pcap
        pcaps = [f for f in files if f.endswith('.pcap')]
        
        if pcaps:
            print(f"\n📂 Pasta: {caminho_relativo}")
            for arquivo in pcaps:
                caminho_completo_origem = os.path.join(root, arquivo)
                processar_pcap(caminho_completo_origem, pasta_atual_destino)

    print("\n" + "="*60)
    print("PROCESSAMENTO CONCLUÍDO COM SUCESSO!")
    print(f"Verifique os resultados em: {DIR_DESTINO}")

if __name__ == "__main__":
    main()
