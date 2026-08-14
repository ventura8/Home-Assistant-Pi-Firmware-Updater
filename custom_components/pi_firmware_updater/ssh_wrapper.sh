#!/bin/bash
# Host-side SSH forced-command wrapper for pi_firmware_updater.
# Never executes caller-supplied stdin as a shell program.
MANAGED_DIR="/root/.pi_firmware_updater"
HOST_CHECK="${MANAGED_DIR}/host_check.sh"
WRAPPER="${MANAGED_DIR}/ssh_wrapper.sh"
KEY_BLOB_FILE="${MANAGED_DIR}/key.blob"
AUTH_KEYS="/root/.ssh/authorized_keys"

remove_managed_auth_line() {
    local blob=""
    if [ -f "$KEY_BLOB_FILE" ]; then
        blob=$(cat "$KEY_BLOB_FILE")
    fi
    if [ ! -f "$AUTH_KEYS" ] || [ -z "$blob" ]; then
        return 0
    fi
    awk -v blob="$blob" -v wrap="$WRAPPER" '
        index($0, blob) && index($0, wrap) { next }
        { print }
    ' "$AUTH_KEYS" > "${AUTH_KEYS}.tmp"
    mv "${AUTH_KEYS}.tmp" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
}

write_stdin_to_managed() {
    local dest="$1"
    mkdir -p "$MANAGED_DIR"
    cat > "${dest}.tmp"
    mv "${dest}.tmp" "$dest"
    chmod 700 "$dest"
}

deploy_auth_line() {
    local auth_line blob
    mkdir -p "$MANAGED_DIR" /root/.ssh
    chmod 700 "$MANAGED_DIR" /root/.ssh
    auth_line=$(cat)
    blob=$(printf '%s\n' "$auth_line" | awk '{
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^ssh-/) { print $(i+1); exit }
        }
    }')
    if [ -z "$blob" ] || [ -z "$auth_line" ]; then
        echo "pi_firmware_updater: invalid auth line" >&2
        exit 1
    fi
    printf '%s\n' "$blob" > "$KEY_BLOB_FILE"
    chmod 600 "$KEY_BLOB_FILE"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    awk -v blob="$blob" -v wrap="$WRAPPER" '
        index($0, blob) && index($0, wrap) { next }
        index($0, blob) { next }
        { print }
    ' "$AUTH_KEYS" > "${AUTH_KEYS}.tmp"
    mv "${AUTH_KEYS}.tmp" "$AUTH_KEYS"
    printf '%s\n' "$auth_line" >> "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
}

case "${SSH_ORIGINAL_COMMAND:-}" in
    "pi_firmware_check")
        exec /bin/bash "$HOST_CHECK"
        ;;
    "pi_firmware_update")
        exec /bin/bash "$HOST_CHECK" --update
        ;;
    "pi_firmware_deploy_host_check")
        write_stdin_to_managed "$HOST_CHECK"
        ;;
    "pi_firmware_deploy_wrapper")
        write_stdin_to_managed "$WRAPPER"
        ;;
    "pi_firmware_deploy_auth")
        deploy_auth_line
        ;;
    "pi_firmware_uninstall")
        remove_managed_auth_line
        rm -rf "$MANAGED_DIR"
        ;;
    "exit" | "")
        exit 0
        ;;
    *)
        echo "pi_firmware_updater: command denied" >&2
        exit 1
        ;;
esac
