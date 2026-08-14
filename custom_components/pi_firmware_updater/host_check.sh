#!/bin/bash
# host_check.sh
# Runs on the host OS via SSH. Detects if firmware updates are possible/blocked.

set -e

# Helper to mock block device checks in tests
if ! declare -F is_block_dev > /dev/null 2>&1; then
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
    echo "current_version: \"$current\" latest_version: \"$latest\" " \
        "update_available: $available update_blocked: $blocked " \
        "blocked_reason: $reason"
}

model_requires_boot_block() {
    case "$1" in
        *"Raspberry Pi 4"* | *"Raspberry Pi 3"* | *"Compute Module 4"* | *"Compute Module 3"* | *"Pi 400"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

normalize_device_path() {
    local device_path="$1"

    if [ -n "$device_path" ] && [[ "$device_path" != /* ]]; then
        echo "/dev/${device_path##*/}"
        return 0
    fi

    echo "$device_path"
}

resolve_boot_device_identifier() {
    local boot_device="$1"
    local link_target=""
    local uuid_value="${boot_device#*=}"

    case "$boot_device" in
        PARTUUID=*)
            if is_block_dev "/dev/disk/by-partuuid/$uuid_value"; then
                link_target=$(readlink "/dev/disk/by-partuuid/$uuid_value" 2> /dev/null || true)
                normalize_device_path "$link_target"
                return 0
            fi
            ;;
        UUID=*)
            if is_block_dev "/dev/disk/by-uuid/$uuid_value"; then
                link_target=$(readlink "/dev/disk/by-uuid/$uuid_value" 2> /dev/null || true)
                normalize_device_path "$link_target"
                return 0
            fi
            ;;
    esac

    echo "$boot_device"
}

classify_boot_device() {
    case "$1" in
        "")
            echo "unsupported_boot_device"
            ;;
        *nvme*)
            echo "unsupported_boot_device_nvme"
            ;;
        *sd*)
            echo "unsupported_boot_device_ssd"
            ;;
        *mmcblk* | *loop* | *overlay*)
            echo "allowed"
            ;;
        *)
            echo "unsupported_boot_device"
            ;;
    esac
}

load_eeprom_versions() {
    if ! command -v rpi-eeprom-update > /dev/null 2>&1; then
        return 1
    fi

    if ! EEPROM_OUT=$(timeout 15 rpi-eeprom-update 2> /dev/null); then
        return 2
    fi

    CUR_VER=$(echo "$EEPROM_OUT" | grep -m 1 "CURRENT:" | cut -d: -f2- | xargs || true)
    LAT_VER=$(echo "$EEPROM_OUT" | grep -m 1 "LATEST:" | cut -d: -f2- | xargs || true)
    BOOTLOADER_LINE=$(echo "$EEPROM_OUT" | grep "BOOTLOADER:" || true)

    if [ -z "$CUR_VER" ] || [ -z "$LAT_VER" ]; then
        return 3
    fi

    if echo "$BOOTLOADER_LINE" | grep -q "update available"; then
        AVAIL="true"
    else
        AVAIL="false"
    fi

    return 0
}

validate_ha_update_readiness() {
    local ha_summary=""
    local err=0

    ha_summary=$(query_ha_firmware) || err=$?

    case "$err" in
        0)
            ;;
        2)
            echo "ERROR: Failed to query firmware upgrade status from HA OS Agent."
            return 1
            ;;
        *)
            echo "ERROR: Failed to parse HA OS firmware status response."
            return 1
            ;;
    esac

    if [[ "$ha_summary" == *"update_blocked: true"* ]]; then
        echo "ERROR: Update is blocked by OS Agent."
        return 1
    fi

    if [[ "$ha_summary" != *"update_available: true"* ]]; then
        echo "ERROR: No firmware update is available."
        return 1
    fi

    return 0
}

validate_fallback_update_readiness() {
    local boot_status=""
    local eeprom_check=""

    boot_status=$(check_ssd_boot)
    if [ "$boot_status" != "allowed" ]; then
        echo "ERROR: Firmware update is blocked: $boot_status."
        return 1
    fi

    if ! command -v rpi-eeprom-update > /dev/null 2>&1; then
        echo "ERROR: rpi-eeprom-update utility not found."
        return 1
    fi

    eeprom_check=$(timeout 15 rpi-eeprom-update 2> /dev/null) || true
    if ! echo "$eeprom_check" | grep -q "update available"; then
        echo "ERROR: No firmware update is available."
        return 1
    fi

    return 0
}

