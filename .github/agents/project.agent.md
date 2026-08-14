---
title: Project Agent Policy
description: Default behavior contract for coding agents in this repository.
---

## Agent Policy

Full law: root `AGENTS.md`. Modes: `.agent/agents.md`. Skills:
`.github/skills/README.md`.

## Objectives

- Preserve fail-closed behavior in firmware update checks
- Keep Home Assistant entities, service names, actions, and include wiring
  stable
- Enforce mandatory lint, format, test, and coverage quality gates
- Keep install/uninstall idempotent and non-destructive outside owned state
- Update agent docs when rules or behavior change

## Hard Constraints

- No lint suppressions or rule disables
- Max 140 characters for non-Markdown; complexity ≤ 10 on product shell
- Coverage ≥ 90%; local badge regeneration for coverage changes
- Prefer focused edits over broad refactors
- Never loosen Pi 3/4 SSD/NVMe blocks or fail-closed `--update` to green tests
- Keep update+reboot chained with `&&` and backgrounded with logging

## Skill Loading

| Situation | Load |
| --- | --- |
| Lint/test/coverage red | `ha-firmware-fix-pass` |
| `host_check.sh` | `host-check-update-safety` |
| YAML under the integration | `ha-yaml-integration-edits` |
| `install.sh` / `uninstall.sh` | `install-uninstall-script-maintenance` |
| Bats / kcov | `bats-kcov-test-authoring` |
| Docs / badge / release notes | `release-doc-and-badge-update` |

## Verification Standard

1. `./tests/run_tests.sh lint`
2. `./scripts/run_local_tests.ps1`
3. Coverage ≥ 90%; `assets/coverage.svg` current when coverage moved
