#!/bin/bash
# Host-side SSH forced-command wrapper for pi_firmware_updater.
# Never executes caller-supplied stdin as a shell program.
# Deployment of host files is NOT allowlisted — use password bootstrap only.
set -euo pipefail

MANAGED_DIR="/root/.pi_firmware_updater"
HOST_CHECK="${MANAGED_DIR}/host_check.sh"
WRAPPER="${MANAGED_DIR}/ssh_wrapper.sh"
KEY_BLOB_FILE="${MANAGED_DIR}/key.blob"
AUTH_KEYS="/root/.ssh/authorized_keys"

remove_managed_auth_line() {
    local blob=""
    if [[ -f "$KEY_BLOB_FILE" ]]; then
        blob=$(cat "$KEY_BLOB_FILE")
    fi
    if [[ ! -f "$AUTH_KEYS" ]]; then
        return 0
    fi
    # Drop lines that reference this wrapper, plus any line whose key field is
    # exactly the managed blob (never a substring match: unrelated keys sharing
    # a common prefix must survive).
    awk -v blob="$blob" -v wrap="$WRAPPER" '
        index($0, wrap) { next }
        blob != "" { for (i = 1; i <= NF; i++) if ($i == blob) next }
        { print }
    ' "$AUTH_KEYS" > "${AUTH_KEYS}.tmp"
    mv "${AUTH_KEYS}.tmp" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
}

case "${SSH_ORIGINAL_COMMAND:-}" in
    "pi_firmware_check")
        exec /bin/bash "$HOST_CHECK"
        ;;
    "pi_firmware_update")
        exec /bin/bash "$HOST_CHECK" --update
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
