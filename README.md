# **🚀 Raspberry Pi Firmware Updater for Home Assistant**

This project provides a robust, professional-grade solution for monitoring and updating Raspberry Pi Bootloader (EEPROM) firmware directly from Home Assistant. It features actionable mobile notifications, persistent dashboard alerts, and a bypass for the Home Assistant 255-character sensor state limit.

## **✨ Features**

* **Real-time Monitoring:** Tracks `CURRENT` and `LATEST` bootloader versions.  
* **Actionable Notifications:** "Install & Reboot" directly from your smartphone.  
* **Persistent Alerts:** Integrated "Bell" notifications on the Home Assistant dashboard.  
* **255-Character Bypass:** Uses optimized SSH piping and string truncation to prevent sensor failure.  
* **Zero-Password Security:** Uses RSA key pairs for secure hardware communication.

## **📋 Prerequisites**

* \[ \] **Hardware:** Raspberry Pi 4 or 5\.  
* \[ \] **Software:** Home Assistant OS (HAOS) installed (Tested on **HAOS 2025.12.4**).  
* \[ \] **Add-ons:**  
  1. **Advanced SSH & Web Terminal** (Community Add-ons) \- Required for setup commands.  
  2. **HassOS SSH Port Configurator** \- Required to open Port 22222 on the host.  
* \[ \] **Mobile App (Optional):** Home Assistant Companion app on your mobile device.

## **🛠️ Step 0: Install the Terminal Add-on**

Before you begin the SSH configuration, you need a way to enter commands into your Home Assistant instance.

1. Go to **Settings** \> **Add-ons** \> **Add-on Store**.  
2. Search for **Advanced SSH & Web Terminal**.  
3. Install the add-on.  
4. In the **Configuration** tab, you must set a `password` or an `authorized_keys` string.  
5. In the **Info** tab, toggle **Show in sidebar** for easy access.  
6. Start the add-on.

## **🛠️ Step 1: Enable Host Access (Port 22222\)**

Standard SSH add-ons in HAOS are sandboxed and cannot access the firmware. You must enable "Host Access" on Port 22222\.

