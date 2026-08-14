---
name: ha-firmware-fix-pass
description: "Fix lint and test failures in one pass for this repository. Use when user asks to fix failing checks, shellcheck, yamllint, bats tests, or coverage regressions. Enforces 90%+ coverage and badge regeneration with scripts/run_local_tests.ps1."
argument-hint: "Scope of files or failing checks"
---

# Home Assistant Firmware Fix Pass

Operational playbook for single-pass lint → test → coverage repair. Project law:
`AGENTS.md`.

## When to Use

- User asks to fix failing tests, lint errors, CI failures, or broken coverage
- Changes touch shell scripts or Home Assistant YAML and must stay release-safe
- You need one end-to-end pass that includes verification

## Hard Rules

- Lint before tests
- Autofix with supported tools before hand-editing remaining lint failures
- Never use lint suppressions or rule disables to pass checks
- Never loosen fail-closed firmware safety to make tests green
- Keep fixing until lint, tests, and coverage ≥ 90% all pass
- Prefer focused edits; avoid unrelated refactors on fix-only requests
- Update agent docs in the same change set when invariants or workflows change

## Procedure

1. **Scope the failure**
   - Read CI logs, local output, or user-provided errors
   - Identify impacted files under `custom_components/`, `tests/`, `.github/`, or docs

2. **Lint gate first**
   - From repository root: `./tests/run_tests.sh lint`
   - Inventory covered by the gate: ShellCheck, shfmt, YamlLint, markdownlint,
     hadolint, actionlint, `manifest.json` JSON validation, cyclomatic complexity
     (max 10 on product shell), non-Markdown max line length 140
   - Apply safe autofix where available (for example `shfmt -w` only when the
     project workflow expects format writes; otherwise keep check-mode parity
     with CI and hand-align to `shfmt -i 4 -bn -sr -ci`)
   - Re-run lint until clean before chasing test behavior

3. **Tests second**
   - Full local parity: `./scripts/run_local_tests.ps1`
   - For iteration, focused Bats under `tests/unit`, `tests/component`, or
     `tests/e2e` are allowed, then re-run the full local script before declaring
     success
   - Fix failures with cross-platform-safe mocks (see Do / Don’t)

4. **Coverage and badge**
   - Confirm total coverage ≥ **90%**
   - Ensure `tests/transform_coverage.py` ran (done by `scripts/run_local_tests.ps1`)
   - Commit updated `assets/coverage.svg` when coverage changed
   - If below 90%, add meaningful branch/path tests immediately — do not stop

5. **Summarize**
   - Report what failed, what changed, residual risk, and whether safety
     contracts were touched

## Regression Checklist

- [ ] `./tests/run_tests.sh lint` exits 0
- [ ] `./scripts/run_local_tests.ps1` exits 0
- [ ] Coverage ≥ 90% and badge current when coverage moved
- [ ] Fail-closed / blocked update behavior unchanged unless the bug fix required
      an intentional, tested safety change
- [ ] Agent docs updated if rules or workflows changed

## Do / Don’t

### Do

- Fix root causes; keep CI and local scripts synchronized
- Guard platform-specific mocks
- Re-run the full local workflow after focused iteration

### Don't

- `# shellcheck disable`, yamllint/markdownlint ignore wrappers, or similar
- Skip coverage badge updates after coverage-affecting changes
- Claim success while any gate still fails
- Mock Unix-only APIs on Windows without checks (`os.mknod`, `SIGKILL`, etc.)
