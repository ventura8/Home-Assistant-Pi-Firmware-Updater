#!/bin/bash
set -e

COMPLEXITY_THRESHOLD=10

function run_shellcheck {
    echo "Running ShellCheck..."
    find custom_components tests -name "*.sh" -not -path "tests/mocks/*" -print0 | xargs -0 shellcheck
}

function run_yamllint {
    echo "Running YamlLint..."
    yamllint .
}

function run_shfmt_check {
    echo "Running shfmt check..."
    find custom_components tests \( -name "*.sh" -o -name "*.bats" \) -print0 | xargs -0 shfmt -i 4 -bn -sr -ci -d
}

function run_markdownlint {
    echo "Running markdownlint..."
    find . -name "*.md" -print0 | xargs -0 markdownlint
}

function run_hadolint {
    echo "Running hadolint..."
    hadolint tests/Dockerfile
}

function run_actionlint {
    echo "Running actionlint..."
    actionlint
}

function run_manifest_json_check {
    echo "Validating JSON manifest..."
    python3 -m json.tool custom_components/pi_firmware_updater/manifest.json > /dev/null
}

function run_complexity_check {
    echo "Running complexity check (max cyclomatic complexity per function: ${COMPLEXITY_THRESHOLD})..."
    python3 - << 'PY'
from pathlib import Path
import sys

import lizard

THRESHOLD = 10
TARGETS = [
    Path("custom_components/pi_firmware_updater/host_check.sh"),
    Path("custom_components/pi_firmware_updater/install.sh"),
    Path("custom_components/pi_firmware_updater/uninstall.sh"),
]

violations = []

for path in TARGETS:
    analysis = lizard.analyze_file(str(path))
    for function in analysis.function_list:
        if function.cyclomatic_complexity > THRESHOLD:
            violations.append(
                f"{path}:{function.start_line}:{function.name}:"
                f"ccn={function.cyclomatic_complexity}:threshold={THRESHOLD}"
            )

if violations:
    print("Complexity threshold violations detected:")
    for violation in violations:
        print(violation)
    sys.exit(1)

print(f"All functions are within cyclomatic complexity threshold <= {THRESHOLD}.")
PY
}

function run_non_markdown_line_length_check {
    echo "Checking max line length (140) for non-Markdown files..."
    python3 - << 'PY'
import sys
from pathlib import Path

MAX_LEN = 140
ROOTS = [
    Path(".github"),
    Path("custom_components"),
    Path("tests"),
]
FILES = [
    Path("scripts/run_local_tests.ps1"),
    Path("scripts/run_coverage.ps1"),
    Path(".yamllint"),
    Path("tests/Dockerfile"),
]
EXTENSIONS = {".sh", ".bats", ".yaml", ".yml", ".py", ".ps1", ".json"}

violations = []

for root in ROOTS:
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in EXTENSIONS:
            continue
        try:
            with path.open("r", encoding="utf-8") as handle:
                for index, line in enumerate(handle, start=1):
                    length = len(line.rstrip("\n\r"))
                    if length > MAX_LEN:
                        violations.append(f"{path}:{index}:{length}")
        except UnicodeDecodeError:
            violations.append(f"{path}:1:binary-or-invalid-utf8")

for path in FILES:
    if not path.exists():
        continue
    with path.open("r", encoding="utf-8") as handle:
        for index, line in enumerate(handle, start=1):
            length = len(line.rstrip("\n\r"))
            if length > MAX_LEN:
                violations.append(f"{path}:{index}:{length}")

if violations:
    print("Line length violations detected:")
    for violation in violations:
        print(violation)
    sys.exit(1)
PY
}

function run_lint_suite {
    run_shellcheck
    run_complexity_check
    run_shfmt_check
    run_yamllint
    run_markdownlint
    run_hadolint
    run_actionlint
    run_manifest_json_check
    run_non_markdown_line_length_check
}

function run_suite {
    SUITE=$1
    echo "Running Bats Suite: $SUITE..."
    if [ -d "tests/$SUITE" ]; then
        bats "tests/$SUITE"
    else
        echo "Suite tests/$SUITE not found!"
        exit 1
    fi
}

function run_coverage {
    SUITE=$1
    echo "Running Coverage for Suite: $SUITE..."
    mkdir -p "/app/coverage/$SUITE"

    # Run kcov on the bats command.
    # We output to a suite-specific directory to allow merging later.
    kcov --include-pattern=.sh \
        --exclude-pattern=/app/tests,/app/coverage,/usr \
        "/app/coverage/$SUITE" \
        bats "tests/$SUITE"
}

MODE=$1
ARG=$2

if [ "$MODE" == "shellcheck" ]; then
    run_shellcheck
elif [ "$MODE" == "shfmt-check" ]; then
    run_shfmt_check
elif [ "$MODE" == "yamllint" ]; then
    run_yamllint
elif [ "$MODE" == "markdownlint" ]; then
    run_markdownlint
elif [ "$MODE" == "hadolint" ]; then
    run_hadolint
elif [ "$MODE" == "actionlint" ]; then
    run_actionlint
elif [ "$MODE" == "manifest-json" ]; then
    run_manifest_json_check
elif [ "$MODE" == "complexity" ]; then
    run_complexity_check
elif [ "$MODE" == "line-length" ]; then
    run_non_markdown_line_length_check
elif [ "$MODE" == "lint" ]; then
    run_lint_suite
elif [ "$MODE" == "tests" ]; then
    if [ -n "$ARG" ]; then
        run_suite "$ARG"
    else
        run_suite "unit"
        run_suite "component"
        run_suite "e2e"
    fi
elif [ "$MODE" == "coverage" ]; then
    if [ -n "$ARG" ]; then
        run_coverage "$ARG"
    else
        echo "Specify suite for coverage: unit, component, or e2e"
        exit 1
    fi
else
    echo "Usage: $0 {lint|shellcheck|complexity|shfmt-check|yamllint|markdownlint|hadolint|actionlint|manifest-json|line-length|...}"
    echo "       ... {tests [suite]|coverage [suite]}"
    exit 1
fi
