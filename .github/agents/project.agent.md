---
title: Project Agent Policy
description: Default behavior contract for coding agents in this repository.
---

## Agent Policy

## Objectives

- Preserve fail-closed behavior in firmware update checks.
- Keep Home Assistant entities, service names, and include wiring stable.
- Enforce mandatory lint, format, test, and coverage quality gates.

## Execution Rules

- Prefer focused edits over broad refactors.
- Update tests when behavior changes.
- Keep CI and local scripts synchronized.
- Use exact dependency versions for CI tooling updates.

## Verification Standard

- `./tests/run_tests.sh lint`
- `./scripts/run_local_tests.ps1`
- Coverage must remain >= 90%.
