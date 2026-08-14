# Skills Index

Project skills live under `.github/skills/<name>/SKILL.md`.
Project law (always-on rules): root `AGENTS.md`.
Mode routing: `.agent/agents.md`.

## Available Skills

| Skill | Use when |
| --- | --- |
| `ha-firmware-fix-pass` | End-to-end lint / test / coverage repair; CI red; “fix checks” |
| `ha-yaml-integration-edits` | Sensors, shell commands, automations, scripts, action handlers |
| `host-check-update-safety` | `host_check.sh` feasibility, blocks, `--update`, reboot chaining |
| `install-uninstall-script-maintenance` | SSH setup, key auth, mobile ID injection, uninstall rollback |
| `bats-kcov-test-authoring` | New/updated Bats suites, mocks, kcov, 90% coverage bar |
| `release-doc-and-badge-update` | README/docs/releases sync and coverage badge refresh |
| `resolve-pr-comments` | Resolve GitHub PR review threads with verify → fix/skip → reply → resolve |
| `pipeline-runner` | Full local CI-parity pipeline (lint, Bats, kcov ≥ 90%, badge) with live logs |

## Trigger Hints

- Failing ShellCheck, YamlLint, Bats, or coverage → `ha-firmware-fix-pass`
- `update_blocked` / `blocked_reason` / SSD / NVMe / fail-closed →
  `host-check-update-safety`
- `sensor.pi_firmware_monitor` / `INSTALL_PI_FIRMWARE` / notify YAML →
  `ha-yaml-integration-edits`
- Port 22222 / RSA keys / `install.sh` / `uninstall.sh` →
  `install-uninstall-script-maintenance`
- `tests/unit|component|e2e` or badge regeneration → `bats-kcov-test-authoring`
  (badge+docs together → also `release-doc-and-badge-update`)
- PR review threads / “resolve comments” → `resolve-pr-comments`
- “run pipeline” / local CI parity → `pipeline-runner`

## Related Workflows

- `.agent/workflows/fix.md`
- `.agent/workflows/explore.md`
- `.agent/workflows/release.md`
