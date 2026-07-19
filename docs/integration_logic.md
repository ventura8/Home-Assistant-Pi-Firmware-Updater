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

## Update Mechanism & Safety Blocking

Updates are performed safely by running `host_check.sh` on the Host OS via SSH stdin redirection. The `apply_pi_firmware_update_script.yaml` handles validation, command execution, and reboots.

### Feasibility Checks

Before any upgrade check or execution, the utility validates feasibility:

1. **HA OS Agent Support**: If the `ha` CLI command is available, it queries status from the supervisor api (`ha os boards raspberrypi firmware`). It honors the supervisor's block status (`update_blocked: true`).
2. **Raspberry Pi 3/4 Family SSD Boot Block**: If `ha` is not present, it performs fallback checks. If the model is a Raspberry Pi 3/4 family variant (including CM3/CM4, CM4S, and Pi 400) recognized by `check_ssd_boot`, and the system is booted from a non-mmcblk/loop/overlay device (where the boot device node contains `nvme` or `sd`, or any other unrecognized device class), the update is marked as blocked (reporting `unsupported_boot_device_nvme`, `unsupported_boot_device_ssd`, or `unsupported_boot_device` accordingly).
3. **Execution Block**: When running in update mode (`--update`), the script validates the feasibility block status. If feasibility checks indicate the update is blocked, or if the `ha` CLI status query or response parsing fails, the update fails closed: the script prints an error and aborts with exit status `1` before applying any update.
4. **Official Update Path**: If allowed, the script runs the update and reboot command chain (`ha os boards raspberrypi firmware update && ha host reboot` if `ha` is present, or `rpi-eeprom-update -a && reboot` if not) detached in the background using `nohup bash -c`. This ensures the reboot is guarded by the `&&` chain (it only triggers if the update command succeeds) while returning immediately to avoid timing out Home Assistant's 60-second shell command limit. Outputs and the exit status of the update command are written to `/var/log/pi_firmware_update.log` for troubleshooting.

### Home Assistant User Interface Integration

- **`sensor.pi_firmware_monitor`**: Exposes the block status as state `Upgrade Blocked` and populates attributes `update_blocked` and `blocked_reason` dynamically.
- **Alert Notifications**: The script `apply_pi_firmware_update_script.yaml` checks the sensor state. If blocked, it skips calling the update command and displays a persistent dashboard notification detailing the block reason.
- **Mobile Action Guarding**: If the mobile notification action `INSTALL_PI_FIRMWARE` is triggered while in blocked state, the action handler notifies the user's phone that the update has been blocked instead of sending a standard command confirmation message.
