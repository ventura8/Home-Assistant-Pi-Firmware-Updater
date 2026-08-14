---
title: Home Assistant YAML Instructions
description: File-scoped rules for pi_firmware_updater YAML integration files.
applyTo: "custom_components/pi_firmware_updater/**/*.yaml"
---

## HA YAML Scope

Follow root `AGENTS.md` and
`.github/skills/ha-yaml-integration-edits/SKILL.md`.

## Rules

- Preserve `sensor.pi_firmware_monitor`, `INSTALL_PI_FIRMWARE`, and include
  wiring unless explicitly migrating
- Keep `update_blocked` and `blocked_reason` available to UI paths
- Keep blocked UX explicit in `update_notification.yaml`,
  `action_handler.yaml`, and `apply_pi_firmware_update_script.yaml`
- Respect 255-character state limits; use attributes for verbose detail
- Trace shell_commands ↔ sensors ↔ templates ↔ notifications ↔ action handler
  ↔ apply script when changing data flow
- Do not commit a personal `notify.mobile_app_*` as the default; keep
  placeholders for `install.sh` injection
- Pass YamlLint; no rule disables

## Verify

1. `./tests/run_tests.sh lint`
2. Relevant component/e2e tests via `./scripts/run_local_tests.ps1`
3. Confirm total coverage ≥ 90%; refresh `assets/coverage.svg` when coverage
   changes
4. Update README/docs when user-visible behavior changes
