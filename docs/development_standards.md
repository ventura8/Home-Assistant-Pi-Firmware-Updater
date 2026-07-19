# Testing & Quality Standards

## Mandatory Code Coverage

- **Threshold:** Minimum **90%** coverage for all Bash scripts.
- **Enforcement:** The CI pipeline (`test.yml`) will fail if coverage falls below 90%.

## Local Development Workflow

Coverage badges are **not** updated by the CI pipeline. They must be updated locally before committing changes.

### Running Tests and Updating Badge

To run all tests and update the coverage badge in `assets/coverage.svg`, use the provided PowerShell script:

```powershell
./scripts/run_local_tests.ps1
```

This script will:

1. Build the Docker test environment.
2. Run the mandatory lint and formatter gate via `./tests/run_tests.sh lint`.
3. The lint and formatter gate includes: ShellCheck, cyclomatic complexity enforcement, shfmt (check mode), YamlLint, markdownlint (Markdown line-length excluded), hadolint, actionlint, JSON manifest validation, and a non-Markdown max line-length check (140).
4. Execute all Bats test suites (Unit, Component, E2E).
5. Generate and merge coverage reports.
6. Update `assets/coverage.svg` using `tests/transform_coverage.py`.
7. Generate `coverage/coverage-summary.md` with overall and per-file coverage and complexity, then print that summary at the end of the local run.

## Mandatory Lint and Formatting Policy

- **Maximum line length:** 140 characters for all non-Markdown files.
- **Maximum cyclomatic complexity per function:** 10.
- **Markdown exception:** Markdown line-length is not enforced.
- **No suppressions:** Do not disable lint rules to pass checks.

### Committing Changes

Always ensure you commit the updated `assets/coverage.svg` along with your code changes.

## Tools

- **Bats-core:** Bash Automated Testing System.
- **kcov:** Code coverage tool for Bash.
- **Docker:** Used to provide a consistent test environment.
- **ShellCheck:** Linting for Bash scripts.
- **shfmt:** Formatting checks for Bash and Bats files.
- **YamlLint:** Linting for YAML configuration files.
- **markdownlint-cli:** Markdown linting checks.
- **hadolint:** Dockerfile linting checks.
- **actionlint:** GitHub Actions workflow linting checks.
