# AI Agent Workflow Guidelines

This document outlines the mandatory workflow for AI agents contributing to this project. Follow these rules to ensure code quality, coverage, and cross-platform compatibility.

## 1. Smart Single-Pass Fixes
When a user requests fixes for a file (or set of files), you must address **both** linting issues and test failures in a single pass/turn whenever possible.

> [!TIP]
> **Automated Workflow**: An agent workflow file is available at `.agent/workflows/fix.md`. Standard agents should favor following the steps defined in this workflow.

### Order of Operations
1.  **Fix Lint Problems First:** Address all `flake8`, `mypy`, or `shellcheck` errors.
2.  **Fix Test Failures:** Once static analysis passes, resolve any `pytest` or `bats` failures.

## 2. Mandatory Coverage Requirements
After running tests, you must **always** perform the following coverage checks:

1.  **Generate Badge:** Ensure the coverage badge is regenerated locally.
    *   Command: `python tests/transform_coverage.py` (or via `run_local_tests.ps1`)
2.  **Verify Threshold:** Check that the total coverage is at least **90%**.
    *   If coverage is < 90%, you **must** add additional tests to cover 
    missing lines or branches before submitting your changes.

## 3. Cross-Platform Compatibility
The development environment is mixed (Windows/Linux).
*   **Mocks:** Always use mocks that are compatible with both Windows and Linux.
    *   *Bad:* Mocking `os.mknod` (Unix only) without platform checks.
    *   *Bad:* Assuming `signal.SIGKILL` exists on Windows.
    *   *Good:* Use `unittest.mock.MagicMock` for platform-specific interactions and condition them on `sys.platform` if necessary, or mock the higher-level abstraction.

## 4. Documentation
*   Keep `Instructions.md` and `README.md` up to date if workflows change.
