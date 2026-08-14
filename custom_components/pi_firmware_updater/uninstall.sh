#!/bin/bash
set -e

CONFIG_DIR="${CONFIG_DIR:-/config/custom_components/pi_firmware_updater}"
SSH_DIR="${SSH_DIR:-/config/.ssh}"
WRAPPER_PATH="/root/.pi_firmware_updater/ssh_wrapper.sh"
WRAPPER_DIR="/root/.pi_firmware_updater"
SSH_PORT=22222
SSH_TARGET="root@127.0.0.1"

print_manual_host_cleanup() {
    echo "⚠️ WARNING: Could not remove host SSH authorization over SSH."
    echo "   Manually remove the managed authorized_keys line that references"
    echo "   ${WRAPPER_PATH} (and your key blob) on the Host OS (port ${SSH_PORT}),"
    echo "   and delete /root/.pi_firmware_updater/."
}

cleanup_via_password() {
    # Bootstrap channel (no integration key): strip wrapper lines + managed dir.
    local remote_script
    remote_script=$(
        cat << EOF
set -e
if [ -f /root/.ssh/authorized_keys ]; then
  awk -v wrap='${WRAPPER_PATH}' '
    index(\$0, wrap) { next }
    { print }
  ' /root/.ssh/authorized_keys > /root/.ssh/authorized_keys.tmp
  mv /root/.ssh/authorized_keys.tmp /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi
rm -rf ${WRAPPER_DIR}
EOF
    )
    # Pipe script to remote bash -s (avoids ssh heredoc client expansion pitfalls).
    printf '%s\n' "$remote_script" | ssh -p "$SSH_PORT" \
        -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$SSH_TARGET" 'bash -s'
}

cleanup_host_authorization() {
    echo "🧹 Removing host authorized_keys entry and wrapper..."

    if [ -f "$SSH_DIR/id_rsa" ]; then
        if ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            -i "$SSH_DIR/id_rsa" "$SSH_TARGET" 'pi_firmware_uninstall' 2> /dev/null; then
            echo "✅ Host authorization cleaned up."
            return 0
        fi
        echo "ℹ️ Key-path uninstall failed; trying password bootstrap cleanup..."
    else
        echo "ℹ️ Local private key missing; trying password bootstrap cleanup..."
    fi

    if cleanup_via_password 2> /dev/null; then
        echo "✅ Host authorization cleaned up via password bootstrap."
        return 0
    fi

    print_manual_host_cleanup
    return 1
}

remove_local_keys() {
    if [ -f "$SSH_DIR/id_rsa" ] || [ -f "$SSH_DIR/id_rsa.pub" ]; then
        echo "🔑 Removing local SSH keys..."
        rm -f "$SSH_DIR/id_rsa" "$SSH_DIR/id_rsa.pub"
    else
        echo "ℹ️ No SSH keys found to remove."
    fi
}

revert_mobile_configs() {
    echo "undoing config changes..."

    if [ -f "$CONFIG_DIR/update_notification.yaml" ]; then
        echo "Reverting update_notification.yaml..."
        sed -i 's/action: notify\..*/action: notify.REPLACE_WITH_YOUR_DEVICE_ID/' \
            "$CONFIG_DIR/update_notification.yaml"
    fi

    if [ -f "$CONFIG_DIR/action_handler.yaml" ]; then
        echo "Reverting action_handler.yaml..."
        sed -i 's/action: notify\..*/action: notify.REPLACE_WITH_YOUR_DEVICE_ID/' \
            "$CONFIG_DIR/action_handler.yaml"
    fi
}

main() {
    local host_status=0

    echo "🗑️ Starting Raspberry Pi Firmware Updater Uninstaller..."

    # Host cleanup must run before local keys are deleted
    if ! cleanup_host_authorization; then
        host_status=1
    fi
    remove_local_keys
    revert_mobile_configs

    if [ "$host_status" -ne 0 ]; then
        echo "⚠️ Uninstall finished with incomplete host cleanup."
        return "$host_status"
    fi

    echo "✅ Uninstall complete."
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
