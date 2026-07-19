# Agents and Skills

This file documents the agent and skill layout used by this project.

## Core Agent Customization Files

- `.github/instructions/project.instructions.md`
- `.github/agents/project.agent.md`
- `.github/prompts/project.prompt.md`
- `.agent/agents.md`
- `.github/copilot-instructions.md`

## Project Skills

- `.github/skills/ha-firmware-fix-pass/SKILL.md`
- `.github/skills/ha-yaml-integration-edits/SKILL.md`
- `.github/skills/host-check-update-safety/SKILL.md`
- `.github/skills/install-uninstall-script-maintenance/SKILL.md`
- `.github/skills/bats-kcov-test-authoring/SKILL.md`
- `.github/skills/release-doc-and-badge-update/SKILL.md`

## Workflow Entry

- `.agent/workflows/fix.md`

## Standard Usage

- Lint and format gate: `./tests/run_tests.sh lint`
- Full local validation: `./scripts/run_local_tests.ps1`
