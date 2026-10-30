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
    unset MOCK_SSH_KEYGEN_DERIVE_FAIL
    export MOCK_SSH_LOG="$BATS_TMPDIR/ssh_log"
    export MOCK_SSH_STDIN_LOG="$BATS_TMPDIR/ssh_stdin"
    rm -f "$MOCK_SSH_LOG" "$MOCK_SSH_STDIN_LOG"
}

teardown() {
    rm -rf /config/.ssh
    rm -rf /config/custom_components
    rm -rf /root/.pi_firmware_updater /root/.ssh
    rm -f "$MOCK_SSH_LOG" "$MOCK_SSH_STDIN_LOG"
}

EXISTING_KEY="ssh-rsa AAAAMOCKEXISTINGKEYDATAEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE pi_firmware_updater"

# Mock convention: a private key file holding a pub line derives to that pub.
seed_existing_key() {
    echo "$EXISTING_KEY" > /config/.ssh/id_rsa
    echo "$EXISTING_KEY" > /config/.ssh/id_rsa.pub
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
    [[ "$output" == *"AAAAMOCKRECOVEREDKEYDATARRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"* ]]
}

@test "Rejects empty public key before host authorization" {
    touch /config/.ssh/id_rsa
    : > /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Public key file is missing or empty"* ]] \
        || [[ "$output" == *"Public key blob is missing"* ]]
}

@test "Rejects multi-line public key before any host mutation" {
    touch /config/.ssh/id_rsa
    printf '%s\n%s\n' \
        "$EXISTING_KEY" \
        "ssh-rsa AAAAMOCKPLANTEDATTACKERKEYDATASTRINGWITHLENGTH attacker" \
        > /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"exactly one key line"* ]]
    [ ! -f "$MOCK_SSH_STDIN_LOG" ]
}

@test "Accepts a single key record surrounded by blank lines" {
    echo "$EXISTING_KEY" > /config/.ssh/id_rsa
    printf '\n%s\n\n' \
        "$EXISTING_KEY" \
        > /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Authorization successful"* ]]
    grep -qF "$EXISTING_KEY" "$MOCK_SSH_STDIN_LOG"
}

@test "Rejects truncated public key blob before any host mutation" {
    touch /config/.ssh/id_rsa
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3 pi_firmware_updater" > /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Public key blob is missing or too short"* ]]
    [ ! -f "$MOCK_SSH_STDIN_LOG" ]
}

@test "Rejects public key that does not match the private key" {
    seed_existing_key
    echo "ssh-rsa AAAAMOCKPLANTEDKEYDATA$(printf 'P%.0s' {1..60}) pi_firmware_updater" > /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not match"* ]]
    [ ! -f "$MOCK_SSH_STDIN_LOG" ]
}

@test "Rejects install when the public key cannot be derived from id_rsa" {
    seed_existing_key
    export MOBILE_ID="notify.test"

    MOCK_SSH_KEYGEN_DERIVE_FAIL=true run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Could not derive the public key"* ]]
    [ ! -f "$MOCK_SSH_STDIN_LOG" ]
}

@test "Host refresh removes only the managed entry and exact key matches" {
    seed_existing_key
    export MOBILE_ID="notify.test"
    blob=$(awk '{ print $2 }' /config/.ssh/id_rsa.pub)
    prefix_admin="ssh-rsa ${blob}EXTRA admin@laptop"
    mkdir -p /root/.ssh
    printf '%s\n' \
        "$prefix_admin" \
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOTHERADMINKEY other@host" \
        "ssh-rsa ${blob} stale_copy" \
        'restrict,command="/root/.pi_firmware_updater/ssh_wrapper.sh" ssh-rsa AAAAOLDMANAGED old' \
        > /root/.ssh/authorized_keys

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    run bash -s < <(sed -n '/^set -e$/,$p' "$MOCK_SSH_STDIN_LOG")
    [ "$status" -eq 0 ]

    grep -qxF "$prefix_admin" /root/.ssh/authorized_keys
    grep -q 'other@host' /root/.ssh/authorized_keys
    ! grep -q 'stale_copy' /root/.ssh/authorized_keys
    ! grep -q 'AAAAOLDMANAGED' /root/.ssh/authorized_keys
    [ "$(grep -c 'ssh_wrapper.sh' /root/.ssh/authorized_keys)" -eq 1 ]
    [ "$(cat /root/.pi_firmware_updater/key.blob)" = "$blob" ]
}

