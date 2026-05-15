#!/usr/bin/env bash
# Install host packages needed by the Hermes Omni demo on Ubuntu/Debian.
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
    echo "This helper supports Ubuntu/Debian hosts with apt-get." >&2
    echo "Install equivalents manually: git curl ca-certificates ffmpeg poppler-utils lsof python3 python3-venv python3-pip nodejs npm." >&2
    exit 1
fi

bash "$(dirname "$0")/ensure-sudo.sh"

sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    lsof \
    nodejs \
    npm \
    poppler-utils \
    python3 \
    python3-pip \
    python3-venv

echo "Host prerequisites installed."

if ! command -v docker >/dev/null 2>&1; then
    echo
    echo "Docker was not found. On a factory DGX Spark image it may already be installed."
    echo "For a clean Ubuntu host, run:"
    echo "  bash scripts/install-docker-nvidia-toolkit.sh"
fi
