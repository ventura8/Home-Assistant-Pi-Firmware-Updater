# Testing & Quality Standards

## Mandatory Code Coverage
- **Threshold:** Minimum **90%** coverage for all Bash scripts.
- **Enforcement:** The CI pipeline (`test.yml`) will fail if coverage falls below 90%.

## Local Development Workflow
Coverage badges are **not** updated by the CI pipeline. They must be updated locally before committing changes.

### Running Tests and Updating Badge
To run all tests and update the coverage badge in `assets/coverage.svg`, use the provided PowerShell script:

```powershell
./run_local_tests.ps1
```

This script will:
1. Build the Docker test environment.
2. Run ShellCheck and YamlLint.
3. Execute all Bats test suites (Unit, Component, E2E).
4. Generate and merge coverage reports.
5. Update `assets/coverage.svg` using `tests/transform_coverage.py`.

### Committing Changes
Always ensure you commit the updated `assets/coverage.svg` along with your code changes.

## Tools
- **Bats-core:** Bash Automated Testing System.
- **kcov:** Code coverage tool for Bash.
- **Docker:** Used to provide a consistent test environment.
- **ShellCheck:** Linting for Bash scripts.
- **YamlLint:** Linting for YAML configuration files.
