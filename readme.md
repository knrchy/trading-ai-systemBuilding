chmod +x 01_os_setup.sh 02_configure_hostname_network.sh 03_install_docker.sh 04_install_k3s.sh 05_setup_git_repo.sh 06_setup_terraform.sh 07_setup_kubernetes_manifests.sh

./01_os_setup.sh
./02_configure_hostname_network.sh
./03_install_docker.sh
./04_install_k3s.sh
./05_setup_git_repo.sh
./06_setup_terraform.sh
./07_setup_kubernetes_manifests.sh

# Trading AI System

## Overview
This project sets up a complete infrastructure for a Trading AI System using Kubernetes (K3s), Docker, and Terraform. This document provides a high-level overview of the project, the setup process, and how to get started.

## Prerequisites
- Ubuntu 22.04 LTS Server
- Basic understanding of Docker, Kubernetes, and Terraform

## Project Structure
```bash
trading-ai-system/
├── infrastructure/
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── monitoring.tf
│   │   ├── providers.tf
│   │   └── terraform.tfvars
│   └── scripts/
│       ├── setup-master.sh
│       ├── add-worker.sh
│       ├── deploy-infrastructure.sh
│       ├── test-infrastructure.sh
│       ├── cleanup.sh
│       ├── backup.sh
│       ├── restore.sh
└── kubernetes/
    ├── namespaces.yaml
    ├── storage/
    │   ├── persistent-volumes.yaml
    │   └── storage-class.yaml
    └── databases/
        ├── postgres/
        │   └── postgres-deployment.yaml
        ├── redis/
        │   └── redis-deployment.yaml
        └── chromadb/
            └── chromadb-deployment.yaml
    └── services/
        └── ollama/
            └── ollama-deployment.yaml
