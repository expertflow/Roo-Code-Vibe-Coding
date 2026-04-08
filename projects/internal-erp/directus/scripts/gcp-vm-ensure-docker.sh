#!/usr/bin/env bash
# Ubuntu 22.04+ (e.g. GCE VM): ensure Docker Engine + Compose v2 are installed.
# Idempotent — skips install when already present.
set -euo pipefail

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo required" >&2
  exit 1
fi

docker_ok() {
  sudo docker info >/dev/null 2>&1 && sudo docker compose version >/dev/null 2>&1
}

if docker_ok; then
  echo "Docker is already installed."
  sudo docker --version
  sudo docker compose version
  exit 0
fi

echo "Docker not found or incomplete — installing Docker Engine + Compose plugin..."

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${VERSION_CODENAME:-jammy}") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker "${SUDO_USER:-$USER}" || true

echo "Done."
sudo docker --version
sudo docker compose version
echo "Log out and back in (or: newgrp docker) to use docker without sudo. Until then: sudo docker ..."
