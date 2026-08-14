# Project Overview & Directory Structure

## Goals

The primary goal of this project is to provide a safe, automated, and user-friendly way to update Raspberry Pi firmware from Home Assistant. It bridges the gap between the Home Assistant container and the Raspberry Pi Host OS using restricted SSH communication on port 22222 (`from="127.0.0.1"` plus a forced-command wrapper allowlisting only the integration host-check flows).

## Directory Structure

- `custom_components/pi_firmware_updater/`: Core integration files.
  - `install.sh`: Setup script for restricted SSH keys/wrapper and configuration.
  - `uninstall.sh`: Cleanup script (host auth + local keys).
  - `ssh_wrapper.sh`: Host forced-command allowlist (deployed to the Host OS).
  - `manifest.json`: HACS/integration metadata (includes release `version`).
  - `host_check.sh`: Shell script for host-side block detection and update execution.
  - `command_line_sensors.yaml`: Sensor definitions.
  - `template_sensors.yaml`: Template sensor definitions.
  - `shell_commands.yaml`: Action definitions.
  - `update_notification.yaml`: Update alert automation.
  - `action_handler.yaml`: Mobile action handler automation.
  - `apply_pi_firmware_update_script.yaml`: Safe update execution script.
- `tests/`: Automated test suite.
  - `unit/`: Bash unit tests using Bats (includes `host_check_test.bats`).
  - `component/`: Integration tests.
  - `e2e/`: End-to-end simulation tests.
  - `transform_coverage.py`: Post-processing script for coverage and badges.
- `assets/`: UI assets and the coverage badge.
- `.github/workflows/`: CI/CD pipelines.
