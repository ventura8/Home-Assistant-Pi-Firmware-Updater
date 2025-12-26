#!/bin/bash

# Raspberry Pi Firmware Updater - Setup Script
# Automates SSH keys, Permissions, and Mobile ID configuration.

set -e

CONFIG_DIR="${CONFIG_DIR:-/config/custom_components/pi_firmware_updater}"
SSH_DIR="${SSH_DIR:-/config/.ssh}"


main() {
    echo "🚀 Starting Raspberry Pi Firmware Updater setup..."

    # --- PART 1: SSH SETUP ---
    echo "--- Step 1: SSH Security Setup ---"

    # 1. Create .ssh directory
    if [ ! -d "$SSH_DIR" ]; then
        echo "📂 Creating $SSH_DIR directory..."
        mkdir -p "$SSH_DIR"
    fi

    # 2. Generate RSA Key Pair
    if [ ! -f "$SSH_DIR/id_rsa" ]; then
        echo "🔑 Generating RSA key pair..."
        ssh-keygen -t rsa -f "$SSH_DIR/id_rsa" -N ""
    else
        echo "ℹ️ SSH key already exists, skipping generation."
    fi

    # 3. Set strict permissions
    echo "🔒 Setting secure file permissions..."
    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/id_rsa"
    chmod 644 "$SSH_DIR/id_rsa.pub"

    # 4. Authorize Key
    echo "⚡ Authorizing key on Host OS..."
    # We check if we can connect first to avoid hanging
    if ssh -p 22222 -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_DIR/id_rsa" root@127.0.0.1 'exit' 2>/dev/null; then
        echo "✅ SSH connection already authorized!"
    else
        # Try to push the key
        echo "Attempting to push key to host..."
        ssh -p 22222 -o StrictHostKeyChecking=no root@127.0.0.1 'mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys' < "$SSH_DIR/id_rsa.pub" || {
            echo "❌ ERROR: Could not authorize key. Ensure 'HassOS SSH Port Configurator' is RUNNING."
            exit 1
        }
        echo "✅ Authorization successful!"
    fi

    # --- PART 2: MOBILE ID SETUP ---
    echo ""
    echo "--- Step 2: Mobile Notification Setup ---"
    echo "To enable actionable notifications, we need your Mobile App ID."
    echo "You can find this in Developer Tools -> Actions -> Search 'notify.mobile_app_'"
    echo ""
    echo ""
    if [ -z "$MOBILE_ID" ]; then
        read -r -p "Enter your Notify ID (e.g., notify.mobile_app_iphone): " MOBILE_ID || true
    fi

    if [ -n "$MOBILE_ID" ]; then
        echo "🔄 Updating automation files with ID: $MOBILE_ID"
        # sed command to find-and-replace the placeholder in the yaml files
        sed -i "s/notify.REPLACE_WITH_YOUR_DEVICE_ID/$MOBILE_ID/g" "$CONFIG_DIR/update_notification.yaml"
        sed -i "s/notify.REPLACE_WITH_YOUR_DEVICE_ID/$MOBILE_ID/g" "$CONFIG_DIR/action_handler.yaml"
        echo "✅ Files updated successfully."
    else
        echo "⚠️ No ID entered. You will need to edit 'update_notification.yaml' and 'action_handler.yaml' manually."
    fi

    # --- PART 3: CONFIGURATION INSTRUCTIONS ---
    echo ""
    echo "--- Step 3: Final Configuration ---"
    echo "✅ Setup complete! To finish, copy the block below into your configuration.yaml:"
    echo ""
    echo "################################################################"
    echo "shell_command: !include custom_components/pi_firmware_updater/shell_commands.yaml"
    echo "command_line: !include custom_components/pi_firmware_updater/command_line_sensors.yaml"
    echo "template: !include custom_components/pi_firmware_updater/template_sensors.yaml"
    echo "automation:"
    echo "  - !include custom_components/pi_firmware_updater/update_notification.yaml"
    echo "  - !include custom_components/pi_firmware_updater/action_handler.yaml"
    echo "script:"
    echo "  apply_pi_firmware_update_script: !include custom_components/pi_firmware_updater/apply_pi_firmware_update_script.yaml"
    echo "################################################################"
    echo ""
    echo "Then RESTART Home Assistant."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
