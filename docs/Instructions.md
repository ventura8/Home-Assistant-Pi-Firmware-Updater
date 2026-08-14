# AI Instructions: Home Assistant Pi Firmware Updater

This document provides technical guidance for AI agents and developers working on this project.

The detailed documentation has been split into multiple files for easier navigation and modularity.

**Agent rules SSOT:** root [`AGENTS.md`](../AGENTS.md) is the always-on project law for quality gates, firmware safety invariants, HA contracts, and mandatory agent-doc updates. Skills and workflows operationalize that law; do not fork conflicting policy.

## Documentation Index

- [Project Overview & Directory Structure](project_overview.md)
  - General project goals and file organization.
- [Testing & Quality Standards](development_standards.md)
  - Environment setup, dependency management, and mandatory coverage requirements.
- [HACS Integration Logic](integration_logic.md)
  - How the Bash scripts interact with Home Assistant and the Host OS.
- [AI Agent Workflow](ai_workflow.md)
  - Agent workflow summary; defers full law to `AGENTS.md`.
- [Release Descriptions](releases)
  - GitHub-ready release/PR description markdown for each release commit.
  - Latest: [v1.0.3](releases/v1.0.3.md)

## Agent Skills

Project-specific Copilot agent skills are available under `.github/skills/`:

- `ha-firmware-fix-pass`: Single-pass lint, test, and coverage repair workflow.
- `ha-yaml-integration-edits`: Safe edits for Home Assistant YAML integration files.
- `host-check-update-safety`: Safety-critical host check and firmware update guard logic.
- `install-uninstall-script-maintenance`: Installer/uninstaller SSH and rollback behavior.
- `bats-kcov-test-authoring`: Bats test authoring and kcov coverage workflows.
- `release-doc-and-badge-update`: Release docs and coverage badge synchronization.

See [`.github/skills/README.md`](../.github/skills/README.md) for trigger hints.

## Agent Customization Files

- `AGENTS.md`: Always-on project law (SSOT for agent rules).
- `.github/instructions/project.instructions.md`: Workspace-wide Copilot defaults.
- `.github/instructions/shell.instructions.md`: File-scoped shell/Bats rules.
- `.github/instructions/ha-yaml.instructions.md`: File-scoped HA YAML rules.
- `.github/agents/project.agent.md`: Default execution policy for coding agents.
- `.github/prompts/project.prompt.md`: Prompt defaults and short prompt library.
- `.agent/agents.md`: Mode-level routing guide.
- `.agent/workflows/fix.md`: Lint/test/coverage fix workflow.
- `.agent/workflows/explore.md`: Architecture and impact exploration workflow.
- `.agent/workflows/release.md`: Docs, badge, and release alignment workflow.
- `.github/copilot-instructions.md`: GitHub-scope Copilot instructions.
- `.github/skills/README.md`: Index for project skill packages.
