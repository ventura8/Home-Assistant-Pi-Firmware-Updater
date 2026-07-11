#!/bin/bash
# host_check.sh
# Runs on the host OS via SSH. Detects if firmware updates are possible/blocked.

set -e

# Helper to mock block device checks in tests
if ! declare -F is_block_dev >/dev/null 2>&1; then
    is_block_dev() {
        [ -b "$1" ]
    }
fi

# Helper to emit standardized compact summary
emit_summary() {
    local current="$1"
    local latest="$2"
    local available="$3"
    local blocked="$4"
    local reason="$5"
    echo "current_version: \"$current\" latest_version: \"$latest\" update_available: $available update_blocked: $blocked blocked_reason: $reason"
}

# Helper to check if running from SSD/NVMe
check_ssd_boot() {
    local model_file="${MODEL_FILE:-/proc/device-tree/model}"
    local cmdline_file="${CMDLINE_FILE:-/proc/cmdline}"

    # Check model
    if [ -f "$model_file" ]; then
        MODEL=$(tr -d '\0' < "$model_file")
    else
        MODEL="Unknown"
    fi

    # We only block SSD boot on Raspberry Pi 3 and 4 family (including CM3/CM4, CM4S, and Pi 400)
    if [[ "$MODEL" == *"Raspberry Pi 4"* || "$MODEL" == *"Raspberry Pi 3"* || "$MODEL" == *"Compute Module 4"* || "$MODEL" == *"Compute Module 3"* || "$MODEL" == *"Pi 400"* ]]; then
        # Find mount point for /boot/firmware, /boot, or /
        BOOT_DEV=$(findmnt -n -o SOURCE /boot/firmware || findmnt -n -o SOURCE /boot || findmnt -n -o SOURCE / || true)
        
        if [ -z "$BOOT_DEV" ] && [ -f "$cmdline_file" ]; then
            # Match root=something
            local ROOT_PART
            ROOT_PART=$(grep -o 'root=[^ ]*' "$cmdline_file" || true)
            # Remove only the 'root=' prefix
            BOOT_DEV="${ROOT_PART#root=}"
            # If it's a UUID/PARTUUID, try to resolve it
            if [[ "$BOOT_DEV" == UUID=* ]] || [[ "$BOOT_DEV" == PARTUUID=* ]]; then
                local UUID_VAL="${BOOT_DEV#*=}"
                if is_block_dev "/dev/disk/by-partuuid/$UUID_VAL"; then
                    BOOT_DEV=$(readlink "/dev/disk/by-partuuid/$UUID_VAL" 2>/dev/null || true)
                    if [ -n "$BOOT_DEV" ] && [[ "$BOOT_DEV" != /* ]]; then
                        BOOT_DEV="/dev/${BOOT_DEV##*/}"
                    fi
                elif is_block_dev "/dev/disk/by-uuid/$UUID_VAL"; then
                    BOOT_DEV=$(readlink "/dev/disk/by-uuid/$UUID_VAL" 2>/dev/null || true)
                    if [ -n "$BOOT_DEV" ] && [[ "$BOOT_DEV" != /* ]]; then
                        BOOT_DEV="/dev/${BOOT_DEV##*/}"
                    fi
                fi
            fi
        fi

        # Guard against empty BOOT_DEV
        if [ -z "$BOOT_DEV" ]; then
            echo "unsupported_boot_device"
            return 0
        fi

        # If boot/root device matches nvme or sd (USB/SATA SSD), block it
        if [[ "$BOOT_DEV" == *nvme* ]]; then
            echo "unsupported_boot_device_nvme"
            return 0
        elif [[ "$BOOT_DEV" == *sd* ]]; then
            echo "unsupported_boot_device_ssd"
            return 0
        elif [[ "$BOOT_DEV" == *mmcblk* || "$BOOT_DEV" == *loop* || "$BOOT_DEV" == *overlay* ]]; then
            echo "allowed"
            return 0
        else
            echo "unsupported_boot_device"
            return 0
        fi
    fi

    echo "allowed"
}

query_ha_firmware() {
    if ! command -v ha >/dev/null 2>&1; then
        return 1
    fi

    local status_json
    if ! status_json=$(timeout 15 ha os boards raspberrypi firmware --raw-json 2>/dev/null); then
        return 2
    fi

    local FORMATTED; FORMATTED=$(STATUS_JSON="$status_json" python3 - 2>/dev/null <<'EOF'
import sys
import json
import os

try:
    data = json.loads(os.environ.get("STATUS_JSON", "{}"))
    if data.get("result") != "ok":
        sys.exit(1)

    payload = data.get("data")
    if not isinstance(payload, dict):
        sys.exit(1)

    required_keys = (
        "current_version",
        "latest_version",
        "update_available",
        "update_blocked",
        "blocked_reason",
    )
    if any(key not in payload for key in required_keys):
        sys.exit(1)

    curr = payload.get("current_version")
    late = payload.get("latest_version")
    avail_raw = payload.get("update_available")
    block_raw = payload.get("update_blocked")
    reas = payload.get("blocked_reason")

    if not isinstance(curr, str) or not curr.strip():
        sys.exit(1)
    if not isinstance(late, str) or not late.strip():
        sys.exit(1)
    if not isinstance(avail_raw, bool):
        sys.exit(1)
    if not isinstance(block_raw, bool):
        sys.exit(1)
    if not isinstance(reas, str) or not reas.strip():
        sys.exit(1)

    avail = str(avail_raw).lower()
    block = str(block_raw).lower()
    print(f"current_version: \"{curr}\" latest_version: \"{late}\" update_available: {avail} update_blocked: {block} blocked_reason: {reas}")
except Exception:
    sys.exit(1)
EOF
    ) || return 3

    echo "$FORMATTED"
    return 0
}

run_check() {
    # Check if ha CLI is available and has supervisor integration
    local HA_SUMMARY
    if HA_SUMMARY=$(query_ha_firmware); then
        echo "$HA_SUMMARY"
        return 0
    fi

    # Fallback to manual checking using rpi-eeprom-update and boot dev checks
    if ! command -v rpi-eeprom-update >/dev/null 2>&1; then
        emit_summary "Unknown" "Unknown" "false" "true" "rpi_eeprom_update_missing"
        return 0
    fi

    # Extract versions from rpi-eeprom-update
    if EEPROM_OUT=$(timeout 15 rpi-eeprom-update 2>/dev/null); then
        CUR_VER=$(echo "$EEPROM_OUT" | grep -m 1 "CURRENT:" | cut -d: -f2- | xargs || true)
        LAT_VER=$(echo "$EEPROM_OUT" | grep -m 1 "LATEST:" | cut -d: -f2- | xargs || true)
        BOOTLOADER_LINE=$(echo "$EEPROM_OUT" | grep "BOOTLOADER:" || true)
        if [ -z "$CUR_VER" ] || [ -z "$LAT_VER" ]; then
            emit_summary "Unknown" "Unknown" "false" "true" "eeprom_version_parse_error"
            return 0
        fi
        if echo "$BOOTLOADER_LINE" | grep -q "update available"; then
            AVAIL="true"
        else
            AVAIL="false"
        fi
    else
        emit_summary "Unknown" "Unknown" "false" "true" "eeprom_query_failed"
        return 0
    fi

    # Check for SSD boot block
    BOOT_STATUS=$(check_ssd_boot)
    if [ "$BOOT_STATUS" != "allowed" ]; then
        emit_summary "$CUR_VER" "$LAT_VER" "$AVAIL" "true" "$BOOT_STATUS"
        return 0
    fi

    emit_summary "$CUR_VER" "$LAT_VER" "$AVAIL" "false" "None"
}

run_update() {
    # Run checks first
    if command -v ha >/dev/null 2>&1; then
        local HA_SUMMARY
        local err=0
        HA_SUMMARY=$(query_ha_firmware) || err=$?
        
        if [ "$err" -eq 2 ]; then
            echo "ERROR: Failed to query firmware upgrade status from HA OS Agent."
            return 1
        elif [ "$err" -ne 0 ]; then
            echo "ERROR: Failed to parse HA OS firmware status response."
            return 1
        fi
        
        # Check if update_blocked: true is in HA_SUMMARY
        if [[ "$HA_SUMMARY" == *"update_blocked: true"* ]]; then
            echo "ERROR: Update is blocked by OS Agent."
            return 1
        fi

        # Check if an update is actually available
        if [[ "$HA_SUMMARY" != *"update_available: true"* ]]; then
            echo "ERROR: No firmware update is available."
            return 1
        fi
        
        # If not blocked and update available, apply update using ha in background
        echo "Applying firmware update via HA OS CLI..."
        nohup bash -c "(echo \"=== Update started at \$(date) ===\" && ha os boards raspberrypi firmware update; status=\$?; echo \"Update exit status: \$status\"; [ \$status -eq 0 ] && ha host reboot) >> /var/log/pi_firmware_update.log 2>&1" >/dev/null 2>&1 &
        return 0
    fi

    # Fallback checks
    BOOT_STATUS=$(check_ssd_boot)
    if [ "$BOOT_STATUS" != "allowed" ]; then
        echo "ERROR: Firmware update is blocked: $BOOT_STATUS."
        return 1
    fi

    if ! command -v rpi-eeprom-update >/dev/null 2>&1; then
        echo "ERROR: rpi-eeprom-update utility not found."
        return 1
    fi

    # Check if an update is actually available before scheduling
    local EEPROM_CHECK
    EEPROM_CHECK=$(timeout 15 rpi-eeprom-update 2>/dev/null) || true
    if ! echo "$EEPROM_CHECK" | grep -q "update available"; then
        echo "ERROR: No firmware update is available."
        return 1
    fi

    echo "Applying firmware update via rpi-eeprom-update..."
    nohup bash -c "(echo \"=== Update started at \$(date) ===\" && timeout 120 rpi-eeprom-update -a; status=\$?; echo \"Update exit status: \$status\"; [ \$status -eq 0 ] && reboot) >> /var/log/pi_firmware_update.log 2>&1" >/dev/null 2>&1 &
    return 0
}

# Main execution
MODE="check"
if [ "$1" = "--update" ]; then
    MODE="update"
fi

if [ "$MODE" = "update" ]; then
    if ! run_update; then
        exit 1
    fi
else
    run_check
fi
