# GitHub Copilot Instructions

## Repository Priorities

- Safety-first firmware update behavior.
- Strict mandatory quality gates in local and CI.
- No lint suppressions or disables.
- Preserve Home Assistant integration entity/service contracts.

## Required Validation Sequence

1. `./tests/run_tests.sh lint`
2. `./scripts/run_local_tests.ps1`
3. Confirm coverage >= 90%.

## Skills

See `.github/skills/README.md` for project-specific skill routing.
