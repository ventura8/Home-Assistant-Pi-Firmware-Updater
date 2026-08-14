---
name: pipeline-runner
description: >-
  Run the full local CI-parity pipeline for this repo (lint, Bats suites, kcov
  coverage ≥ 90%, coverage badge). Use when the user asks to run the pipeline,
  validate locally before commit/PR, or re-check quality gates after fixes.
argument-hint: "Optional: full | lint-only | focused suite"
---

# Local Pipeline Runner

Inspired by the asus-zenbook `pipeline-runner` skill, adapted to this project's
Docker + PowerShell local gates. Project law: `AGENTS.md`. Related fix playbook:
`.github/skills/ha-firmware-fix-pass/SKILL.md`.

## When to Use

- User asks to “run the pipeline”, “validate locally”, or “CI parity”
- Before declaring a release or PR ready
- After substantive shell/YAML/test changes

## Hard Rules

- Stream output live; also capture a durable log under `reports/pipeline-logs/`
- Lint before chasing test/coverage failures
- Autofix with project-supported tools first (`shfmt -w` when formatting is the
  failure mode), then hand-fix remaining issues
- **Keep fixing until the full pipeline exits 0** — do not stop after the first
  failure report
- Never suppress, disable, or loosen gates (`# shellcheck disable`, yamllint /
  markdownlint ignores, lowering the 90% coverage bar, skipping suites)
- Never loosen fail-closed firmware safety to make tests green
- Coverage badge (`assets/coverage.svg`) must be refreshed when coverage moves
  (done by `scripts/run_local_tests.ps1`)

## Canonical full pipeline

From repository root (Linux with `pwsh` + Docker):

```bash
set -euo pipefail
mkdir -p reports/pipeline-logs
pwsh -File ./scripts/run_local_tests.ps1 \
  2>&1 | tee "reports/pipeline-logs/full-pipeline-$(date -u +%Y%m%dT%H%M%SZ).log"
```

This is CI parity for this repo:

1. `docker build -t ha-updater-test -f tests/Dockerfile .`
2. Lint gate (mounted workspace): `./tests/run_tests.sh lint`
3. Bats unit + component + e2e (image `/app`)
4. kcov coverage per suite → merge → `tests/transform_coverage.py` badge
5. Fail if total line coverage `< 90%`

## Iteration helpers (then re-run full)

Lint only (Docker tools, current tree):

```bash
mkdir -p reports/pipeline-logs
docker run --rm -v "$(pwd):/work" -w /work ha-updater-test \
  bash /work/tests/run_tests.sh lint \
  2>&1 | tee reports/pipeline-logs/lint.log
```

Focused Bats (after image build):

```bash
docker run --rm ha-updater-test /app/tests/run_tests.sh tests component
docker run --rm ha-updater-test /app/tests/run_tests.sh tests unit
docker run --rm ha-updater-test /app/tests/run_tests.sh tests e2e
```

Safe autofix before hand-edits:

```bash
shfmt -i 4 -bn -sr -ci -w custom_components/pi_firmware_updater/*.sh \
  tests/mocks/* tests/component/*.bats tests/e2e/*.bats tests/unit/*.bats
```

## Lint inventory (must stay green)

Via `./tests/run_tests.sh lint`:

- ShellCheck, shfmt (check), YamlLint, markdownlint, hadolint, actionlint
- `manifest.json` JSON validation
- Cyclomatic complexity ≤ 10 on product shell (`host_check.sh`, `install.sh`,
  `uninstall.sh`, `ssh_wrapper.sh`)
- Non-Markdown max line length 140

## Coverage inventory

- Product shell under `custom_components/pi_firmware_updater/*.sh` via kcov
- Total line coverage ≥ **90%**
- Badge at `assets/coverage.svg`; summary under `coverage/coverage-summary.md`

## Procedure

1. Ensure Docker is available; `pwsh` preferred for the canonical script
2. Run the full pipeline with `tee` into `reports/pipeline-logs/`
3. On failure: diagnose from live output / log → autofix → hand-fix → re-run
   focused stage → **re-run full pipeline** before success
4. Report: lint OK, suites OK, coverage %, badge updated yes/no, log path

## Acceptance

- [ ] Full `./scripts/run_local_tests.ps1` exit 0
- [ ] Coverage ≥ 90%
- [ ] `assets/coverage.svg` current when coverage changed
- [ ] No suppressions introduced
- [ ] Log saved under `reports/pipeline-logs/`

## Do / Don't

### Do

- Treat every red gate as blocking
- Prefer root-cause fixes over threshold games
- Keep local script and CI workflow aligned when changing gates

### Don't

- Claim success while any stage fails
- Raise timeouts or skip suites to hide flakes
- Run only a focused suite and skip the final full pass
