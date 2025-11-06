#!/bin/bash

# Prompt the user for the IP address
read -p "Enter your IP address: " YOUR_IP

echo "Setting hostname..."
sudo hostnamectl set-hostname trading-ai-master

echo "Configuring /etc/hosts..."
sudo bash -c "echo '127.0.0.1 trading-ai-master' >> /etc/hosts"
sudo bash -c "echo '$YOUR_IP trading-ai-master' >> /etc/hosts"

echo "Hostname and network configuration done."
