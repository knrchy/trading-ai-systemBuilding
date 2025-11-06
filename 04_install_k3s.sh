#!/bin/bash

echo "Installing K3s master..."
curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --node-name trading-ai-master

echo "Verifying K3s installation..."
sudo systemctl status k3s

echo "Setting up kubectl..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "Verifying cluster..."
kubectl get nodes
kubectl get pods -A

echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

echo "K3s installation complete."
