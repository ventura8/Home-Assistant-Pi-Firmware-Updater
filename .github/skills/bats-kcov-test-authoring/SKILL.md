---
name: bats-kcov-test-authoring
description: "Write or update Bats tests and coverage wiring for this repository. Use for unit/component/e2e tests, mocks, kcov coverage merges, and enforcing minimum 90% coverage in local and CI runs."
argument-hint: "Test suite target: unit, component, e2e, or coverage"
---

# Bats and kcov Test Authoring

Playbook for tests under `tests/` and coverage tooling. Project law: `AGENTS.md`.
Standards: `docs/development_standards.md`.

## When to Use

- Adding tests for shell script changes
- Fixing flaky or failing Bats tests
- Improving coverage to meet the 90% threshold
- Changing coverage merge or badge generation behavior

## Hard Rules

- Place tests in the correct suite (unit / component / e2e)
- Assert success **and** fail-closed / blocked paths for safety logic
- Keep mocks cross-platform safe
- Maintain ≥ **90%** total coverage
- Regenerate `assets/coverage.svg` locally when coverage changes
- Prefer meaningful branch coverage over line-count padding

## Suite Placement

| Suite | Path | Use for |
| --- | --- | --- |
| Unit | `tests/unit/` | Script logic, edge cases (`host_check_test.bats`, structure) |
| Component | `tests/component/` | Install/uninstall interactions |
| E2E | `tests/e2e/` | Workflow simulation across install + config mutation |

Reuse helpers and environment overrides already used by existing tests
(`CONFIG_DIR`, `SSH_DIR`, model/cmdline fixtures, HA CLI stubs, etc.).

## Procedure

1. Identify the behavior under test and which suite owns it
2. Copy patterns from neighboring tests rather than inventing a new harness
3. For `host_check.sh`:
   - Cover HA CLI success, HA parse failure → fallback, blocked NVMe/SSD,
     allowed mmc boot, EEPROM missing/query/parse failures, and `--update`
     abort vs launch paths as applicable
4. For install/uninstall: cover idempotent success, missing artifacts, and ID
   injection / revert
5. Keep mocks at behavior level; guard Unix-only primitives
6. Run focused Bats while iterating, then full `./scripts/run_local_tests.ps1`
7. Confirm kcov merge + `tests/transform_coverage.py` badge/summary outputs
8. If coverage < 90%, add tests for uncovered product branches before finishing

## Coverage Tooling

- Local full run builds Docker test env, runs lint, executes Bats suites, merges
  coverage, updates `assets/coverage.svg`, and prints
  `coverage/coverage-summary.md` (via `scripts/run_local_tests.ps1`)
- CI fails below 90%; badge update remains a local/commit responsibility
- Do not weaken coverage thresholds to green a PR

## Quality Bar

- Assert user-visible outcomes, exit statuses, and key substrings
  (`update_blocked`, `blocked_reason` tokens)
- New safety logic must include blocked and unblocked scenarios
- Flaky sleeps/timeouts: prefer deterministic stubs over real long waits

## Regression Checklist

- [ ] New tests land in the correct suite directory
- [ ] Fail-closed paths asserted where safety changed
- [ ] Mocks safe on Windows and Linux runners/dev machines
- [ ] `./tests/run_tests.sh lint` clean (includes `.bats` shfmt)
- [ ] Full local run green with coverage ≥ 90%
- [ ] Badge committed when coverage moved

## Do / Don’t

### Do

- Read existing `host_check_test.bats` fixtures before adding HA JSON stubs
- Fail tests on unexpected success when block is required
- Keep test data minimal and explicit

### Don't

- Mock away the safety condition under test
- Depend on live Raspberry Pi hardware for unit tests
- Raise timeouts to hide hung product paths
- Check in coverage drops without new tests
