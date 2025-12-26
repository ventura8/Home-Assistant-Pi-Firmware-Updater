#!/bin/bash
set -e

function run_shellcheck {
    echo "Running ShellCheck..."
    find . -name "*.sh" -not -path "./tests/mocks/*" -print0 | xargs -0 shellcheck
}

function run_yamllint {
    echo "Running YamlLint..."
    yamllint .
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
elif [ "$MODE" == "yamllint" ]; then
    run_yamllint
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
    echo "Usage: $0 {shellcheck|yamllint|tests [suite]|coverage [suite]}"
    exit 1
fi
