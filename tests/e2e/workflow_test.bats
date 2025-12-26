#!/usr/bin/env bats

setup() {
    # Create temp config dir
    export CONFIG_DIR="$BATS_TMPDIR/config/custom_components/pi_firmware_updater"
    export SSH_DIR="$BATS_TMPDIR/config/.ssh"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SSH_DIR"

    # Create dummy yaml files
    echo "action: notify.REPLACE_WITH_YOUR_DEVICE_ID" > "$CONFIG_DIR/update_notification.yaml"
    echo "action: notify.REPLACE_WITH_YOUR_DEVICE_ID" > "$CONFIG_DIR/action_handler.yaml"
}

teardown() {
    rm -rf "$BATS_TMPDIR/config"
}

@test "E2E: Full Install and Uninstall Cycle" {
    # 1. Run Install
    # We mock git/ssh/apt calls just enough to pass, or rely on real file ops?
    # For E2E we usually want as much real as possible, but we are in a container/mock env.
    # We will assume 'ssh-keygen' works. 'ssh' to localhost needs mocking or real service.
    # Given the previous tests used mocks, we might need to mock ssh here too or rely on the container loopback?
    # The container has 'ssh' installed? 
    # Let's mock 'ssh' to always succeed to simulate successful connection.
    
    # Mock SSH for this test (local function override or path manipulation? BATS usually path manipulation)
    mkdir -p "$BATS_TMPDIR/bin"
    echo -e '#!/bin/bash\nexit 0' > "$BATS_TMPDIR/bin/ssh"
    chmod +x "$BATS_TMPDIR/bin/ssh"
    export PATH="$BATS_TMPDIR/bin:$PATH"

    # Run Install with input
    # We run the script directly so the main guard executes the function.
    # Env vars CONFIG_DIR and SSH_DIR are exported by setup() and inherited.
    run bash -c "custom_components/pi_firmware_updater/install.sh <<< 'notify.mobile_app_test'"
    
    [ "$status" -eq 0 ]
    [ -f "$SSH_DIR/id_rsa" ]
    
    # Verify file replacement
    grep "notify.mobile_app_test" "$CONFIG_DIR/update_notification.yaml"
    
    # 2. Run Uninstall
    run custom_components/pi_firmware_updater/uninstall.sh
    [ "$status" -eq 0 ]
    
    # Verify Removal
    [ ! -f "$SSH_DIR/id_rsa" ]
    grep "notify.REPLACE_WITH_YOUR_DEVICE_ID" "$CONFIG_DIR/update_notification.yaml"
}
