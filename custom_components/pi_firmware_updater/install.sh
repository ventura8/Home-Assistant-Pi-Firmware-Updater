#!/bin/bash

# Raspberry Pi Firmware Updater - Setup Script
# Automates SSH keys, Permissions, and Mobile ID configuration.

set -e

CONFIG_DIR="${CONFIG_DIR:-/config/custom_components/pi_firmware_updater}"
SSH_DIR="${SSH_DIR:-/config/.ssh}"
KEY_COMMENT="pi_firmware_updater"
WRAPPER_DIR="/root/.pi_firmware_updater"
WRAPPER_PATH="${WRAPPER_DIR}/ssh_wrapper.sh"
HOST_CHECK_PATH="${WRAPPER_DIR}/host_check.sh"
KEY_BLOB_PATH="${WRAPPER_DIR}/key.blob"
SSH_PORT=22222
SSH_TARGET="root@127.0.0.1"
WRAPPER_SRC="${CONFIG_DIR}/ssh_wrapper.sh"

build_authorized_keys_line() {
    local pub_key
    pub_key=$(awk '{print $1" "$2}' "$SSH_DIR/id_rsa.pub")
    printf 'restrict,from="127.0.0.1",command="%s" %s %s\n' \
        "$WRAPPER_PATH" "$pub_key" "$KEY_COMMENT"
}

get_key_blob() {
    awk '{print $2}' "$SSH_DIR/id_rsa.pub"
}

# Reject empty/malformed pubs before any remote authorized_keys mutation.
validate_public_key() {
    local line key_type blob
    if [ ! -s "$SSH_DIR/id_rsa.pub" ]; then
        echo "❌ ERROR: Public key file is missing or empty."
        exit 1
    fi
    line=$(head -n 1 "$SSH_DIR/id_rsa.pub")
    key_type=$(printf '%s\n' "$line" | awk '{print $1}')
    blob=$(printf '%s\n' "$line" | awk '{print $2}')
    case "$key_type" in
        ssh-rsa | ssh-ed25519 | ecdsa-sha2-nistp256 | ecdsa-sha2-nistp384 | \
            ecdsa-sha2-nistp521) ;;
        *)
            echo "❌ ERROR: Unsupported or malformed public key type."
            exit 1
            ;;
    esac
    if [ -z "$blob" ] || [ "${#blob}" -lt 32 ]; then
        echo "❌ ERROR: Public key blob is missing or too short."
        exit 1
    fi
}

ssh_host() {
    local use_identity="$1"
    shift
    if [ "$use_identity" = "yes" ]; then
        ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            -i "$SSH_DIR/id_rsa" "$SSH_TARGET" "$@"
    else
        ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$SSH_TARGET" "$@"
    fi
}

# Password/bootstrap channel only (not the restricted integration key).
replace_managed_auth_remote() {
    local auth_line="$1"
    local key_blob="$2"
    local remote_script

    remote_script=$(
        cat << EOF
set -e
mkdir -p ${WRAPPER_DIR} /root/.ssh
chmod 700 ${WRAPPER_DIR} /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
awk -v blob='${key_blob}' -v wrap='${WRAPPER_PATH}' '
  blob != "" && index(\$0, blob) && index(\$0, wrap) { next }
  blob != "" && index(\$0, blob) { next }
  index(\$0, wrap) { next }
  { print }
' /root/.ssh/authorized_keys > /root/.ssh/authorized_keys.tmp
mv /root/.ssh/authorized_keys.tmp /root/.ssh/authorized_keys
cat >> /root/.ssh/authorized_keys <<'AUTH'
${auth_line}
AUTH
chmod 600 /root/.ssh/authorized_keys
printf '%s\n' '${key_blob}' > ${KEY_BLOB_PATH}
chmod 600 ${KEY_BLOB_PATH}
EOF
    )
    printf '%s\n' "$remote_script" | ssh_host no 'bash -s'
}

