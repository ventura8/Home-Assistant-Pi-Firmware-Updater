---
title: Agent Modes Registry
description: Mode-level guide for how agents should route tasks in this repository.
---

## Agent Modes

Project law: root `AGENTS.md`. Skills index: `.github/skills/README.md`.

Pick a mode from the user request, then follow the linked workflow and/or skill.
Do not skip safety or quality gates listed in `AGENTS.md`.

## Explore Mode

Use for architecture discovery, file tracing, and impact analysis.

- Workflow: `.agent/workflows/explore.md`
- Read first: `AGENTS.md`, `docs/project_overview.md`, `docs/integration_logic.md`
- Trace shell ↔ YAML ↔ tests ↔ docs before proposing edits
- Prefer read-only exploration until the user asks for implementation

## Fix Mode

Use for failing lint, tests, CI, or coverage.

- Workflow: `.agent/workflows/fix.md`
- Skill: `.github/skills/ha-firmware-fix-pass/SKILL.md`
- Also for green validation: `.github/skills/pipeline-runner/SKILL.md`
- Order: lint → tests → coverage ≥ 90% → badge if needed
- Never loosen fail-closed firmware rules to green checks

## YAML Integration Mode

Use for Home Assistant YAML under `custom_components/pi_firmware_updater/`.

- Skill: `.github/skills/ha-yaml-integration-edits/SKILL.md`
- Preserve entity/service/action contracts and blocked UX paths

## Host Safety Mode

Use for `host_check.sh` feasibility, blocking, and `--update` execution.

- Skill: `.github/skills/host-check-update-safety/SKILL.md`
- Preserve two-path feasibility, fail-closed update, and `&&` reboot chaining

## Installer Maintenance Mode

Use for `install.sh` / `uninstall.sh` SSH setup and rollback.

- Skill: `.github/skills/install-uninstall-script-maintenance/SKILL.md`
- Keep port 22222 RSA flow, idempotency, and non-destructive uninstall

## Test Authoring Mode

Use for Bats suites, mocks, kcov, and coverage threshold work.

- Skill: `.github/skills/bats-kcov-test-authoring/SKILL.md`
- Cover blocked and unblocked safety paths; keep mocks cross-platform

## Release Mode

Use for docs, release notes, and coverage badge synchronization.

- Workflow: `.agent/workflows/release.md`
- Skill: `.github/skills/release-doc-and-badge-update/SKILL.md`
- Keep README/docs/agent files aligned with implementation

## PR Comments Mode

Use when resolving GitHub PR review threads.

- Skill: `.github/skills/resolve-pr-comments/SKILL.md`
- Verify each comment, fix or skip with a reply, then resolve (except Blocked)
