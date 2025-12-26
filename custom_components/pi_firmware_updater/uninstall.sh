#!/bin/bash
set -e


CONFIG_DIR="${CONFIG_DIR:-/config/custom_components/pi_firmware_updater}"
SSH_DIR="${SSH_DIR:-/config/.ssh}"


main() {
    echo "🗑️ Starting Raspberry Pi Firmware Updater Uninstaller..."

    # 1. Remove Keys
    if [ -f "$SSH_DIR/id_rsa" ]; then
        echo "🔑 Removing SSH keys..."
        rm -f "$SSH_DIR/id_rsa" "$SSH_DIR/id_rsa.pub"
    else
        echo "ℹ️ No SSH keys found to remove."
    fi

    # 2. Revert Configs
    echo "undoing config changes..."

    # Revert update_notification.yaml
    if [ -f "$CONFIG_DIR/update_notification.yaml" ]; then
        echo "Reverting update_notification.yaml..."
        sed -i 's/action: notify\..*/action: notify.REPLACE_WITH_YOUR_DEVICE_ID/' "$CONFIG_DIR/update_notification.yaml"
    fi

    # Revert action_handler.yaml
    if [ -f "$CONFIG_DIR/action_handler.yaml" ]; then
        echo "Reverting action_handler.yaml..."
        sed -i 's/action: notify\..*/action: notify.REPLACE_WITH_YOUR_DEVICE_ID/' "$CONFIG_DIR/action_handler.yaml"
    fi

    echo "✅ Uninstall complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
