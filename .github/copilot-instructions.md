# GitHub Copilot Instructions

Full always-on project law: root [`AGENTS.md`](../AGENTS.md).
Skills: [`.github/skills/README.md`](skills/README.md).
Modes: [`.agent/agents.md`](../.agent/agents.md).

## Repository Priorities

- Safety-first firmware update behavior (fail-closed)
- Strict mandatory quality gates in local and CI
- No lint suppressions or disables
- Preserve Home Assistant integration entity/service/action contracts
- Update agent docs when rules or behavior change

## Required Validation Sequence

1. `./tests/run_tests.sh lint`
2. `./scripts/run_local_tests.ps1`
3. Confirm coverage ≥ 90% and refresh `assets/coverage.svg` when coverage changes

## Skills

See `.github/skills/README.md` for project-specific skill routing.
