# Custom Entrypoint Scripts Guide

This document provides a comprehensive guide to using custom entrypoint scripts with the Docker LXQT VNC container. Custom scripts allow you to extend and customize the container behavior without modifying the base image.

## Table of Contents

- [Overview](#overview)
- [Script Execution Phases](#script-execution-phases)
- [Quick Start](#quick-start)
- [Script Requirements](#script-requirements)
- [Environment Variables](#environment-variables)
- [Example Scripts](#example-scripts)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Overview

The custom entrypoint script system allows you to run your own shell scripts at specific phases during container startup. This enables you to:

- Install additional packages
- Configure system settings
- Set up user environments
- Customize the VNC server
- Configure desktop applications
- Perform post-startup tasks

Scripts are organized into directories based on when they should execute during the container startup process.

## Script Execution Phases

### 1. Pre-Init (`/entrypoint.d/pre-init/`)
**When**: Before any system setup
**Use for**: 
- Installing system packages
- Configuring system-wide settings
- Setting up repositories
- Early system configuration

**Example**:
```bash
#!/bin/bash
# Install development tools
pacman -S --noconfirm vim git curl wget
```

### 2. Pre-User (`/entrypoint.d/pre-user/`)
**When**: Before user creation and configuration
**Use for**:
- System-level configuration
- Service setup
- Global system settings

**Example**:
```bash
#!/bin/bash
# Configure timezone
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
```

### 3. Pre-VNC (`/entrypoint.d/pre-vnc/`)
**When**: After user setup but before VNC server starts
**Use for**:
- User environment setup
- Application configuration
- User-specific customizations

**Example**:
```bash
#!/bin/bash
# Setup development workspace
VNC_USER=${VNC_USER:-root}
USER_HOME=$([ "$VNC_USER" = "root" ] && echo "/root" || echo "/home/$VNC_USER")
mkdir -p "$USER_HOME/workspace"
```

### 4. Post-VNC (`/entrypoint.d/post-vnc/`)
**When**: After VNC server starts but before desktop environment
**Use for**:
- VNC server configuration
- Display settings
- Input device setup

**Example**:
```bash
#!/bin/bash
# Configure VNC clipboard
DISPLAY=:1 autocutsel -fork -selection PRIMARY &
```

### 5. Post-Init (`/entrypoint.d/post-init/`)
**When**: After desktop environment starts
**Use for**:
- Auto-opening applications
- Desktop customization
- Final setup tasks

**Example**:
```bash
#!/bin/bash
# Open terminal automatically
sleep 5
DISPLAY=:1 qterminal &
```

## Quick Start

### Method 1: Mount Scripts Directory

1. Create your scripts directory:
```bash
mkdir -p ./my-scripts/{pre-init,pre-user,pre-vnc,post-vnc,post-init}
```

2. Add your custom script:
```bash
cat > ./my-scripts/pre-init/01-packages.sh << 'EOF'
#!/bin/bash
echo "Installing custom packages..."
pacman -S --noconfirm htop tree
EOF

chmod +x ./my-scripts/pre-init/01-packages.sh
```

3. Run container with mounted scripts:
```bash
docker run -d \
  -p 5901:5901 \
  -v $(pwd)/my-scripts:/entrypoint.d \
  -e VNC_USER=developer \
  -e VNC_PASSWORD=devpass \
  lxqt-vnc
```

### Method 2: Use Example Scripts

Copy and modify the provided examples:
```bash
cp -r examples/entrypoint-scripts ./my-custom-scripts
# Edit scripts as needed
docker run -d \
  -p 5901:5901 \
  -v $(pwd)/my-custom-scripts:/entrypoint.d \
  lxqt-vnc
```

### Method 3: Build Custom Image

Create a Dockerfile:
```dockerfile
FROM lxqt-vnc:latest
COPY my-scripts/ /entrypoint.d/
RUN find /entrypoint.d -name "*.sh" -exec chmod +x {} \;
```

## Script Requirements

### File Naming and Permissions
- Scripts must have `.sh` extension
- Scripts must be executable (`chmod +x script.sh`)
- Scripts are executed in alphabetical order within each phase
- Use numeric prefixes for ordering: `01-first.sh`, `02-second.sh`

### Script Structure
```bash
#!/bin/bash
# Description: What this script does
# Phase: pre-init|pre-user|pre-vnc|post-vnc|post-init

set -e  # Exit on any error (recommended)

echo "[PHASE] Starting custom setup..."

# Your custom logic here

echo "[PHASE] Custom setup completed successfully"
```

### Error Handling
- Scripts should handle errors gracefully
- Container startup continues even if scripts fail
- Use `set -e` to exit on errors
- Log progress with descriptive messages

## Environment Variables

### Available Variables
Your scripts have access to all container environment variables:

- `VNC_USER` - The VNC username (default: `root`)
- `VNC_PASSWORD` - The VNC password (default: `password`)
- `SUDO_NOPASSWD` - Whether sudo requires password (default: `false`)

### User Home Directory Pattern
```bash
VNC_USER=${VNC_USER:-root}
if [ "$VNC_USER" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME="/home/$VNC_USER"
fi
```

### Configuration Variables
Many example scripts support configuration via environment variables:

#### Package Installation
- `INSTALL_DEV_TOOLS=true` - Install development packages
- `INSTALL_FONTS=true` - Install additional fonts
- `INSTALL_FLATPAK_APPS=true` - Install Flatpak applications

#### System Configuration
- `CONFIGURE_TIMEZONE=true` - Set system timezone
- `TIMEZONE=UTC` - Timezone to set
- `CONFIGURE_LOCALE=true` - Configure system locale
- `LOCALE=en_US.UTF-8` - Locale to set

#### Development Environment
- `SETUP_DEV_WORKSPACE=true` - Create development directories
- `CONFIGURE_GIT=true` - Configure Git settings
- `GIT_USER_NAME="Name"` - Git username
- `GIT_USER_EMAIL="email@domain.com"` - Git email

#### Desktop Environment
- `AUTO_OPEN_TERMINAL=true` - Auto-open terminal
- `AUTO_OPEN_VSCODE=true` - Auto-open VS Code
- `CREATE_WELCOME_MESSAGE=true` - Create welcome file

## Example Scripts

### Package Installation (pre-init)
```bash
#!/bin/bash
set -e

if [ "${INSTALL_DEV_TOOLS:-false}" = "true" ]; then
    echo "Installing development tools..."
    pacman -S --noconfirm vim git curl wget htop tree firefox
    echo "Development tools installed successfully"
fi
```

### User Workspace Setup (pre-vnc)
```bash
#!/bin/bash
set -e

VNC_USER=${VNC_USER:-root}
USER_HOME=$([ "$VNC_USER" = "root" ] && echo "/root" || echo "/home/$VNC_USER")

echo "Setting up workspace for $VNC_USER..."

# Create directories
mkdir -p "$USER_HOME"/{workspace,projects,downloads}

# Create useful scripts
cat > "$USER_HOME/workspace/update-system.sh" << 'EOF'
#!/bin/bash
sudo pacman -Syu --noconfirm
EOF

chmod +x "$USER_HOME/workspace/update-system.sh"

# Set ownership
if [ "$VNC_USER" != "root" ]; then
    chown -R "$VNC_USER:$VNC_USER" "$USER_HOME"/{workspace,projects,downloads}
fi

echo "Workspace setup completed"
```

### Auto-open Applications (post-init)
```bash
#!/bin/bash
set -e

if [ "${AUTO_OPEN_APPS:-false}" = "true" ]; then
    echo "Auto-opening applications..."
    sleep 5  # Wait for desktop to load
    
    if [ "${AUTO_OPEN_TERMINAL:-false}" = "true" ]; then
        DISPLAY=:1 qterminal &
    fi
    
    if [ "${AUTO_OPEN_VSCODE:-false}" = "true" ] && command -v code >/dev/null 2>&1; then
        DISPLAY=:1 code &
    fi
    
    echo "Applications opened"
fi
```

## Best Practices

### 1. Script Organization
- Use descriptive names with numeric prefixes
- Group related functionality in single scripts
- Keep scripts focused on specific tasks
- Document what each script does

### 2. Error Handling
```bash
#!/bin/bash
set -e  # Exit on any error

# Check if command exists before using
if ! command -v git >/dev/null 2>&1; then
    echo "Git not found, installing..."
    pacman -S --noconfirm git
fi

# Check if directory exists before creating files
if [ ! -d "$USER_HOME" ]; then
    echo "User home directory not found: $USER_HOME"
    exit 1
fi
```

### 3. Configuration via Environment Variables
```bash
# Make scripts configurable
PACKAGE_LIST="${EXTRA_PACKAGES:-vim git curl}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$USER_HOME/workspace}"

# Provide defaults and validation
if [ -z "$VNC_USER" ]; then
    echo "ERROR: VNC_USER not set"
    exit 1
fi
```

### 4. Proper File Ownership
```bash
# Always check if we need to change ownership
if [ "$VNC_USER" != "root" ]; then
    chown -R "$VNC_USER:$VNC_USER" "$USER_HOME/.config"
fi
```

### 5. Logging and Feedback
```bash
# Use consistent logging prefixes
echo "[PRE-INIT] Installing packages..."
echo "[PRE-INIT] ✓ Packages installed successfully"
echo "[PRE-INIT] ⚠ Warning: Some packages failed to install"
echo "[PRE-INIT] ✗ Error: Package installation failed"
```

## Troubleshooting

### Check Script Execution
```bash
# View container logs
docker logs <container-name>

# Check if scripts are executable
docker exec -it <container-name> find /entrypoint.d -name "*.sh" -exec ls -la {} \;

# Test script syntax
docker exec -it <container-name> bash -n /entrypoint.d/pre-init/01-packages.sh
```

### Common Issues

#### Script Not Executing
- **Cause**: Script not executable
- **Solution**: `chmod +x script.sh`

#### Syntax Errors
- **Cause**: Wrong line endings (CRLF instead of LF)
- **Solution**: Use `dos2unix script.sh` or ensure editor uses Unix line endings

#### Permission Denied
- **Cause**: Trying to access files as wrong user
- **Solution**: Check user context and use proper ownership changes

#### Package Installation Fails
- **Cause**: Package not available or repo not updated
- **Solution**: Update package database first: `pacman -Sy`

### Validation Tool
Use the included validation script:
```bash
# Validate example scripts
./validate-scripts.sh

# Validate custom scripts
./validate-scripts.sh -d ./my-scripts

# Fix common issues automatically
./validate-scripts.sh -f -d ./my-scripts

# Only check syntax
./validate-scripts.sh -s
```

## Advanced Usage

### Docker Compose with Custom Scripts
```yaml
version: '3.8'
services:
  lxqt-desktop:
    build: .
    ports:
      - "5901:5901"
    environment:
      - VNC_USER=developer
      - VNC_PASSWORD=devpass123
      - INSTALL_DEV_TOOLS=true
      - SETUP_DEV_WORKSPACE=true
      - AUTO_OPEN_TERMINAL=true
    volumes:
      - ./custom-scripts:/entrypoint.d
      - ./workspace:/home/developer/workspace
```

### Conditional Script Execution
```bash
#!/bin/bash
# Only run on first startup
MARKER_FILE="/tmp/first-run-complete"

if [ ! -f "$MARKER_FILE" ]; then
    echo "First run setup..."
    # Your first-run logic here
    touch "$MARKER_FILE"
else
    echo "Skipping first-run setup (already completed)"
fi
```

### Multi-Phase Scripts
```bash
#!/bin/bash
# Script that works in multiple phases
SCRIPT_NAME=$(basename "$0")
PHASE=$(basename "$(dirname "$0")")

case "$PHASE" in
    pre-init)
        echo "[$SCRIPT_NAME] Pre-init phase"
        # Install packages
        ;;
    post-init)
        echo "[$SCRIPT_NAME] Post-init phase"
        # Configure applications
        ;;
esac
```

### Custom Environment Variables
```bash
# In your docker run command
docker run -d \
  -e CUSTOM_SETTING=value \
  -e FEATURE_ENABLED=true \
  -v ./scripts:/entrypoint.d \
  lxqt-vnc

# In your script
if [ "${FEATURE_ENABLED:-false}" = "true" ]; then
    echo "Custom feature enabled with setting: $CUSTOM_SETTING"
fi
```

### Building Custom Images
```dockerfile
FROM lxqt-vnc:latest

# Copy scripts
COPY scripts/ /entrypoint.d/

# Set permissions
RUN find /entrypoint.d -name "*.sh" -exec chmod +x {} \;

# Set custom defaults
ENV INSTALL_DEV_TOOLS=true
ENV SETUP_DEV_WORKSPACE=true
ENV AUTO_OPEN_TERMINAL=true
```

This custom script system provides tremendous flexibility while maintaining the stability and functionality of the base container. Start with the provided examples and gradually build your own customizations based on your specific needs.