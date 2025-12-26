---
description: Fix lints and tests in the codebase in a single smart pass, ensuring cross-platform compatibility and 90% coverage.
---

1.  **Analyze and Fix Lints**:
    *   Run `run_local_tests.ps1` (or individual lint commands like `flake8` or `shellcheck`) to identify static analysis issues.
    *   Fix all reported lint errors first. Do not proceed to testing until lints are resolved.

2.  **Run and Fix Tests**:
    *   Run the full test suite using `run_local_tests.ps1` or `pytest`.
    *   Analyze any failures.
    *   **Crucial**: When fixing tests, use valid cross-platform mocks.
        *   Do not mock platform-specific signals (like `SIGKILL`) on Windows without checks.
        *   Do not use `os.mknod` or other Unix-only calls in mocks unless guarded by `sys.platform`.
    *   Apply fixes to the code or tests to resolve failures.

3.  **Verify and Enforce Coverage**:
    *   Run `tests/transform_coverage.py` (this is automatically done by `run_local_tests.ps1`, but ensure it happens).
    *   Check the output or `coverage_summary.md` to confirm Total Coverage is at least **90%**.
    *   If coverage is below 90%, identify uncovered lines and add new test cases immediately.
    *   Regenerate the badge to ensure `assets/coverage.svg` is up to date.

4.  **Final Check**:
    *   Ensure all tests pass and the repository is clean of lint errors.
