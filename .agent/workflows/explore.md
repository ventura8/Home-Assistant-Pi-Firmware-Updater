---
description: Explore architecture and impact across shell, YAML, tests, and docs before editing.
---

# Explore Workflow

Use for architecture discovery, file tracing, and impact analysis. Prefer
read-only work until the user asks to implement.

## 1. Orient

Read in order (stop early if the question is narrow):

1. `AGENTS.md` — always-on project law
2. `docs/project_overview.md` — layout and goals
3. `docs/integration_logic.md` — SSH, feasibility, UI contracts
4. `.agent/agents.md` — which mode/skill owns the domain

## 2. Trace the Impact Surface

Follow the relevant graph:

- **Host safety**: `host_check.sh` → unit tests → sensor/template YAML →
  apply script / action handler
- **YAML UX**: notification / action handler ↔ `sensor.pi_firmware_monitor`
  attributes and states
- **Install**: `install.sh` / `uninstall.sh` → component/e2e tests → README
  setup steps
- **Quality**: `tests/run_tests.sh` → `scripts/run_local_tests.ps1` → coverage
  badge tooling

## 3. Inventory Before Edit

Produce a short impact list:

- Files likely to change
- Contracts that must stay stable (entities, actions, block tokens, port 22222)
- Tests that must be added or updated
- Docs/agent files that would become stale

## 4. Hand Off

- If the user wants fixes: switch to Fix Mode / `.agent/workflows/fix.md`
- If YAML-only: `ha-yaml-integration-edits`
- If `host_check.sh`: `host-check-update-safety`
- If install/uninstall: `install-uninstall-script-maintenance`
- If release/docs: `.agent/workflows/release.md`
