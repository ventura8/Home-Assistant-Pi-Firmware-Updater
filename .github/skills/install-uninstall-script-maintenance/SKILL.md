---
name: install-uninstall-script-maintenance
description: "Maintain install.sh and uninstall.sh for secure SSH setup and rollback. Use when changing key generation, host authorization flow, mobile_app notification ID injection, or cleanup semantics."
argument-hint: "Installer or uninstaller change scope"
---

# Install and Uninstall Script Maintenance

## When to Use
- Changing custom_components/pi_firmware_updater/install.sh or uninstall.sh.
- Modifying SSH key handling, first-time setup flow, or rollback behavior.
- Adjusting how notification IDs are injected into YAML files.

## Procedure
1. Keep setup idempotent:
   - Re-running install should not duplicate keys or corrupt YAML.
   - Re-running uninstall should be safe when artifacts are already absent.
2. Keep secure defaults:
   - Use RSA key pair flow already expected by integration.
   - Avoid introducing password persistence in files.
3. Validate mobile notification ID injection:
   - Detect expected notify.mobile_app_* format.
   - Only mutate intended YAML placeholders.
4. Preserve clear terminal guidance for Home Assistant add-on setup and prerequisites.
5. Ensure uninstall reverses only integration-created state and does not delete unrelated user content.
6. Run component tests that validate installer and uninstaller behavior.

## Review Focus
- No destructive file edits outside integration-owned files.
- Good error messages for missing prerequisites.
- Script exit codes reflect real success/failure state.
