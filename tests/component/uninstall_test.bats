#!/usr/bin/env bats

setup() {
    mkdir -p /config/custom_components/pi_firmware_updater
    mkdir -p /config/.ssh

    echo "    - action: notify.my_phone" > /config/custom_components/pi_firmware_updater/update_notification.yaml
    echo "    - action: notify.my_phone" > /config/custom_components/pi_firmware_updater/action_handler.yaml

    touch /config/.ssh/id_rsa
    echo "ssh-rsa AAAAMOCKEXISTINGKEYDATASTRINGWITHLENGTH pi_firmware_updater" > /config/.ssh/id_rsa.pub

    SCRIPT_DIR="/app/custom_components/pi_firmware_updater"
    UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall.sh"

    export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
    chmod +x "$BATS_TEST_DIRNAME/../mocks/ssh"
    unset MOCK_SSH_FAIL
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

@test "Removes SSH keys" {
    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "/config/.ssh/id_rsa" ]
    [ ! -f "/config/.ssh/id_rsa.pub" ]
}

@test "Cleans host authorization before deleting local keys" {
    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "/config/.ssh/id_rsa" ]
    grep -q "identity=yes cmd=pi_firmware_uninstall" "$MOCK_SSH_LOG"
    [[ "$output" == *"Host authorization cleaned up"* ]]
}

@test "Warns and fails when host cleanup SSH fails" {
    export MOCK_SSH_AUTHORIZE_FAIL="true"

    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [ ! -f "/config/.ssh/id_rsa" ]
    [ ! -f "/config/.ssh/id_rsa.pub" ]
    [[ "$output" == *"WARNING: Could not remove host SSH authorization"* ]]
    [[ "$output" == *"incomplete host cleanup"* ]]
}

@test "Reverts YAML files" {
    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]

    run cat /config/custom_components/pi_firmware_updater/update_notification.yaml
    [[ "$output" == *"notify.REPLACE_WITH_YOUR_DEVICE_ID"* ]]

    run cat /config/custom_components/pi_firmware_updater/action_handler.yaml
    [[ "$output" == *"notify.REPLACE_WITH_YOUR_DEVICE_ID"* ]]
}

@test "Missing keys try password bootstrap then exit nonzero on failure" {
    rm -f /config/.ssh/id_rsa
    rm -f /config/.ssh/id_rsa.pub
    export MOCK_SSH_AUTHORIZE_FAIL="true"

    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"password bootstrap cleanup"* ]]
    [[ "$output" == *"No SSH keys found"* ]]
    [[ "$output" == *"incomplete host cleanup"* ]]
    grep -q "identity=no cmd=bash -s" "$MOCK_SSH_LOG"
}

@test "Missing keys succeed via password bootstrap cleanup" {
    rm -f /config/.ssh/id_rsa
    rm -f /config/.ssh/id_rsa.pub

    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"password bootstrap cleanup"* ]]
    grep -q "identity=no cmd=bash -s" "$MOCK_SSH_LOG"
}

@test "Handles missing config files gracefully" {
    rm -f /config/custom_components/pi_firmware_updater/update_notification.yaml
    rm -f /config/custom_components/pi_firmware_updater/action_handler.yaml

    run bash "$UNINSTALL_SCRIPT"
    [ "$status" -eq 0 ]
}
