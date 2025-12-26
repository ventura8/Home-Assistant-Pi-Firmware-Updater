# HACS Integration Logic

## Secure SSH Communication
The project uses RSA key pairs to allow the Home Assistant container to communicate with the Raspberry Pi Host OS on Port 22222.

### `install.sh` Logic
1. Checks for the existence of `ha_pi_updater_rsa`.
2. Generates keys if missing.
3. Attempts to copy the public key to the Host OS (Port 22222).
4. Verifies the connection.
5. Injects the Mobile Notification ID into the YAML files.

### 255-Character Bypass
Home Assistant sensors have a 255-character limit for their state. The scripts use string truncation and optimized formatting to ensure that version information and update statuses fit within this limit, while providing detailed information in attributes.

## Update Mechanism
Updates are performed by running `rpi-eeprom-update -a` on the Host OS via SSH. The `apply_pi_firmware_update_script.yaml` handles the command execution and subsequent system reboot.