build_ha_update_command() {
    cat << 'CMD'
echo "=== Update started at $(date) ===" &&
ha os boards raspberrypi firmware update
status=$?
echo "Update exit status: $status"
[ $status -eq 0 ] && ha host reboot
CMD
}

build_fallback_update_command() {
    cat << 'CMD'
echo "=== Update started at $(date) ===" &&
timeout 120 rpi-eeprom-update -a
status=$?
echo "Update exit status: $status"
[ $status -eq 0 ] && reboot
CMD
}

launch_background_update() {
    local update_command="$1"
    nohup bash -c "$update_command" >> /var/log/pi_firmware_update.log 2>&1 &
}

# Helper to check if running from SSD/NVMe
check_ssd_boot() {
    local model_file="${MODEL_FILE:-/proc/device-tree/model}"
    local cmdline_file="${CMDLINE_FILE:-/proc/cmdline}"
    local boot_device=""

    # Check model
    if [ -f "$model_file" ]; then
        MODEL=$(tr -d '\0' < "$model_file")
    else
        MODEL="Unknown"
    fi

    # We only block SSD boot on Raspberry Pi 3 and 4 family (including CM3/CM4, CM4S, and Pi 400)
    if ! model_requires_boot_block "$MODEL"; then
        echo "allowed"
        return 0
    fi

    # Find mount point for /boot/firmware, /boot, or /
    boot_device=$(findmnt -n -o SOURCE /boot/firmware || findmnt -n -o SOURCE /boot || findmnt -n -o SOURCE / || true)

    if [ -z "$boot_device" ] && [ -f "$cmdline_file" ]; then
        local root_part
        root_part=$(grep -o 'root=[^ ]*' "$cmdline_file" || true)
        boot_device=$(resolve_boot_device_identifier "${root_part#root=}")
    fi

    classify_boot_device "$boot_device"
}

query_ha_firmware() {
    if ! command -v ha > /dev/null 2>&1; then
        return 1
    fi

    local status_json
    if ! status_json=$(timeout 15 ha os boards raspberrypi firmware --raw-json 2> /dev/null); then
        return 2
    fi

    local FORMATTED
    FORMATTED=$(
        STATUS_JSON="$status_json" python3 - 2> /dev/null << 'EOF'
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
    print(
        f"current_version: \"{curr}\" latest_version: \"{late}\" "
        f"update_available: {avail} update_blocked: {block} "
        f"blocked_reason: {reas}"
    )
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
    local boot_status=""
    local eeprom_status=0

    if HA_SUMMARY=$(query_ha_firmware); then
        echo "$HA_SUMMARY"
        return 0
    fi

    load_eeprom_versions || eeprom_status=$?

    case "$eeprom_status" in
        1)
            emit_summary "Unknown" "Unknown" "false" "true" "rpi_eeprom_update_missing"
            return 0
            ;;
        2)
            emit_summary "Unknown" "Unknown" "false" "true" "eeprom_query_failed"
            return 0
            ;;
        3)
            emit_summary "Unknown" "Unknown" "false" "true" "eeprom_version_parse_error"
            return 0
            ;;
    esac

    # Check for SSD boot block
    boot_status=$(check_ssd_boot)
    if [ "$boot_status" != "allowed" ]; then
        emit_summary "$CUR_VER" "$LAT_VER" "$AVAIL" "true" "$boot_status"
        return 0
    fi

    emit_summary "$CUR_VER" "$LAT_VER" "$AVAIL" "false" "None"
}

run_update() {
    # Run checks first
    if command -v ha > /dev/null 2>&1; then
        local ha_update_cmd=""

        if ! validate_ha_update_readiness; then
            return 1
        fi

        ha_update_cmd=$(build_ha_update_command)

        echo "Applying firmware update via HA OS CLI..."
        launch_background_update "$ha_update_cmd"
        return 0
    fi

    local fallback_update_cmd=""

    if ! validate_fallback_update_readiness; then
        return 1
    fi

    fallback_update_cmd=$(build_fallback_update_command)

    echo "Applying firmware update via rpi-eeprom-update..."
    launch_background_update "$fallback_update_cmd"
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
