#!/bin/bash
# Description: Install vesktop-bin using paru before VNC starts
# Phase: pre-vnc

set -e

echo "[PRE-VNC] Starting vesktop-bin installation..."

# Check if paru is available
if ! command -v paru >/dev/null 2>&1; then
    echo "[PRE-VNC] ✗ Error: paru not found in PATH"
    echo "[PRE-VNC] Please ensure paru is installed in the base image"
    exit 1
fi

# Get the VNC user
VNC_USER=${VNC_USER:-root}

# Check if trying to install AUR package as root
if [ "$VNC_USER" = "root" ]; then
    echo "[PRE-VNC] ⚠ Warning: Cannot install AUR packages as root user"
    echo "[PRE-VNC] Skipping vesktop-bin installation"
    echo "[PRE-VNC] Please use a non-root VNC_USER to install AUR packages"
    exit 0
fi

echo "[PRE-VNC] Installing vesktop-bin for user: $VNC_USER"

# Install vesktop-bin using paru
echo "[PRE-VNC] Running: paru -S --noconfirm vesktop-bin"
if su - "$VNC_USER" -c "paru -S --noconfirm vesktop-bin"; then
    echo "[PRE-VNC] ✓ vesktop-bin installed successfully"
else
    echo "[PRE-VNC] ⚠ Warning: vesktop-bin installation failed with exit code $?"
    echo "[PRE-VNC] Continuing with startup process..."
    exit 0  # Don't fail the entire startup process
fi

echo "[PRE-VNC] vesktop-bin installation completed"