@test "Wrapper uninstall keeps keys that only share a prefix with the managed blob" {
    WRAPPER=/config/custom_components/pi_firmware_updater/ssh_wrapper.sh
    blob="AAAAB3NzaC1yc2EAAAADAQABAAABAQC3MANAGEDKEY"
    mkdir -p /root/.ssh /root/.pi_firmware_updater
    printf '%s\n' "$blob" > /root/.pi_firmware_updater/key.blob
    printf '%s\n' \
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3ADMINKEY admin@laptop" \
        "restrict,command=\"/root/.pi_firmware_updater/ssh_wrapper.sh\" ssh-rsa ${blob} pi_firmware_updater" \
        "ssh-rsa ${blob} unmanaged_copy" \
        > /root/.ssh/authorized_keys

    run env SSH_ORIGINAL_COMMAND='pi_firmware_uninstall' bash "$WRAPPER"
    [ "$status" -eq 0 ]
    [ "$(cat /root/.ssh/authorized_keys)" = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3ADMINKEY admin@laptop" ]
    [ ! -d /root/.pi_firmware_updater ]
}

@test "Rejects public key blob with non-base64 characters" {
    touch /config/.ssh/id_rsa
    echo "ssh-rsa AAAAMOCKKEY'DATA$(printf 'Q%.0s' {1..60}) pi_firmware_updater" > /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid characters"* ]]
    [ ! -f "$MOCK_SSH_STDIN_LOG" ]
}

@test "Rejects unsupported public key type" {
    touch /config/.ssh/id_rsa
    echo "${EXISTING_KEY/ssh-rsa/ssh-dss}" > /config/.ssh/id_rsa.pub
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unsupported or malformed public key type"* ]]
    [ ! -f "$MOCK_SSH_STDIN_LOG" ]
}

@test "Pushes exactly one restricted authorized_keys entry built from validated fields" {
    seed_existing_key
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    run sed -n "/<<'AUTH'/,/^AUTH$/p" "$MOCK_SSH_STDIN_LOG"
    [ "$(printf '%s\n' "$output" | wc -l)" -eq 3 ]
    expected='restrict,from="127.0.0.1",command="/root/.pi_firmware_updater/ssh_wrapper.sh"'
    expected="$expected $EXISTING_KEY"
    [[ "$output" == *"$expected"* ]]
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
    [[ "$output" == *"password bootstrap"* ]]
    grep -q "identity=no" "$MOCK_SSH_LOG"
}

@test "Refreshes host auth via password bootstrap when key auth works" {
    seed_existing_key
    export MOBILE_ID="notify.test"

    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"password bootstrap"* ]]
    [[ "$output" == *"Authorization successful"* ]]
    grep -q "identity=yes cmd=exit" "$MOCK_SSH_LOG"
    grep -q "identity=no" "$MOCK_SSH_LOG"
    grep -q 'restrict,from="127.0.0.1"' "$MOCK_SSH_STDIN_LOG"
}

@test "Wrapper allowlists fixed ops and denies arbitrary commands" {
    WRAPPER=/config/custom_components/pi_firmware_updater/ssh_wrapper.sh
    chmod +x "$WRAPPER"

    run env SSH_ORIGINAL_COMMAND='rm -rf /' bash "$WRAPPER"
    [ "$status" -ne 0 ]
    [[ "$output" == *"command denied"* ]]

    run env SSH_ORIGINAL_COMMAND='pi_firmware_deploy_host_check' bash "$WRAPPER"
    [ "$status" -ne 0 ]
    [[ "$output" == *"command denied"* ]]

    run env SSH_ORIGINAL_COMMAND='exit' bash "$WRAPPER"
    [ "$status" -eq 0 ]

    run env SSH_ORIGINAL_COMMAND='' bash "$WRAPPER"
    [ "$status" -eq 0 ]

    mkdir -p /root/.pi_firmware_updater
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
