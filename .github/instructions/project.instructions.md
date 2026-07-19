---
title: Home Assistant Pi Firmware Updater Workspace Instructions
description: Project-level Copilot instructions for strict quality gates, safety-critical firmware logic, and testing workflows.
---

## Workspace Instructions

Use this repository as a safety-first Home Assistant integration for Raspberry Pi firmware checks and updates.

## Mandatory Quality Gates

- Run the full quality gate with `./tests/run_tests.sh lint`.
- Keep maximum line length at 140 for all non-Markdown sources and configs.
- Do not use lint suppressions, disables, or ignores to pass checks.
- Keep CI and local workflows aligned; update both together.

## Mandatory Test and Coverage Gates

- Run tests through `./scripts/run_local_tests.ps1` for local parity with CI workflows.
- Maintain at least 90% total coverage.
- Regenerate coverage outputs when behavior changes.

## Agent Routing

- For one-pass lint+test repair: use `.github/skills/ha-firmware-fix-pass/SKILL.md`.
- For Home Assistant YAML edits: use `.github/skills/ha-yaml-integration-edits/SKILL.md`.
- For host update safety logic: use `.github/skills/host-check-update-safety/SKILL.md`.
- For installer or uninstaller changes: use `.github/skills/install-uninstall-script-maintenance/SKILL.md`.
- For Bats and coverage work: use `.github/skills/bats-kcov-test-authoring/SKILL.md`.
- For release docs and badge updates: use `.github/skills/release-doc-and-badge-update/SKILL.md`.

## Related Agent Files

- `.github/agents/project.agent.md`
- `.github/prompts/project.prompt.md`
- `AGENTS.md`
- `.agent/agents.md`
- `.github/copilot-instructions.md`
- `.github/skills/README.md`
