#!/usr/bin/env bats

setup() {
    # Create an isolated temp directory for mocks and files per test
    TEST_DIR=$(mktemp -d)
    mkdir -p "$TEST_DIR/bin"
    
    # Path to script under test
    HOST_CHECK_SCRIPT="/app/custom_components/pi_firmware_updater/host_check.sh"
    
    # Setup test file variables
    export MODEL_FILE="$TEST_DIR/model"
    export CMDLINE_FILE="$TEST_DIR/cmdline"
    
    # Setup update and reboot markers
    export UPDATE_MARKER="$TEST_DIR/update_marker"
    export REBOOT_MARKER="$TEST_DIR/reboot_marker"
    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"

    # Clean/Reset environment variables
    unset MOCK_EEPROM_EXISTS
    unset MOCK_FINDMNT_DEV
    
    # Prepare clean mock scripts
    # Note: We DO NOT mock 'ha' by default here so that 'command -v ha' fails naturally.
    # Tests that require 'ha' will call create_mock_ha.

    # Mock 'rpi-eeprom-update'
    echo '#!/bin/bash
if [ "$MOCK_EEPROM_EXISTS" = "false" ]; then
    exit 127
fi
if [ "$1" = "-a" ]; then
    echo "Updating eeprom..."
    touch "$UPDATE_MARKER"
    exit 0
fi
echo "BOOTLOADER: update available"
echo "CURRENT: Thu 29 Apr 2021 11:11:25 AM UTC (1619694685)"
echo "LATEST: Thu 29 Apr 2021 11:11:25 AM UTC (1778498402)"
echo "RELEASE: default"
exit 0
' > "$TEST_DIR/bin/rpi-eeprom-update"
    chmod +x "$TEST_DIR/bin/rpi-eeprom-update"

    # Mock 'findmnt'
    echo '#!/bin/bash
if [ -n "$MOCK_FINDMNT_DEV" ]; then
    echo "$MOCK_FINDMNT_DEV"
    exit 0
fi
exit 1
' > "$TEST_DIR/bin/findmnt"
    chmod +x "$TEST_DIR/bin/findmnt"

    # Mock 'reboot'
    echo '#!/bin/bash
echo "Rebooting..."
touch "$REBOOT_MARKER"
exit 0
' > "$TEST_DIR/bin/reboot"
    chmod +x "$TEST_DIR/bin/reboot"

    export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

create_mock_ha() {
    local blocked="$1"
    echo "#!/bin/bash
if [ \"\$1\" = \"os\" ] && [ \"\$2\" = \"boards\" ] && [ \"\$3\" = \"raspberrypi\" ] && [ \"\$4\" = \"firmware\" ]; then
    if [ \"\$5\" = \"update\" ]; then
        echo \"Updating firmware...\"
        touch \"$UPDATE_MARKER\"
        exit 0
    fi
    if [ \"\$5\" = \"--raw-json\" ]; then
        if [ \"$blocked\" = \"true\" ]; then
            echo '{\"result\": \"ok\", \"data\": {\"current_version\": \"1765222194\", \"latest_version\": \"1778498402\", \"update_available\": true, \"update_blocked\": true, \"blocked_reason\": \"unsupported_boot_device\"}}'
        else
            echo '{\"result\": \"ok\", \"data\": {\"current_version\": \"1765222194\", \"latest_version\": \"1778498402\", \"update_available\": true, \"update_blocked\": false, \"blocked_reason\": \"None\"}}'
        fi
        exit 0
    fi
fi
if [ \"\$1\" = \"host\" ] && [ \"\$2\" = \"reboot\" ]; then
    echo \"Rebooting host...\"
    touch \"$REBOOT_MARKER\"
    exit 0
fi
exit 1
" > "$TEST_DIR/bin/ha"
    chmod +x "$TEST_DIR/bin/ha"
}

@test "HostCheck: Blocks on Raspberry Pi 4 when booting from NVMe" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/nvme0n1p2"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: Blocks on Compute Module 4 when booting from NVMe" {
    echo -n "Raspberry Pi Compute Module 4 Rev 1.0" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/nvme0n1p2"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: Blocks on Raspberry Pi 4 when booting from USB SSD" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/sda2"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: Allows on Raspberry Pi 4 when booting from SD Card" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
    [[ "$output" == *"update_available: true"* ]]
}

@test "HostCheck: Allows on Raspberry Pi 5 when booting from NVMe" {
    echo -n "Raspberry Pi 5 Model B Rev 1.0" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/nvme0n1p2"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
    [[ "$output" == *"update_available: true"* ]]
}

@test "HostCheck: Follows 'ha' command block status when HA CLI is available (blocked)" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"  # fallback would be allowed
    create_mock_ha true                      # HA CLI is blocked
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: Follows 'ha' command block status when HA CLI is available (allowed)" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/nvme0n1p2"  # fallback would be blocked
    create_mock_ha false                     # HA CLI is allowed
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
}

@test "HostCheck: Falls back in run_check when HA CLI query fails" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"  # fallback would be allowed
    
    # Mock HA CLI to fail
    echo '#!/bin/bash
exit 1
' > "$TEST_DIR/bin/ha"
    chmod +x "$TEST_DIR/bin/ha"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
    [[ "$output" == *"update_available: true"* ]]
}

@test "HostCheck: Falls back in run_check when HA CLI returns invalid JSON" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"  # fallback would be allowed
    
    # Mock HA CLI to return invalid JSON
    echo '#!/bin/bash
echo "invalid json"
exit 0
' > "$TEST_DIR/bin/ha"
    chmod +x "$TEST_DIR/bin/ha"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
    [[ "$output" == *"update_available: true"* ]]
}

@test "HostCheck: Blocks updates with exit status 1 in update mode when blocked" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/nvme0n1p2"
    
    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR:"* ]]
    [ ! -f "$UPDATE_MARKER" ]
    [ ! -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Allows updates in update mode when not blocked" {
    echo -n "Raspberry Pi 5 Model B Rev 1.0" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/nvme0n1p2"
    
    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Applying firmware update"* ]]
    
    # Wait up to 2 seconds for background processes to write markers
    for i in {1..20}; do
        [ -f "$UPDATE_MARKER" ] && [ -f "$REBOOT_MARKER" ] && break
        sleep 0.1
    done
    [ -f "$UPDATE_MARKER" ]
    [ -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Does not reboot when rpi-eeprom-update -a fails" {
    echo -n "Raspberry Pi 5 Model B Rev 1.0" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/nvme0n1p2"

    # Override eeprom mock: -a exits 1 (flash failure), status check reports available
    cat > "$TEST_DIR/bin/rpi-eeprom-update" <<MOCK
#!/bin/bash
if [ "\$1" = "-a" ]; then
    echo "Flash failed"
    touch "${UPDATE_MARKER}"
    exit 1
fi
echo "BOOTLOADER: update available"
echo "CURRENT: Thu 29 Apr 2021 11:11:25 AM UTC (1619694685)"
echo "LATEST: Thu 29 Apr 2021 11:11:25 AM UTC (1778498402)"
echo "RELEASE: default"
exit 0
MOCK
    chmod +x "$TEST_DIR/bin/rpi-eeprom-update"

    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Applying firmware update"* ]]

    # Wait briefly for background nohup to run and attempt the update
    for i in {1..20}; do
        [ -f "$UPDATE_MARKER" ] && break
        sleep 0.1
    done
    # Update was attempted
    [ -f "$UPDATE_MARKER" ]
    # But reboot must NOT have been called because -a exited non-zero
    sleep 0.3
    [ ! -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Allows check if model file is missing" {
    export MODEL_FILE="$TEST_DIR/non_existent_model"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
}

@test "HostCheck: Fallbacks to cmdline root device if findmnt fails" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo -n "console=serial0,115200 root=/dev/sda2 rw" > "$CMDLINE_FILE"
    export MOCK_EEPROM_EXISTS="true"
    # force findmnt to fail (MOCK_FINDMNT_DEV is unset)
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: Blocks check if rpi-eeprom-update is missing" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    rm -f "$TEST_DIR/bin/rpi-eeprom-update"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: rpi_eeprom_update_missing"* ]]
}

@test "HostCheck: Blocks updates in update mode when blocked via HA CLI" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    create_mock_ha true
    
    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Update is blocked by OS Agent."* ]]
    [ ! -f "$UPDATE_MARKER" ]
    [ ! -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Blocks updates in update mode when rpi-eeprom-update is missing" {
    echo -n "Raspberry Pi 5 Model B Rev 1.0" > "$MODEL_FILE"
    rm -f "$TEST_DIR/bin/rpi-eeprom-update"
    
    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: rpi-eeprom-update utility not found."* ]]
    [ ! -f "$UPDATE_MARKER" ]
    [ ! -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Blocks check if boot device is completely unknown" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    rm -f "$CMDLINE_FILE"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: Blocks updates in update mode when HA CLI query fails" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo '#!/bin/bash
exit 1
' > "$TEST_DIR/bin/ha"
    chmod +x "$TEST_DIR/bin/ha"
    
    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Failed to query"* ]]
    [ ! -f "$UPDATE_MARKER" ]
    [ ! -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Blocks updates in update mode when HA CLI returns invalid JSON" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo '#!/bin/bash
echo "not valid json"
exit 0
' > "$TEST_DIR/bin/ha"
    chmod +x "$TEST_DIR/bin/ha"
    
    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Failed to parse"* ]]
    [ ! -f "$UPDATE_MARKER" ]
    [ ! -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Falls back in run_check when HA CLI JSON is missing required update_blocked key" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # Missing update_blocked must cause parser failure and fallback execution
    cat > "$TEST_DIR/bin/ha" <<'MOCK'
#!/bin/bash
if [ "$1" = "os" ] && [ "$5" = "--raw-json" ]; then
    echo '{"result":"ok","data":{"current_version":"1765222194","latest_version":"1778498402","update_available":true,"blocked_reason":"None"}}'
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/ha"

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
    [[ "$output" == *"update_available: true"* ]]
}

@test "HostCheck: Blocks updates in update mode when HA CLI JSON is missing required update_blocked key" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"

    cat > "$TEST_DIR/bin/ha" <<'MOCK'
#!/bin/bash
if [ "$1" = "os" ] && [ "$5" = "--raw-json" ]; then
    echo '{"result":"ok","data":{"current_version":"1765222194","latest_version":"1778498402","update_available":true,"blocked_reason":"None"}}'
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/ha"

    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Failed to parse"* ]]
}

@test "HostCheck: Resolves root device via PARTUUID using exported is_block_dev helper" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo -n "console=serial0,115200 root=PARTUUID=12345678-02 rw" > "$CMDLINE_FILE"
    export MOCK_EEPROM_EXISTS="true"

    # Record the symlink argument; resolve to an NVMe device (blocked)
    READLINK_ARG_FILE="$TEST_DIR/readlink_arg"
    cat > "$TEST_DIR/bin/readlink" <<'MOCK'
#!/bin/bash
echo "$1" >> "${READLINK_ARG_FILE}"
echo "/dev/nvme0n1p2"
exit 0
MOCK
    chmod +x "$TEST_DIR/bin/readlink"

    # Mock is_block_dev: accept only the expected by-partuuid path
    is_block_dev() {
        [[ "$1" == */by-partuuid/* ]] || return 1
        return 0
    }
    export -f is_block_dev
    export READLINK_ARG_FILE

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
    # Confirm readlink was called with the correct PARTUUID path
    grep -q "/dev/disk/by-partuuid/12345678-02" "$READLINK_ARG_FILE"

    unset -f is_block_dev
}

@test "HostCheck: Resolves root device via UUID using exported is_block_dev helper" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo -n "console=serial0,115200 root=UUID=5831-294 rw" > "$CMDLINE_FILE"
    export MOCK_EEPROM_EXISTS="true"

    # Record the symlink argument; resolve to an SD-card device (allowed)
    READLINK_ARG_FILE="$TEST_DIR/readlink_arg"
    cat > "$TEST_DIR/bin/readlink" <<'MOCK'
#!/bin/bash
echo "$1" >> "${READLINK_ARG_FILE}"
echo "/dev/mmcblk0p2"
exit 0
MOCK
    chmod +x "$TEST_DIR/bin/readlink"

    # Mock is_block_dev: accept only the expected by-uuid path
    is_block_dev() {
        [[ "$1" == */by-uuid/* ]] || return 1
        return 0
    }
    export -f is_block_dev
    export READLINK_ARG_FILE

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
    # Confirm readlink was called with the correct UUID path
    grep -q "/dev/disk/by-uuid/5831-294" "$READLINK_ARG_FILE"

    unset -f is_block_dev
}

@test "HostCheck: Handles check when firmware is already up-to-date" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"
    
    # Mock rpi-eeprom-update to return up-to-date output
    echo '#!/bin/bash
echo "BOOTLOADER: up-to-date"
echo "CURRENT: Thu 29 Apr 2021 11:11:25 AM UTC (1619694685)"
echo "LATEST: Thu 29 Apr 2021 11:11:25 AM UTC (1619694685)"
exit 0
' > "$TEST_DIR/bin/rpi-eeprom-update"
    chmod +x "$TEST_DIR/bin/rpi-eeprom-update"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
    [[ "$output" == *"update_available: false"* ]]
}

@test "HostCheck: Handles eeprom query failure path gracefully" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"
    
    # Mock rpi-eeprom-update to fail (exit 1)
    echo '#!/bin/bash
exit 1
' > "$TEST_DIR/bin/rpi-eeprom-update"
    chmod +x "$TEST_DIR/bin/rpi-eeprom-update"
    
    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: eeprom_query_failed"* ]]
}

@test "HostCheck: Blocks run_check when eeprom returns empty versions" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # Mock rpi-eeprom-update to return output without CURRENT/LATEST lines
    echo '#!/bin/bash
echo "BOOTLOADER: update available"
exit 0
' > "$TEST_DIR/bin/rpi-eeprom-update"
    chmod +x "$TEST_DIR/bin/rpi-eeprom-update"

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: eeprom_version_parse_error"* ]]
}

@test "HostCheck: Blocks update in update mode when no update available via HA CLI" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # Mock HA CLI reporting update_available: false
    echo '#!/bin/bash
if [ "$1" = "os" ] && [ "$5" = "--raw-json" ]; then
    echo "{\"result\": \"ok\", \"data\": {\"current_version\": \"1765222194\", \"latest_version\": \"1765222194\", \"update_available\": false, \"update_blocked\": false, \"blocked_reason\": \"None\"}}"
    exit 0
fi
exit 1
' > "$TEST_DIR/bin/ha"
    chmod +x "$TEST_DIR/bin/ha"

    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: No firmware update is available."* ]]
}

@test "HostCheck: Blocks update in update mode when no update available via rpi-eeprom-update" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # Mock rpi-eeprom-update to report up-to-date (no "update available")
    echo '#!/bin/bash
echo "BOOTLOADER: up-to-date"
echo "CURRENT: Thu 29 Apr 2021 11:11:25 AM UTC (1619694685)"
echo "LATEST: Thu 29 Apr 2021 11:11:25 AM UTC (1619694685)"
exit 0
' > "$TEST_DIR/bin/rpi-eeprom-update"
    chmod +x "$TEST_DIR/bin/rpi-eeprom-update"

    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: No firmware update is available."* ]]
}
@test "HostCheck: Blocks when boot device is unrecognised type (vda)" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/vda2"

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: Resolves root device via UUID fallback in cmdline" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo -n "console=serial0,115200 root=UUID=abc123 rw" > "$CMDLINE_FILE"
    export MOCK_EEPROM_EXISTS="true"

    # Mock readlink to return nvme device (so update gets blocked)
    echo '#!/bin/bash
echo "/dev/nvme0n1p2"
exit 0
' > "$TEST_DIR/bin/readlink"
    chmod +x "$TEST_DIR/bin/readlink"

    # Export is_block_dev: false for PARTUUID path, true for UUID path
    is_block_dev() {
        case "$1" in
            */by-partuuid/*) return 1 ;;
            */by-uuid/*) return 0 ;;
            *) [ -b "$1" ] ;;
        esac
    }
    export -f is_block_dev

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]

    unset -f is_block_dev
}

@test "HostCheck: Uses native is_block_dev when not mocked" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # Ensure is_block_dev is NOT exported -- tests the native [ -b "$1" ] path
    unset -f is_block_dev

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: false"* ]]
}

@test "HostCheck: Applies update via HA CLI on Pi 4 booting from SD card" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # HA CLI present with update available and not blocked
    create_mock_ha false

    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Applying firmware update via HA OS CLI"* ]]

    # Wait up to 2 seconds for background nohup to write markers
    for i in {1..20}; do
        [ -f "$UPDATE_MARKER" ] && [ -f "$REBOOT_MARKER" ] && break
        sleep 0.1
    done
    [ -f "$UPDATE_MARKER" ]
    [ -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Does not reboot when HA CLI firmware update command fails" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # HA CLI: status query succeeds (not blocked, update available),
    # but the actual firmware update command exits 1 (flash failure)
    cat > "$TEST_DIR/bin/ha" <<MOCK
#!/bin/bash
if [ "\$1" = "os" ] && [ "\$2" = "boards" ] && [ "\$3" = "raspberrypi" ] && [ "\$4" = "firmware" ]; then
    if [ "\$5" = "update" ]; then
        echo "Firmware flash failed"
        touch "${UPDATE_MARKER}"
        exit 1
    fi
    if [ "\$5" = "--raw-json" ]; then
        echo '{"result": "ok", "data": {"current_version": "1765222194", "latest_version": "1778498402", "update_available": true, "update_blocked": false, "blocked_reason": "None"}}'
        exit 0
    fi
fi
if [ "\$1" = "host" ] && [ "\$2" = "reboot" ]; then
    touch "${REBOOT_MARKER}"
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/ha"

    rm -f "$UPDATE_MARKER" "$REBOOT_MARKER"
    run bash "$HOST_CHECK_SCRIPT" --update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Applying firmware update via HA OS CLI"* ]]

    # Wait briefly for background nohup to attempt the update
    for i in {1..20}; do
        [ -f "$UPDATE_MARKER" ] && break
        sleep 0.1
    done
    # Update was attempted
    [ -f "$UPDATE_MARKER" ]
    # But reboot must NOT have been called because the update command exited non-zero
    sleep 0.3
    [ ! -f "$REBOOT_MARKER" ]
}

@test "HostCheck: Exercises native is_block_dev with PARTUUID cmdline (block dev absent)" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo -n "console=serial0,115200 root=PARTUUID=deadbeef-02 rw" > "$CMDLINE_FILE"
    export MOCK_EEPROM_EXISTS="true"
    # No findmnt mock — findmnt fails, falls back to cmdline
    # No is_block_dev export — native [ -b ] runs on line 10

    unset -f is_block_dev

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    # by-partuuid path doesn't exist in container, so BOOT_DEV stays empty -> unknown_boot_device
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device"* ]]
}

@test "HostCheck: query_ha_firmware returns formatted output on valid JSON (covers heredoc success path)" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    export MOCK_EEPROM_EXISTS="true"
    export MOCK_FINDMNT_DEV="/dev/mmcblk0p2"

    # HA CLI returns well-formed JSON — exercises line 94 (if ! FORMATTED=...) success branch
    echo '#!/bin/bash
if [ "$1" = "os" ] && [ "$5" = "--raw-json" ]; then
    echo "{\"result\": \"ok\", \"data\": {\"current_version\": \"111\", \"latest_version\": \"222\", \"update_available\": true, \"update_blocked\": false, \"blocked_reason\": \"None\"}}"
    exit 0
fi
exit 1
' > "$TEST_DIR/bin/ha"
    chmod +x "$TEST_DIR/bin/ha"

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"current_version: \"111\""* ]]
    [[ "$output" == *"update_available: true"* ]]
}

@test "HostCheck: Normalizes relative readlink result for PARTUUID path" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo -n "console=serial0,115200 root=PARTUUID=1234-AB rw" > "$CMDLINE_FILE"
    export MOCK_EEPROM_EXISTS="true"

    cat > "$TEST_DIR/bin/readlink" <<'MOCK'
#!/bin/bash
echo "../../nvme0n1p2"
exit 0
MOCK
    chmod +x "$TEST_DIR/bin/readlink"

    is_block_dev() {
        [[ "$1" == */by-partuuid/* ]]
    }
    export -f is_block_dev

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device_nvme"* ]]

    unset -f is_block_dev
}

@test "HostCheck: Normalizes relative readlink result for UUID path" {
    echo -n "Raspberry Pi 4 Model B Rev 1.2" > "$MODEL_FILE"
    echo -n "console=serial0,115200 root=UUID=ABCD-1234 rw" > "$CMDLINE_FILE"
    export MOCK_EEPROM_EXISTS="true"

    cat > "$TEST_DIR/bin/readlink" <<'MOCK'
#!/bin/bash
echo "../../sdx2"
exit 0
MOCK
    chmod +x "$TEST_DIR/bin/readlink"

    is_block_dev() {
        [[ "$1" == */by-uuid/* ]]
    }
    export -f is_block_dev

    run bash "$HOST_CHECK_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_blocked: true"* ]]
    [[ "$output" == *"blocked_reason: unsupported_boot_device_ssd"* ]]

    unset -f is_block_dev
}
