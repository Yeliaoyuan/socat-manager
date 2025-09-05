#!/bin/bash

# ==============================================================================
# Socat Manager - One-Click Installer
#
# Description: This script automates the setup of a centralized systemd service
#              to manage multiple socat port forwarding rules from a single
#              config file. It solves the problem of Docker containers needing
#              to access services running on the host's localhost (127.0.0.1).
#
# GitHub:      https://github.com/yeliaoyuan/socat-manager
# Author:      yeliaoyuan
# Version:     1.2
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration Paths ---
CONFIG_DIR="/etc/socat"
CONFIG_FILE="${CONFIG_DIR}/forwards.conf"
MANAGER_SCRIPT="/usr/local/bin/socat-manager.sh"
SERVICE_FILE="/etc/systemd/system/socat-manager.service"

# --- Main installation function ---
install_socat_manager() {
    echo "--- Socat Port Forwarding Manager Installer ---"
    echo "      Author: yeliaoyuan"
    echo "      GitHub: https://github.com/yeliaoyuan/socat-manager"
    echo "----------------------------------------------------"

    # 1. Check for root privileges
    if [[ $EUID -ne 0 ]]; then
       echo "❌ Error: This script must be run as root or with sudo." >&2
       exit 1
    fi
    echo "✅ Root privileges verified."

    # 2. Check and install socat if not present
    if ! command -v socat &> /dev/null; then
        echo "⚠️ 'socat' is not installed. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y socat
        elif command -v yum &> /dev/null; then
            yum install -y socat
        else
            echo "❌ Error: Could not determine package manager. Please install 'socat' manually and re-run." >&2
            exit 1
        fi
    fi
    echo "✅ 'socat' is installed."

    # 3. Create config directory and file
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "🔧 Creating directory: ${CONFIG_DIR}"
        mkdir -p "$CONFIG_DIR"
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "🔧 Creating initial config file: ${CONFIG_FILE}"
        cat << EOF > "$CONFIG_FILE"
# Socat Forwarding Rules
#
# This file is managed by Socat Manager.
# Add your forwarding rules below. The service needs to be restarted
# after any changes to this file.
#
# Format: <Listen_IP>:<Listen_Port>:<Forward_IP>:<Forward_Port>
# Lines starting with # and blank lines are ignored.
#
# Example (uncomment and edit to use):
# 172.17.0.1:5000:127.0.0.1:5000
EOF
    else
        echo "ℹ️ Config file ${CONFIG_FILE} already exists. Skipping creation."
    fi

    # 4. Create the manager script
    echo "🔧 Creating manager script: ${MANAGER_SCRIPT}"
    cat << 'EOF' > "$MANAGER_SCRIPT"
#!/bin/bash

CONFIG_FILE="/etc/socat/forwards.conf"

start() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "[ERROR] Config file ${CONFIG_FILE} not found. Exiting." >&2
        exit 1
    fi
    
    echo "Starting socat forwarders from ${CONFIG_FILE}..."
    
    # Read config file, filter comments and blank lines, then loop
    grep -vE '^\s*#|^\s*$' "$CONFIG_FILE" | while IFS= read -r line; do
        # Use Parameter Expansion for safer parsing
        listen_ip=$(echo "$line" | cut -d: -f1)
        listen_port=$(echo "$line" | cut -d: -f2)
        forward_ip=$(echo "$line" | cut -d: -f3)
        forward_port=$(echo "$line" | cut -d: -f4)

        if [[ -z "$listen_ip" || -z "$listen_port" || -z "$forward_ip" || -z "$forward_port" ]]; then
            echo "[WARN] Skipping invalid line in config: $line"
            continue
        fi
        
        echo "  - Forwarding ${listen_ip}:${listen_port} -> ${forward_ip}:${forward_port}"
        # Start socat in the background
        socat TCP4-LISTEN:${listen_port},bind=${listen_ip},fork,reuseaddr TCP4:${forward_ip}:${forward_port} &
    done
    
    # Keep the script running so systemd can manage its lifecycle
    wait
}

stop() {
    echo "Stopping all socat forwarders..."
    # Kill processes that match the specific command pattern to avoid killing other socat processes
    pkill -f "socat TCP4-LISTEN.*,bind=.*,fork,reuseaddr" || true
}

# Trap signals to ensure a clean shutdown
trap "stop; exit 0" SIGINT SIGTERM

# Main execution logic
start
EOF
    chmod +x "$MANAGER_SCRIPT"

    # 5. Create the systemd service file
    echo "🔧 Creating systemd service file: ${SERVICE_FILE}"
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Socat Port Forwarding Manager by yeliaoyuan
Documentation=https://github.com/yeliaoyuan/socat-manager
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=${MANAGER_SCRIPT}
ExecStop=/usr/bin/pkill -f "socat TCP4-LISTEN.*,bind=.*,fork,reuseaddr"
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    # 6. Reload systemd, enable and start the service
    echo "🔄 Reloading systemd daemon..."
    systemctl daemon-reload

    echo "👍 Enabling service to start on boot..."
    systemctl enable socat-manager.service

    echo "🚀 Starting (or restarting) the service..."
    systemctl restart socat-manager.service

    # Give the service a moment to start before checking status
    sleep 2

    echo ""
    echo "🎉 Installation/Update complete!"
    echo "----------------------------------------------------"
    echo "To add/edit forwarding rules, modify the file:"
    echo "  sudo nano ${CONFIG_FILE}"
    echo ""
    echo "After editing, apply changes by restarting the service:"
    echo "  sudo systemctl restart socat-manager.service"
    echo ""
    echo "Current service status:"
    systemctl status socat-manager.service --no-pager
    echo "----------------------------------------------------"
}

# --- Run the installer ---
install_socat_manager

exit 0
