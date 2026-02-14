# Systemd Service Creator

Bash script for creating, configuring, and installing systemd service for background services for ubuntu servers

## Overview
This script simplifies the process of creating systemd service files by providing an interactive interface that guides you through all necessary options. It supports downloading templates from GitHub, configuring security hardening options, integrating with screen for interactive services, and automatically installing the service with symbolic links.

## Features

- **Interactive Prompts** - Guided setup with sensible defaults
- **Security Hardening** - Optional enable/disable of systemd security features
- **Screen Integration** - Automatic screen command wrapping for interactive services
- **Systemd Integration** - Automatic symlink creation in /etc/systemd/system/
- **Service Management** - Optional enable, start, and status checking

## Quick Start

### One-Line Installation

Download and run the script directly from GitHub:

```bash
curl -sSL https://github.com/Supernich/create-service/main/create-service.sh | bash
```

Or with wget:

```bash
wget -qO- https://github.com/Supernich/create-service/main/create-service.sh | bash
```

### Manual Download

```bash
# Download the script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/systemd-service-creator/main/create-service.sh

# Make it executable
chmod +x create-service.sh

# Run it
./create-service.sh
```

## Step-by-Step Guide

### 1. Basic Information
- **Service name** - e.g., `gmod`, `minecraft`, `cs2`
- **Description** - What does this service do?
- **Working directory** - Where the service runs
- **Username** - User account to run the service
- **Custom group** - Optional separate group name

### 2. Security Hardening
Choose which security features to enable:

| Option | Description | When to use |
|--------|-------------|-------------|
| `NoNewPrivileges` | Prevents privilege escalation | Always recommended |
| `PrivateTmp` | Isolated temporary directory | Services that create temp files |
| `ProtectSystem=full` | Protects system directories | Most services |
| `ProtectHome=yes` | Isolates /home and /root | Services without home access |

### 3. Restart Policy
Select how the service should restart:

| Option | Behavior | Use Case |
|--------|----------|----------|
| `on-failure` | Restart only on crash | Game servers, web apps |
| `always` | Always restart | Critical services |
| `no` | Never restart | One-time tasks |
| `on-abnormal` | Restart on abnormal exit | Services with cleanup |

### 4. Screen Integration
If using screen (recommended for interactive services):
- **Screen session name** - Identifier for the screen session
- **Base command** - The actual command to run inside screen
- **Screen-friendly stop** - Automatically generates proper stop command

Example screen workflow:
```bash
# Start command becomes:
/usr/bin/screen -dmS gmod ./srcds_run -game garrysmod +ip 127.0.0.1 -port 27015

# Stop command becomes:
/usr/bin/screen -p 0 -S gmod -X eval 'stuff "quit\015"'
```

### 5. Installation
- **Create symbolic link?** - Links service file to /etc/systemd/system/

- **Reload systemd?** - Applies changes immediately

- **Enable at boot?** - Service starts automatically on system boot

- **Start now?** - Launches the service immediately

## Useful Commands After Installation

```bash
# Create SymLink from file to systemd
sudo ln -sf SERVICE_FILE_PATH /etc/systemd/system/SERVICE_NAME.service

# Check service status
sudo systemctl status SERVICE_NAME

# View logs
sudo journalctl -u SERVICE_NAME -f

# Enable service
sudo systemctl ebanble SERVICE_NAME

# Disable service
sudo systemctl disable SERVICE_NAME

# Start service
sudo systemctl start SERVICE_NAME

# Restart service
sudo systemctl restart SERVICE_NAME

# Stop service
sudo systemctl stop SERVICE_NAME

# Attach to screen session (if used)
screen -r SCREEN_NAME

# List all screen sessions
screen -ls
```