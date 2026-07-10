---
name: release-doc-and-badge-update
description: "Prepare release-safe documentation and coverage artifacts for this project. Use when behavior changes require README/docs updates or when coverage badge and release notes must be refreshed consistently."
argument-hint: "What changed and target release version"
---

# Release Doc and Badge Update

## When to Use
- Behavior or setup workflow changed and user-facing docs need updates.
- Coverage changed and badge or release notes may be stale.
- Preparing final change set for merge or release tagging.

## Procedure
1. Identify user-visible impact from code changes.
2. Update docs in lockstep:
   - README.md for setup, usage, or warning changes.
   - Instructions.md and docs/* when workflow or engineering constraints changed.
   - docs/releases/* for versioned release summaries where applicable.
3. Regenerate coverage artifacts through local test workflow:
   - Run ./run_local_tests.ps1.
   - Ensure assets/coverage.svg reflects current results.
4. Verify consistency between docs and implementation details.
5. Summarize migration or operational impact for maintainers.

## Acceptance Checks
- Documentation reflects actual script prompts, file paths, and requirements.
- Coverage badge is current for the proposed changes.
- No stale release claims remain after edits.
