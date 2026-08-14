---
title: Home Assistant Pi Firmware Updater Workspace Instructions
description: Project-level Copilot instructions for strict quality gates, safety-critical firmware logic, and testing workflows.
---

## Workspace Instructions

Safety-first Home Assistant integration for Raspberry Pi EEPROM firmware monitor
and update. Full always-on law: root `AGENTS.md`. Do not conflict with it.

## Mandatory Quality Gates

- Run `./tests/run_tests.sh lint` before behavioral test fixes
- Max line length 140 for non-Markdown; Markdown line-length not enforced
- Max cyclomatic complexity 10 on product shell functions
- No lint suppressions, disables, or ignores
- Autofix first, then hand-fix remaining issues
- Keep CI and local scripts aligned

## Mandatory Test and Coverage Gates

- Full local parity: `./scripts/run_local_tests.ps1`
- Coverage ≥ 90%; regenerate `assets/coverage.svg` locally when coverage changes
- Keep fixing until lint, tests, and coverage are green
- Never loosen fail-closed firmware safety to pass tests

## Safety and Contracts (summary)

- Two-path feasibility (HA CLI preferred, local fallback)
- Fail-closed `--update`; update+reboot chained with `&&`
- Preserve `sensor.pi_firmware_monitor`, `INSTALL_PI_FIRMWARE`,
  `update_blocked`, `blocked_reason`
- SSH host access on port 22222 with RSA keys
- Update agent docs in the same change set when rules/behavior change

## Agent Routing

| Need | Entry |
| --- | --- |
| One-pass lint+test repair | `.github/skills/ha-firmware-fix-pass/SKILL.md` |
| HA YAML edits | `.github/skills/ha-yaml-integration-edits/SKILL.md` |
| Host update safety | `.github/skills/host-check-update-safety/SKILL.md` |
| Installer / uninstaller | `.github/skills/install-uninstall-script-maintenance/SKILL.md` |
| Bats / kcov | `.github/skills/bats-kcov-test-authoring/SKILL.md` |
| Release docs / badge | `.github/skills/release-doc-and-badge-update/SKILL.md` |
| Modes / workflows | `.agent/agents.md`, `.agent/workflows/` |

## Related Agent Files

- `AGENTS.md`
- `.github/agents/project.agent.md`
- `.github/prompts/project.prompt.md`
- `.github/copilot-instructions.md`
- `.github/instructions/shell.instructions.md`
- `.github/instructions/ha-yaml.instructions.md`
- `.github/skills/README.md`
