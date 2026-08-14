---
name: ha-yaml-integration-edits
description: "Safely edit Home Assistant YAML integration files in custom_components/pi_firmware_updater. Use for sensors, shell commands, automations, scripts, and action handlers while preserving entity names, service calls, and include wiring."
argument-hint: "Target YAML file and intended behavior change"
---

# Home Assistant YAML Integration Edits

Playbook for YAML under `custom_components/pi_firmware_updater/`. Project law:
`AGENTS.md`. Logic overview: `docs/integration_logic.md`.

## When to Use

- Modifying `custom_components/pi_firmware_updater/*.yaml`
- Adding or changing automations, shell commands, or template sensors
- Updating notification, action, or script behavior

## Hard Rules

- Preserve entity IDs, script names, and `INSTALL_PI_FIRMWARE` unless explicitly
  migrating
- Keep `update_blocked` and `blocked_reason` attributes available to UX paths
- Keep blocked update UX explicit on dashboard and mobile paths
- Respect 255-character state limits; put verbose detail in attributes
- Validate data flow across the file graph in the same change set
- Run lint + tests after YAML edits

## File Graph

Trace changes through related files:

```text
host_check.sh (host)
    │ SSH stdin / monitor output
    ▼
shell_commands.yaml ──────────► apply_pi_firmware_update_script.yaml
    │
    ▼
command_line_sensors.yaml ──► template_sensors.yaml ──► sensor.pi_firmware_monitor
                                      │
                                      ├─► update_notification.yaml
                                      └─► action_handler.yaml (INSTALL_PI_FIRMWARE)
```

| File | Role |
| --- | --- |
| `command_line_sensors.yaml` | SSH monitor command; raw host summary |
| `template_sensors.yaml` | Transforms state/attributes for UI |
| `shell_commands.yaml` | Host check / update shell entrypoints |
| `update_notification.yaml` | Alert when update available; mobile action |
| `action_handler.yaml` | Handles `INSTALL_PI_FIRMWARE`; blocked branch |
| `apply_pi_firmware_update_script.yaml` | Guarded apply + persistent notifications |

## Stable Contracts

Do not rename without migration + docs + tests:

- `sensor.pi_firmware_monitor`
- States used by automations: at least `Upgrade Blocked`, `Update Available`
- Action `INSTALL_PI_FIRMWARE`
- Notify placeholders (`notify.REPLACE_WITH_YOUR_DEVICE_ID` /
  `notify.mobile_app_*` after install injection)
- Include structure shown in README configuration snippets

## Procedure

1. Locate related YAML files and follow existing naming / alias conventions
2. Edit the smallest set of files that keeps the graph consistent
3. Validate:
   - Shell command output still matches sensor parsing expectations
   - Template attributes still expose versions and block fields
   - Notification and action handler still branch on blocked vs available
   - Apply script still skips update when blocked and surfaces reason
4. Keep state strings concise (255-char limit); move detail to attributes
5. Run `./tests/run_tests.sh lint` (includes YamlLint) and local tests
6. Confirm total coverage ≥ 90%; refresh `assets/coverage.svg` when coverage
   changes
7. Update README/docs when user-visible behavior changes
8. Update agent docs if contracts or UX invariants change

## Regression Checklist

- [ ] Blocked dashboard notification still shows `blocked_reason`
- [ ] Mobile `INSTALL_PI_FIRMWARE` while blocked notifies block, does not pretend
      success
- [ ] Available path still calls `shell_command.apply_pi_firmware_update` (or
      current equivalent) with failure messaging intact
- [ ] SSH still targets port 22222 with the expected key path unless migrating
- [ ] Installer ID injection still matches placeholders you rely on
- [ ] Coverage ≥ 90%; `assets/coverage.svg` refreshed when coverage changed

## Do / Don’t

### Do

- Keep choose/default branches for blocked, available, and fallback states
- Prefer attribute templates for long text
- Coordinate with `host-check-update-safety` when parsing host output changes

### Don't

- Remove block attributes to simplify templates
- Hard-code a single user’s `notify.mobile_app_*` in committed defaults
- Break include wiring silently
- Skip YamlLint failures with disables
