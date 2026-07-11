---
name: bats-kcov-test-authoring
description: "Write or update Bats tests and coverage wiring for this repository. Use for unit/component/e2e tests, mocks, kcov coverage merges, and enforcing minimum 90% coverage in local and CI runs."
argument-hint: "Test suite target: unit, component, e2e, or coverage"
---

# Bats and kcov Test Authoring

## When to Use
- Adding tests for shell script changes.
- Fixing flaky or failing Bats tests.
- Improving coverage to meet 90% threshold.

## Procedure
1. Pick the correct suite location:
   - tests/unit for script logic and edge cases.
   - tests/component for integration interactions.
   - tests/e2e for end-to-end workflow behavior.
2. Reuse existing helper patterns from tests and coverage helpers.
3. Keep mocks cross-platform:
   - Avoid Unix-only assumptions in mocks unless guarded.
   - Prefer behavior-level mocks over low-level platform-specific primitives.
4. Ensure assertions cover both success and fail-closed paths.
5. Run full local workflow with ./run_local_tests.ps1 after adding tests.
6. Confirm merged coverage reports and badge update behavior are intact.

## Quality Bar
- Tests should assert user-visible outcomes and exit statuses.
- New safety logic must include blocked and unblocked scenario coverage.
- Coverage improvements should target meaningful branches, not only line count.
