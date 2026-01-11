# CARTIO: Reference Implementation and Tactical Lab Setup

This directory contains the core implementation of the CARTIO (Common Auxiliary Registry for Tactical Operations) protocol, along with the automation scripts used to deploy, test, and validate the experimental laboratory.

## Project Overview
The CARTIO project provides a resilient Identity Management (IdM) solution for DIL (Disconnected, Intermittent, and Limited) networks. It shifts the tactical synchronization paradigm from verbose text-based protocols (such as SCIM/JSON) to a highly optimized binary approach using LDAP (Lightweight Directory Access Protocol) with custom tactical schemas.

## Directory Structure

- _ldap-sync-traditional/: Legacy LDAP synchronization scripts for comparison.
- scim_sync_traditional/: SCIM-based synchronization scripts (Baseline).
- schema/: Tactical LDAP schema definitions (.ldif).
- scim_server/: Comparative SCIM server implementation (Flask-based).
- scim_client/: Reference client for synchronization tests.
- setup_ldap.sh: Master script for OpenLDAP environment configuration.
- rodar_experimento.sh: Main orchestration script for tactical scenarios.
- gerar_dados.sh: Script for population of the tactical directory.
- medir_lag.sh: Latency and synchronization lag measurement tools.

## Prerequisites

### Environment
- Operating System: Debian 12 (Kernel 6.1 LTS) recommended.
- Architectures Supported: x86_64 and ARM64 (Apple Silicon).
- Hardware Matrix: Validated for both SSD (High-Speed NVMe) and HDD (Legacy 5400 RPM).

### Software Dependencies
- OpenLDAP 2.5+
- Python 3.12+
- NetEm (Linux Network Emulator) for DIL simulation.
- Tcpdump / Wireshark for network capture.

## Lab Setup Instructions

### 1. Initialize the Environment
Ensure all scripts have execution permissions:
```bash
chmod +x *.sh
### 2. Configure LDAP Infrastructure

Run the setup script to import the CARTIO tactical schema and configure the MMR (Multi-Master Replication) environment:

```bash
./setup_ldap.sh
```

### 3. Deploy the SCIM Comparison Server (Optional)

If you wish to replicate the comparative SCIM-based analysis, deploy the reference server:

```bash
cd scim_server
pip install -r requirements.txt
python server.py
```

### 4. Running Experiments

The experiments are fully automated and designed to simulate five tactical network states (ranging from *Baseline* to *Chaos*).

To start the complete battery of tests, run:

```bash
./rodar_experimento.sh
```

## Methodology

The experimental scripts inject controlled network faults using `tc/netem`, including:

- Packet loss
- Latency
- Jitter

These conditions emulate information survivability in extreme DIL environments.  
Network traffic is captured in `.pcap` files and later consolidated into `.csv` datasets for analytical processing and comparison.

## Academic Credit

Developed by **Wagner Philippe Calazans** as part of the Master's Thesis in Computer Engineering at the **Military Institute of Engineering (IME)**, Rio de Janeiro, Brazil.

### Citation

If you use these scripts or the CARTIO protocol in academic or technical research, please refer to the `CITATION.cff` file located in the root directory of this repository.

### Project Website

- https://cartio.org
