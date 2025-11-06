#!/bin/bash

# If not already installed, download Ubuntu 22.04 LTS Server
# Recommended: Fresh installation or dedicated partition

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing essential tools..."
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    build-essential \
    software-properties-common
