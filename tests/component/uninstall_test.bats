#!/usr/bin/env bats

setup() {
    # Create the config directory structure
    mkdir -p /config/custom_components/pi_firmware_updater
    mkdir -p /config/.ssh
    
    # Create dummy files with "installed" values
    echo "    - action: notify.my_phone" > /config/custom_components/pi_firmware_updater/update_notification.yaml
    echo "    - action: notify.my_phone" > /config/custom_components/pi_firmware_updater/action_handler.yaml
    
    # Create mock keys
    touch /config/.ssh/id_rsa
    touch /config/.ssh/id_rsa.pub

    # Path to the script under test
    SCRIPT_DIR="/app/custom_components/pi_firmware_updater"
    UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall.sh"
}

teardown() {
    rm -rf /config/.ssh
    rm -rf /config/custom_components
}

@test "Removes SSH keys" {
    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "/config/.ssh/id_rsa" ]
    [ ! -f "/config/.ssh/id_rsa.pub" ]
}

@test "Reverts YAML files" {
    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    
    run cat /config/custom_components/pi_firmware_updater/update_notification.yaml
    [[ "$output" == *"notify.REPLACE_WITH_YOUR_DEVICE_ID"* ]]
    
    run cat /config/custom_components/pi_firmware_updater/action_handler.yaml
    [[ "$output" == *"notify.REPLACE_WITH_YOUR_DEVICE_ID"* ]]
}

@test "Handles missing keys gracefully (Idempotency)" {
    rm -f /config/.ssh/id_rsa
    rm -f /config/.ssh/id_rsa.pub
    
    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No SSH keys found"* ]]
}

@test "Handles missing config files gracefully" {
    rm -f /config/custom_components/pi_firmware_updater/update_notification.yaml
    rm -f /config/custom_components/pi_firmware_updater/action_handler.yaml
    
    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    # Should not crash
}
