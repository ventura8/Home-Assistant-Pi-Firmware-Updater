---
title: Shell and Bats Instructions
description: File-scoped rules for product shell scripts and Bats tests.
applyTo: "**/*.{sh,bash,bats}"
---

## Shell / Bats Scope

Follow root `AGENTS.md`. For `host_check.sh` use
`.github/skills/host-check-update-safety/SKILL.md`. For install/uninstall use
`.github/skills/install-uninstall-script-maintenance/SKILL.md`. For tests use
`.github/skills/bats-kcov-test-authoring/SKILL.md`.

## Rules

- Pass ShellCheck and shfmt (`-i 4 -bn -sr -ci`); no `# shellcheck disable`
- Keep functions at cyclomatic complexity ≤ 10 on product scripts
- Max line length 140
- Preserve fail-closed update behavior and `&&` update+reboot chaining
- Keep monitor `emit_summary` fields parseable by YAML sensors
- Prefer idempotent install/uninstall with honest exit codes
- Assert blocked and unblocked paths in new safety tests
- Use cross-platform-safe mocks; guard Unix-only primitives

## Verify

1. `./tests/run_tests.sh lint`
2. `./scripts/run_local_tests.ps1`
3. Coverage ≥ 90%; update `assets/coverage.svg` when coverage changes