deploy_via_password() {
    local auth_line="$1"
    local key_blob="$2"
    local host_check="$CONFIG_DIR/host_check.sh"

    ssh_host no "mkdir -p ${WRAPPER_DIR} /root/.ssh && chmod 700 ${WRAPPER_DIR} /root/.ssh" \
        || return 1
    ssh_host no "cat > ${HOST_CHECK_PATH}" < "$host_check" || return 1
    ssh_host no "chmod 700 ${HOST_CHECK_PATH}" || return 1
    ssh_host no "cat > ${WRAPPER_PATH}" < "$WRAPPER_SRC" || return 1
    ssh_host no "chmod 700 ${WRAPPER_PATH}" || return 1
    replace_managed_auth_remote "$auth_line" "$key_blob" || return 1
}

authorize_key_on_host() {
    local auth_line key_blob
    validate_public_key
    auth_line=$(build_authorized_keys_line)
    key_blob=$(get_key_blob)

    if [ ! -f "$WRAPPER_SRC" ]; then
        echo "❌ ERROR: Missing wrapper source at ${WRAPPER_SRC}"
        exit 1
    fi
    if [ ! -f "$CONFIG_DIR/host_check.sh" ]; then
        echo "❌ ERROR: Missing host_check.sh at ${CONFIG_DIR}/host_check.sh"
        exit 1
    fi

    echo "⚡ Authorizing/refreshing restricted key on Host OS..."
    echo "   (Bootstrap uses password auth on port ${SSH_PORT}; not the integration key.)"
    if ssh_host yes 'exit' 2> /dev/null; then
        echo "ℹ️ SSH key auth works; refreshing host files via password bootstrap..."
    else
        echo "Attempting to push restricted key to host via password bootstrap..."
    fi

    if deploy_via_password "$auth_line" "$key_blob"; then
        echo "✅ Authorization successful!"
        return 0
    fi
    echo "❌ ERROR: Could not authorize key."
    echo "   Ensure 'HassOS SSH Port Configurator' is RUNNING with a password set."
    exit 1
}

ensure_ssh_key_material() {
    if [ ! -d "$SSH_DIR" ]; then
        echo "📂 Creating $SSH_DIR directory..."
        mkdir -p "$SSH_DIR"
    fi

    if [ ! -f "$SSH_DIR/id_rsa" ]; then
        echo "🔑 Generating RSA key pair..."
        ssh-keygen -t rsa -f "$SSH_DIR/id_rsa" -N "" -C "$KEY_COMMENT"
        return 0
    fi

    if [ -f "$SSH_DIR/id_rsa.pub" ]; then
        echo "ℹ️ SSH key already exists, skipping generation."
        return 0
    fi

    echo "🔑 Regenerating public key from existing private key..."
    if ! ssh-keygen -y -f "$SSH_DIR/id_rsa" > "$SSH_DIR/id_rsa.pub"; then
        echo "❌ ERROR: Could not regenerate id_rsa.pub from id_rsa."
        rm -f "$SSH_DIR/id_rsa.pub"
        exit 1
    fi
    if [ ! -s "$SSH_DIR/id_rsa.pub" ]; then
        echo "❌ ERROR: Regenerated id_rsa.pub is empty."
        rm -f "$SSH_DIR/id_rsa.pub"
        exit 1
    fi
}

setup_ssh_keys() {
    ensure_ssh_key_material

    echo "🔒 Setting secure file permissions..."
    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/id_rsa"
    chmod 644 "$SSH_DIR/id_rsa.pub"

    authorize_key_on_host
}

setup_mobile_id() {
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
        sed -i "s/notify.REPLACE_WITH_YOUR_DEVICE_ID/$MOBILE_ID/g" \
            "$CONFIG_DIR/update_notification.yaml"
        sed -i "s/notify.REPLACE_WITH_YOUR_DEVICE_ID/$MOBILE_ID/g" \
            "$CONFIG_DIR/action_handler.yaml"
        echo "✅ Files updated successfully."
    else
        echo "⚠️ No ID entered. You will need to edit"
        echo "   'update_notification.yaml' and 'action_handler.yaml' manually."
    fi
}

print_config_instructions() {
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

main() {
    echo "🚀 Starting Raspberry Pi Firmware Updater setup..."
    echo "--- Step 1: SSH Security Setup ---"
    setup_ssh_keys
    setup_mobile_id
    print_config_instructions
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
