#!/usr/bin/env bats

setup() {
    export CONFIG_DIR="$BATS_TMPDIR/config/custom_components/pi_firmware_updater"
    mkdir -p "$CONFIG_DIR"
    
    # Source the script but don't run main
    # We need to make sure we don't accidentally trample real files if sourcing went wrong
    # The script uses absolute paths /config/.ssh
    # We MUST define /config to be safe or redefine mkdir?
    # The script acts on /config. In a Docker container this is fine.
    # Locally we must be careful.
    # The script uses /config hardcoded. We should probably make that configurable or mock mkdir.
    # For unit tests, we can mock mkdir.
    
    mkdir -p "$BATS_TMPDIR/bin"
    export PATH="$BATS_TMPDIR/bin:$PATH"
}

@test "Unit: Install script defines functions" {
    source custom_components/pi_firmware_updater/install.sh
    # Check if main is defined
    run type -t main
    [ "$output" = "function" ]
}
