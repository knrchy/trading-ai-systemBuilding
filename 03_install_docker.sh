#!/bin/bash

echo "Removing old Docker versions..."
sudo apt remove -y docker docker-engine docker.io containerd runc

echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "Adding user to docker group..."
sudo usermod -aG docker $USER
newgrp docker

echo "Verifying Docker installation..."
docker --version
docker run hello-world

echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

echo "Docker installation complete."
