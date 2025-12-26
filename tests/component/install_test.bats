#!/usr/bin/env bats

setup() {
    # Create the config directory structure that install.sh expects
    mkdir -p /config/custom_components/pi_firmware_updater
    mkdir -p /config/.ssh
    
    # Create dummy files that install.sh expects to exist for sed replacement
    echo "notify.REPLACE_WITH_YOUR_DEVICE_ID" > /config/custom_components/pi_firmware_updater/update_notification.yaml
    echo "notify.REPLACE_WITH_YOUR_DEVICE_ID" > /config/custom_components/pi_firmware_updater/action_handler.yaml

    # Path to the script under test
    SCRIPT_DIR="/app/custom_components/pi_firmware_updater"
    INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
    
    # Setup Mocks
    export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
    chmod +x "$BATS_TEST_DIRNAME/../mocks/ssh"
    chmod +x "$BATS_TEST_DIRNAME/../mocks/ssh-keygen"
    
    # Default mock behavior
    unset MOCK_SSH_FAIL
}

teardown() {
    # Clean up
    rm -rf /config/.ssh
    rm -rf /config/custom_components
}

@test "Fails if Mobile ID is not provided" {
    # Ensure no pre-set env var
    unset MOBILE_ID
    # Pass empty string as input
    run bash -c "echo '' | $INSTALL_SCRIPT"
    [ "$status" -eq 0 ] # Script shouldn't crash
    [[ "$output" == *"No ID entered"* ]]
}

@test "Accepts Mobile ID via Environment Variable" {
    export MOBILE_ID="notify.env_var_device"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    
    run cat /config/custom_components/pi_firmware_updater/update_notification.yaml
    [[ "$output" == *"notify.env_var_device"* ]]
}

@test "Creates .ssh directory and Generates Key if missing" {
    rm -rf /config/.ssh
    
    # Mock specific check in script (it checks for id_rsa)
    export MOBILE_ID="notify.test"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ -d "/config/.ssh" ]
    [ -f "/config/.ssh/id_rsa" ]
    [[ "$output" == *"Generating RSA key pair"* ]]
}

@test "Skips Key Generation if Key exists" {
    touch /config/.ssh/id_rsa
    touch /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SSH key already exists, skipping generation"* ]]
}

@test "Handles SSH Authorization Failure" {
    export MOCK_SSH_FAIL="true"
    export MOBILE_ID="notify.test"
    
    # Force the first check (connection check) to fail, so it tries to push key
    # But wait, my mock returns fail whenever MOCK_SSH_FAIL is true
    # The script:
    # 1. ssh connect check (fails)
    # 2. ssh push key (fails)
    # 3. exits with 1
    
    # Needs to match the command used in script.
    # Script calls `ssh -p ...` directly.
    # Since mocked ssh is in PATH, it should catch it if PATH is correct.
    
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not authorize key"* ]]
}

@test "Handles successful authorization after missing key" {
    export MOCK_SSH_CONNECTION_CHECK_FAIL="true"
    export MOBILE_ID="notify.test"
    
    # First check fails (simulates key not authorized)
    # Second check (push) succeeds (default mock behavior)
    
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Authorization successful"* ]]
}

@test "Sets correct permissions on .ssh files" {
    export MOBILE_ID="notify.test"
    touch /config/.ssh/id_rsa
    touch /config/.ssh/id_rsa.pub
    
    run bash "$INSTALL_SCRIPT"
    
    # Check permissions (octal)
    run stat -c "%a" /config/.ssh
    [ "$output" = "700" ]
    
    run stat -c "%a" /config/.ssh/id_rsa
    [ "$output" = "600" ]
    
    run stat -c "%a" /config/.ssh/id_rsa.pub
    [ "$output" = "644" ]
}

@test "Updates YAML files with Mobile ID" {
    run bash -c "echo 'notify.my_phone' | $INSTALL_SCRIPT"
    
    run cat /config/custom_components/pi_firmware_updater/update_notification.yaml
    [[ "$output" == *"notify.my_phone"* ]]
    
    run cat /config/custom_components/pi_firmware_updater/action_handler.yaml
    [[ "$output" == *"notify.my_phone"* ]]
}
