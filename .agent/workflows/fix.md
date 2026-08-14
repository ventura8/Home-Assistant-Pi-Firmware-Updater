---
description: Fix lints and tests in the codebase in a single smart pass, ensuring cross-platform compatibility and 90% coverage.
---

# Fix Workflow

Aligned with `.github/skills/ha-firmware-fix-pass/SKILL.md` and `AGENTS.md`.

## 1. Analyze and Fix Lints

1. Identify failing files/checks from CI or local output.
2. Run `./tests/run_tests.sh lint` as the mandatory first validation step.
3. Lint inventory: ShellCheck, shfmt, YamlLint, markdownlint, hadolint,
   actionlint, JSON manifest validation, cyclomatic complexity (max 10 on
   product shell), non-Markdown max line length 140.
4. Autofix with supported tools first; hand-edit only what remains.
5. Do not use suppressions or rule disables.
6. Do not proceed to behavioral test fixes until lint is clean.

## 2. Run and Fix Tests

1. Run the full suite via `./scripts/run_local_tests.ps1`.
2. Focused Bats under `tests/unit`, `tests/component`, or `tests/e2e` are OK
   while iterating; re-run the full local script before declaring success.
3. Analyze failures and fix code or tests.
4. Use valid cross-platform mocks:
   - Do not mock platform-specific signals (like `SIGKILL`) on Windows without
     checks.
   - Do not use `os.mknod` or other Unix-only calls in mocks unless guarded by
     `sys.platform`.
5. Never loosen fail-closed firmware safety to make tests pass.

## 3. Verify and Enforce Coverage

1. Ensure `tests/transform_coverage.py` ran (automatic via
   `scripts/run_local_tests.ps1`).
2. Confirm total coverage is at least **90%** (see coverage summary output).
3. If below 90%, add tests for uncovered product branches immediately.
4. Regenerate/commit `assets/coverage.svg` when coverage changed.

## 4. Keep Fixing Until Green

1. Re-run lint and full local tests after each substantive fix batch.
2. Treat every remaining lint/test/coverage failure as blocking.
3. Update agent docs in the same change set if workflows or invariants changed.

## 5. Final Check

- Lint clean, tests green, coverage ≥ 90%, badge current when required
- Summarize changes, risks, and any safety-contract impact
