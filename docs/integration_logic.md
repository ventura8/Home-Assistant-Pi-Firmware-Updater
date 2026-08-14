# HACS Integration Logic

## Secure SSH Communication

The project uses RSA key pairs to allow the Home Assistant container to communicate with the Raspberry Pi Host OS on Port 22222.

Private key path: `/config/.ssh/id_rsa` (passphrase-less for unattended `shell_command` use). This path is inside the Home Assistant config directory and is included in HA full backups by default—treat backups as sensitive.

### `install.sh` Logic

1. Checks for `/config/.ssh/id_rsa` (regenerates `.pub` via `ssh-keygen -y` if
   the private key exists alone; aborts if recovery fails).
2. Generates an RSA key pair if missing (`ssh-keygen` comment `pi_firmware_updater`).
3. Deploys host copies of `host_check.sh` and `ssh_wrapper.sh` under
   `/root/.pi_firmware_updater/`, stores the key blob, and upserts a restricted
   `authorized_keys` line:
   `restrict,from="127.0.0.1",command="/root/.pi_firmware_updater/ssh_wrapper.sh" ...`
4. Managed auth-line removal matches **key blob + wrapper path** (never
   comment-only deletes).
5. Wrapper allowlists fixed ops only (`pi_firmware_check`, `pi_firmware_update`,
   `pi_firmware_uninstall`, `exit`) and never executes caller stdin as a shell
   program. Deploy/upload ops are **not** allowlisted — install/refresh uses the
   password bootstrap channel on port 22222.
6. Re-running install refreshes host scripts and `authorized_keys` via password
   bootstrap. Public keys are validated (non-empty typed blob) before any remote
   mutation.
7. Injects the Mobile Notification ID into the YAML files.

### `uninstall.sh` Logic

1. Attempts host cleanup via `pi_firmware_uninstall` when the local private key
   exists; if the key is missing or that call fails, attempts password-bootstrap
   cleanup (SSH without `-i`). If both fail, prints manual remediation steps
   and records incomplete cleanup.
2. Deletes local `/config/.ssh/id_rsa` and `id_rsa.pub` when present.
3. Reverts mobile notification placeholders in the YAML files.
4. Exits non-zero when host cleanup was incomplete; remains safe to re-run.

### HA remote commands

`shell_commands.yaml` / `command_line_sensors.yaml` invoke fixed host commands
`pi_firmware_check` and `pi_firmware_update` (no stdin pipe of scripts).

### 255-Character Bypass

Home Assistant sensors have a 255-character limit for their state. The scripts use string truncation and optimized formatting to ensure that version information and update statuses fit within this limit, while providing detailed information in attributes.

## Update Mechanism & Safety Blocking

Updates are performed safely by running the host-installed `host_check.sh` via
the fixed SSH forced-command `pi_firmware_update`. The
`apply_pi_firmware_update_script.yaml` handles validation, command execution,
and reboots.

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
