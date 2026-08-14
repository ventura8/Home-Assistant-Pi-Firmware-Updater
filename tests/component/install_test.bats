#!/usr/bin/env bats

setup() {
    mkdir -p /config/custom_components/pi_firmware_updater
    mkdir -p /config/.ssh

    echo "notify.REPLACE_WITH_YOUR_DEVICE_ID" > /config/custom_components/pi_firmware_updater/update_notification.yaml
    echo "notify.REPLACE_WITH_YOUR_DEVICE_ID" > /config/custom_components/pi_firmware_updater/action_handler.yaml

    SCRIPT_DIR="/app/custom_components/pi_firmware_updater"
    INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
    cp "$SCRIPT_DIR/host_check.sh" /config/custom_components/pi_firmware_updater/host_check.sh
    cp "$SCRIPT_DIR/ssh_wrapper.sh" /config/custom_components/pi_firmware_updater/ssh_wrapper.sh

    export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
    chmod +x "$BATS_TEST_DIRNAME/../mocks/ssh"
    chmod +x "$BATS_TEST_DIRNAME/../mocks/ssh-keygen"

    unset MOCK_SSH_FAIL
    unset MOCK_SSH_CONNECTION_CHECK_FAIL
    unset MOCK_SSH_AUTHORIZE_FAIL
    export MOCK_SSH_LOG="$BATS_TMPDIR/ssh_log"
    export MOCK_SSH_STDIN_LOG="$BATS_TMPDIR/ssh_stdin"
    rm -f "$MOCK_SSH_LOG" "$MOCK_SSH_STDIN_LOG"
}

teardown() {
    rm -rf /config/.ssh
    rm -rf /config/custom_components
    rm -f "$MOCK_SSH_LOG" "$MOCK_SSH_STDIN_LOG"
}

seed_existing_key() {
    touch /config/.ssh/id_rsa
    echo "ssh-rsa AAAAMOCKEXISTINGKEY pi_firmware_updater" > /config/.ssh/id_rsa.pub
}

@test "Fails if Mobile ID is not provided" {
    unset MOBILE_ID
    run bash -c "echo '' | $INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
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

    export MOBILE_ID="notify.test"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ -d "/config/.ssh" ]
    [ -f "/config/.ssh/id_rsa" ]
    [[ "$output" == *"Generating RSA key pair"* ]]
    run cat /config/.ssh/id_rsa.pub
    [[ "$output" == *"pi_firmware_updater"* ]]
}

@test "Skips Key Generation if Key exists" {
    seed_existing_key
    export MOBILE_ID="notify.test"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SSH key already exists, skipping generation"* ]]
}

@test "Regenerates public key when private key exists without pub" {
    touch /config/.ssh/id_rsa
    rm -f /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Regenerating public key"* ]]
    [ -s /config/.ssh/id_rsa.pub ]
    run cat /config/.ssh/id_rsa.pub
    [[ "$output" == *"AAAAMOCKRECOVEREDKEY"* ]]
}

@test "Handles SSH Authorization Failure" {
    export MOCK_SSH_FAIL="true"
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not authorize key"* ]]
}

@test "Handles successful authorization after missing key" {
    export MOCK_SSH_CONNECTION_CHECK_FAIL="true"
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Authorization successful"* ]]
    [[ "$output" == *"Attempting to push restricted key"* ]]
    grep -q "identity=no" "$MOCK_SSH_LOG"
}

@test "Refreshes restricted authorization when key auth already works" {
    seed_existing_key
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"refreshing host authorization"* ]]
    [[ "$output" == *"Authorization successful"* ]]
    grep -q "identity=yes cmd=pi_firmware_deploy_host_check" "$MOCK_SSH_LOG"
    grep -q "identity=yes cmd=pi_firmware_deploy_wrapper" "$MOCK_SSH_LOG"
    grep -q "identity=yes cmd=pi_firmware_deploy_auth" "$MOCK_SSH_LOG"
    grep -q 'restrict,from="127.0.0.1"' "$MOCK_SSH_STDIN_LOG"
    grep -q "ssh_wrapper.sh" "$MOCK_SSH_STDIN_LOG"
}

@test "Wrapper allowlists fixed ops and denies arbitrary commands" {
    WRAPPER=/config/custom_components/pi_firmware_updater/ssh_wrapper.sh
    chmod +x "$WRAPPER"

    # Denied command must fail closed
    run env SSH_ORIGINAL_COMMAND='rm -rf /' bash "$WRAPPER"
    [ "$status" -ne 0 ]
    [[ "$output" == *"command denied"* ]]

    # exit / empty succeed without executing stdin
    run env SSH_ORIGINAL_COMMAND='exit' bash "$WRAPPER"
    [ "$status" -eq 0 ]

    run env SSH_ORIGINAL_COMMAND='' bash "$WRAPPER"
    [ "$status" -eq 0 ]

    # deploy_host_check writes stdin to managed path without exec as shell
    mkdir -p /root/.pi_firmware_updater
    run bash -c "printf '%s\n' 'echo PWNED' | env SSH_ORIGINAL_COMMAND='pi_firmware_deploy_host_check' bash '$WRAPPER'"
    [ "$status" -eq 0 ]
    [ -f /root/.pi_firmware_updater/host_check.sh ]
    run cat /root/.pi_firmware_updater/host_check.sh
    [[ "$output" == "echo PWNED" ]]
    # Prove contents were not executed as a program by the wrapper itself
    [[ "$output" != *"PWNED executed"* ]]

    # Permitted check/update invoke host script path (create stub)
    printf '%s\n' '#!/bin/bash' 'echo CHECK_OK' > /root/.pi_firmware_updater/host_check.sh
    chmod 700 /root/.pi_firmware_updater/host_check.sh
    run env SSH_ORIGINAL_COMMAND='pi_firmware_check' bash "$WRAPPER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CHECK_OK"* ]]

    printf '%s\n' '#!/bin/bash' 'echo UPDATE_OK' > /root/.pi_firmware_updater/host_check.sh
    chmod 700 /root/.pi_firmware_updater/host_check.sh
    run env SSH_ORIGINAL_COMMAND='pi_firmware_update' bash "$WRAPPER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UPDATE_OK"* ]]

    rm -rf /root/.pi_firmware_updater
}

@test "Sets correct permissions on .ssh files" {
    export MOBILE_ID="notify.test"
    seed_existing_key

    run bash "$INSTALL_SCRIPT"

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
