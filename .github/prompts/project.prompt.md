# Prompt Defaults

When working in this repository, follow root `AGENTS.md`.

## Global Defaults

1. Start from strict quality compliance
2. Keep max 140 characters for non-Markdown files
3. Avoid lint suppressions and rule disables
4. Keep update logic fail-closed
5. Run lint checks before test fixes
6. Preserve Home Assistant integration contracts
7. Keep fixing until lint, tests, and coverage ≥ 90% are green
8. Update agent docs when invariants or workflows change

## Prompt Library

### Fix pass

Run a single smart fix pass: lint via `./tests/run_tests.sh lint`, then full
local tests via `./scripts/run_local_tests.ps1`, enforce ≥ 90% coverage and badge
update, and do not loosen firmware safety. Follow
`.github/skills/ha-firmware-fix-pass/SKILL.md` and `.agent/workflows/fix.md`.

### Host-safety review

Review or change `host_check.sh` feasibility and `--update` paths. Preserve
two-path HA CLI / fallback model, Pi 3/4 SSD/NVMe blocks, fail-closed aborts,
`&&` reboot chaining, and parseable monitor output. Follow
`.github/skills/host-check-update-safety/SKILL.md`.

### YAML change

Edit Home Assistant YAML under `custom_components/pi_firmware_updater/` while
preserving `sensor.pi_firmware_monitor`, `INSTALL_PI_FIRMWARE`, block
attributes, and blocked UX on dashboard and mobile paths. Follow
`.github/skills/ha-yaml-integration-edits/SKILL.md`.

### Release prep

Synchronize README, `docs/`, release notes, coverage badge, and agent guidance
with implementation. Follow `.agent/workflows/release.md` and
`.github/skills/release-doc-and-badge-update/SKILL.md`.