1. Install the [**HassOS SSH port 22222 Configurator**](https://github.com/adamoutler/HassOSConfigurator) add-on.  
2. In the add-on configuration, set a password or paste a public key.  
3. Start the add-on. This will open Port 22222 on the physical hardware.  
4. **Verification:** Open the terminal you installed in Step 0 and verify access:

```bash
ssh -p 22222 root@127.0.0.1
```

If you see the HassOS CLI welcome screen, you have successfully bridged to the hardware.

## **🔑 Step 2: Generate SSH Key & Set Permissions**

To allow Home Assistant's internal engine to talk to the hardware without a password prompt, we must generate keys and set the correct Linux permissions.

1. Open the Home Assistant Terminal and run:
```bash
mkdir -p /config/.ssh  
ssh-keygen -t rsa -f /config/.ssh/id_rsa -N ""
```

2. **Set Permissions:** SSH requires strict permissions to work. Run these commands to ensure the keys are secure:

```bash
# Secure the directory (Read/Write/Execute for owner only)  
chmod 700 /config/.ssh

# Secure the private key (Read/Write for owner only)  
chmod 600 /config/.ssh/id_rsa

# Secure the public key (Read/Write for owner, Read for others)  
chmod 644 /config/.ssh/id_rsa.pub
```

3. Authorize the key on the host hardware:

```bash
cat /config/.ssh/id_rsa.pub >> /config/.ssh/authorized_keys
```

4. **Connection Test:** Ensure this returns the firmware status without asking for a password:

```bash
ssh -p 22222 -i /config/.ssh/id_rsa -o StrictHostKeyChecking=no root@127.0.0.1 'rpi-eeprom-update'
```

## **📂 Step 3: File Configuration**

Add the following files to your `/config/` directory.

### **1\. `configuration.yaml`**

Link the files together using the specific filenames:  

```yaml
shell_command: !include custom_components/pi_firmware_monitor/shell_commands.yaml
command_line: !include custom_components/pi_firmware_monitor/command_line_sensors.yaml
template: !include custom_components/pi_firmware_monitor/template_sensors.yaml
automation:
  - !include custom_components/pi_firmware_monitor/update_notification.yaml
  - !include custom_components/pi_firmware_monitor/action_handler.yaml
script: !include custom_components/pi_firmware_monitor/apply_pi_firmware_update_script.yaml
```

### **2\. `shell_commands.yaml`**

```yaml
# Grabs only relevant lines to stay under 255-character sensor limit  
update_pi_firmware_data: "ssh -p 22222 -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa root@127.0.0.1 'rpi-eeprom-update' | head -n 5 | tr '\n' ' '"

# Applies the firmware update and reboots the system  
apply_pi_firmware_update: "ssh -p 22222 -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa root@127.0.0.1 'rpi-eeprom-update -a && reboot'"
```

### **3\. `command_line_sensors.yaml`**

```yaml
- sensor:  
    name: "Pi Firmware Raw"  
    unique_id: pi_firmware_raw  
    command: "ssh -p 22222 -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa root@127.0.0.1 'rpi-eeprom-update' | head -n 5 | tr '\n' ' '"  
    value_template: "{{ value }}"  
    scan_interval: 86400
```

### **4\. `template_sensors.yaml`**

```yaml
- sensor:  
    - name: "Pi Firmware Monitor"  
      unique_id: pi_firmware_monitor  
      icon: mdi:raspberry-pi  
      state: \>  
        {% set raw = states('sensor.pi_firmware_raw') %}  
        {% if 'update available' in raw.lower() %} Update Available  
        {% elif 'up to date' in raw.lower() %} Up to Date  
        {% else %} Checking... {% endif %}  
      attributes:  
        current_version: >  
          {% set raw = states('sensor.pi_firmware_raw') %}  
          {{ raw.split('CURRENT:')[1].split('LATEST:')[0].strip() if 'CURRENT:' in raw else 'Not Found' }}  
        latest_version: >  
          {% set raw = states('sensor.pi_firmware_raw') %}  
          {{ raw.split('LATEST:')[1].split('RELEASE:')[0].strip() if 'LATEST:' in raw else 'Not Found' }}
```

## **📱 Step 4: Find Your Mobile Device ID**

Actionable notifications need your specific device ID.

1. Go to **Developer Tools** \> **Actions**.  
2. Search for `notify.mobile_app_`.  
3. Note your device ID (e.g., `notify.mobile_app_pixel_9_pro`).  
4. Replace `REPLACE_WITH_YOUR_DEVICE_ID` in `update_notification.yaml` and `action_handler.yaml` with this ID.

## **🤖 Step 5: Automations**

### **1\. Notification Automation (`update_notification.yaml`)**

Triggers when a version mismatch is detected.

```yaml
- alias: "Pi Firmware: Notify Mobile"  
  id: pi_firmware_notify_mobile  
  trigger:  
    - platform: state  
      entity_id: sensor.pi_firmware_monitor  
      to: "Update Available"  
  action:  
    - action: notify.REPLACE_WITH_YOUR_DEVICE_ID  
      data:  
        title: "🚀 Pi Firmware Update Available"  
        message: "A new Pi Firmware Update is ready.\n\n**Installed:** {{ state_attr('sensor.pi_firmware_monitor', 'current_version') }}\n**Latest:** {{ state_attr('sensor.pi_firmware_monitor', 'latest_version') }}"  
        data:  
          tag: "pi_update"  
          actions:  
            - action: "INSTALL_PI_FIRMWARE"  
              title: "Install & Reboot"  
              destructive: true  
    - action: persistent_notification.create  
      data:  
        title: "🚀 Pi Firmware Update"  
        message: "A new Pi Firmware Update is ready.\n\n**Installed:** {{ state_attr('sensor.pi_firmware_monitor', 'current_version') }}\n**Latest:** {{ state_attr('sensor.pi_firmware_monitor', 'latest_version') }}" \n\n [Install & Reboot](/config/script/edit/apply_pi_firmware_update_script)"  
        notification_id: "pi_firmware_alert"
```

### **2\. Action Handler (`action_handler.yaml`)**

Responds to the "Install & Reboot" button on your phone.

```yaml
- alias: "Pi Firmware: Action Handler"  
  id: pi_firmware_action_handler  
  trigger:  
    - platform: event  
      event_type: mobile_app_notification_action  
      event_data:  
        action: "INSTALL_PI_FIRMWARE"  
  action:  
    - action: shell_command.apply_pi_firmware_update  
    - action: persistent_notification.dismiss  
      data:  
        notification_id: "pi_firmware_alert"  
    - action: notify.REPLACE_WITH_YOUR_DEVICE_ID  
      data:  
        message: "Update triggered. The system will reboot shortly."
```

> [!WARNING]
> Flashing EEPROM carries inherent risks. Always ensure your system is backed up. This project is provided "as-is" without warranty.
