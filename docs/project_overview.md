# Project Overview & Directory Structure

## Goals
The primary goal of this project is to provide a safe, automated, and user-friendly way to update Raspberry Pi firmware from Home Assistant. It bridges the gap between the Home Assistant container and the Raspberry Pi Host OS using secure SSH communication.

## Directory Structure

- `custom_components/pi_firmware_updater/`: Core integration files.
  - `install.sh`: Setup script for SSH keys and configuration.
  - `uninstall.sh`: Cleanup script.
  - `command_line_sensors.yaml`: Sensor definitions.
  - `shell_commands.yaml`: Action definitions.
- `tests/`: Automated test suite.
  - `unit/`: Bash unit tests using Bats.
  - `component/`: Integration tests.
  - `e2e/`: End-to-end simulation tests.
  - `transform_coverage.py`: Post-processing script for coverage and badges.
- `assets/`: UI assets and the coverage badge.
- `.github/workflows/`: CI/CD pipelines.
