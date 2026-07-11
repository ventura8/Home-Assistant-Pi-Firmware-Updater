---
name: ha-yaml-integration-edits
description: "Safely edit Home Assistant YAML integration files in custom_components/pi_firmware_updater. Use for sensors, shell commands, automations, scripts, and action handlers while preserving entity names, service calls, and include wiring."
argument-hint: "Target YAML file and intended behavior change"
---

# Home Assistant YAML Integration Edits

## When to Use
- Modifying files in custom_components/pi_firmware_updater/*.yaml.
- Adding or changing automations, shell commands, or template sensors.
- Updating notification, action, or script behavior.

## Procedure
1. Locate related YAML files and follow existing naming conventions.
2. Preserve these integration contracts unless explicitly asked to migrate them:
   - Existing entity IDs and script names.
   - Existing action names like INSTALL_PI_FIRMWARE.
   - Existing include structure documented in README configuration snippet.
3. Validate data flow across files:
   - shell_commands.yaml command output.
   - command_line_sensors.yaml sensor parsing.
   - template_sensors.yaml transformed state/attributes.
   - update_notification.yaml and action_handler.yaml interaction path.
4. Keep state values concise to respect Home Assistant state length limits; move verbose details to attributes when needed.
5. Re-run tests and lint checks after changes.
6. If behavior changed for users, update README.md and relevant docs.

## Safety Notes
- Do not remove block-related attributes update_blocked or blocked_reason when touching monitor logic.
- Keep blocked update UX explicit in both dashboard and mobile action paths.
