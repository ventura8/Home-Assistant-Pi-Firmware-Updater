# AI Instructions: Home Assistant Pi Firmware Updater

This document provides technical guidance for AI agents and developers working on this project.

The detailed documentation has been split into multiple files for easier navigation and modularity.

## Documentation Index

- [Project Overview & Directory Structure](docs/project_overview.md)
  - General project goals and file organization.
- [Testing & Quality Standards](docs/development_standards.md)
  - Environment setup, dependency management, and mandatory coverage requirements.
- [HACS Integration Logic](docs/integration_logic.md)
  - How the Bash scripts interact with Home Assistant and the Host OS.
- [AI Agent Workflow](docs/ai_workflow.md)
  - Specific guidelines for AI agents regarding linting, testing, and coverage.

## Agent Skills

Project-specific Copilot agent skills are available under `.github/skills/`:

- `ha-firmware-fix-pass`: Single-pass lint, test, and coverage repair workflow.
- `ha-yaml-integration-edits`: Safe edits for Home Assistant YAML integration files.
- `host-check-update-safety`: Safety-critical host check and firmware update guard logic.
- `install-uninstall-script-maintenance`: Installer/uninstaller SSH and rollback behavior.
- `bats-kcov-test-authoring`: Bats test authoring and kcov coverage workflows.
- `release-doc-and-badge-update`: Release docs and coverage badge synchronization.
