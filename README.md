# 🚀 Home Assistant Pi Firmware Monitor

A robust Home Assistant integration for monitoring and updating Raspberry Pi Bootloader (EEPROM) firmware. 

This project bypasses the standard 255-character sensor limit by using a direct SSH-to-Command-Line bridge, providing real-time version tracking and one-tap updates from your mobile device.

## ✨ Features
* **Live Monitoring:** Tracks `CURRENT` and `LATEST` firmware versions.
* **Smart Parsing:** Simplified text-splitting logic to avoid Regex failures.
* **Persistent Notifications:** Integrated dashboard alerts with action links.
* **Mobile Actionable Notifications:** Update your Pi firmware directly from your phone.
* **Security Focused:** Uses SSH-key authentication (no passwords in config).

## 🛠️ Hardware Requirements
- **Host:** Raspberry Pi (Running HAOS or Debian-based Pi OS).
- **SSH Access:** SSH must be configured for the host system (Port 22222 for HAOS users).

## 📂 Repository Contents
- `sensors.yaml`: The Command Line and Template sensors.
- `shell_commands.yaml`: The SSH bridge commands.
- `automations.yaml`: Both the notification and the update-handler logic.
- `scripts.yaml`: The helper script for dashboard interaction.

## 🛠️ Installation

### 1. Prerequisites
* Raspberry Pi running HAOS or Debian.
* SSH access enabled (Port 22222 for HAOS).
* Generated SSH keys in `/config/.ssh/`.

### 2. Add to `configuration.yaml`
Copy the contents of `sensor.yaml` and `shell_commands.yaml` (provided in this repo) into your Home Assistant configuration.

### 3. Automations
Import the `firmware_notification.yaml` to enable the Pixel/Mobile app alerts.

## 📱 Mobile Preview
The notification includes the exact version strings and a destructive "Install & Reboot" button.

---
*Disclaimer: Use the "Install & Reboot" feature with caution. Always ensure your system is backed up before flashing EEPROM.*
