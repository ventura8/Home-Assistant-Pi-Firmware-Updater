---
name: ha-firmware-fix-pass
description: "Fix lint and test failures in one pass for this repository. Use when user asks to fix failing checks, shellcheck, yamllint, bats tests, or coverage regressions. Enforces 90%+ coverage and badge regeneration with run_local_tests.ps1."
argument-hint: "Scope of files or failing checks"
---

# Home Assistant Firmware Fix Pass

## When to Use
- User asks to fix failing tests, lint errors, CI failures, or broken coverage.
- Changes touch shell scripts or Home Assistant YAML and must stay release-safe.
- You need one end-to-end pass that includes verification.

## Procedure
1. Read failure context and identify impacted files first.
2. Run local quality workflow from repository root:
   - PowerShell: ./run_local_tests.ps1
   - If a quick iteration is needed, run focused Bats suites under tests/unit, tests/component, or tests/e2e.
3. Fix lint issues before test behavior issues:
   - ShellCheck warnings in shell scripts.
   - YamlLint issues in automation and sensor files.
4. Fix test failures with cross-platform-safe mocks.
5. Re-run tests until green.
6. Verify coverage is at least 90% and badge is updated:
   - Ensure tests/transform_coverage.py has been executed (done by run_local_tests.ps1).
   - Confirm assets/coverage.svg changed when coverage changed.
7. Summarize behavior changes and risks.

## Project Rules
- Keep fail-closed behavior for blocked or unknown update conditions.
- Do not loosen safety checks to make tests pass.
- Keep command behavior compatible with mixed Windows/Linux development.
- Avoid unrelated refactors during fix-only requests.
