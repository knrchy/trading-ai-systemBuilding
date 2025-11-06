#!/bin/bash

echo "Creating project directory..."
mkdir -p ~/trading-ai-system
cd ~/trading-ai-system

echo "Initializing Git repository..."
git init
read -p "Enter your Git username: " GIT_USERNAME
read -p "Enter your Git email: " GIT_EMAIL
git config user.name "$GIT_USERNAME"
git config user.email "$GIT_EMAIL"

echo "Creating .gitignore file..."
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/

# Data files
data/raw/*
data/processed/*
!data/raw/.gitkeep
!data/processed/.gitkeep

# Secrets
*.key
*.pem
secrets/
.env

# IDE
.vscode/
.idea/
*.swp

# Kubernetes
*.kubeconfig

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
EOF

echo "Creating directory structure..."
mkdir -p {docs/phase-guides,infrastructure/{terraform,ansible/{playbooks,inventory},scripts},kubernetes/{namespaces,storage,databases/{chromadb,redis,postgres},services/{rag-service,api-gateway,ollama,celery-workers},monitoring/{prometheus,grafana},ingress},applications/{data-pipeline,rag-engine,backtesting-engine,ml-optimizer,api-gateway}/{src,tests},data/{raw,processed,embeddings,models},configs/{development,staging,production},scripts}

echo "Creating .gitkeep files for empty directories..."
find data -type d -exec touch {}/.gitkeep \;

echo "Performing initial commit..."
git add .
git commit -m "Initial project structure"

echo "Git repository setup complete."
