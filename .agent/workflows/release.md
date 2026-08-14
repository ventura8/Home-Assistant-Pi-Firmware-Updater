---
description: Synchronize README, docs, release notes, coverage badge, and agent guidance for merge or release.
---

# Release Workflow

Aligned with `.github/skills/release-doc-and-badge-update/SKILL.md` and
`AGENTS.md`.

## 1. Identify User-Visible Impact

List changes that affect setup, safety blocks, entities/actions, notifications,
uninstall, or verification commands.

## 2. Bump Version and Update Documentation

1. Set `custom_components/pi_firmware_updater/manifest.json` `"version"` to the
   release version
2. Add `docs/releases/vX.Y.Z.md` and link it from `docs/Instructions.md`
3. Update `README.md` for setup, usage, and warnings
4. Update relevant files under `docs/` (`Instructions.md`, `integration_logic.md`,
   `development_standards.md`, `ai_workflow.md`, `project_overview.md`)
5. Search for stale prior version strings that should move with the release

## 3. Refresh Coverage Artifacts

1. Run `./tests/run_tests.sh lint`
2. Run `./scripts/run_local_tests.ps1`
3. Confirm coverage ≥ 90%
4. Ensure `assets/coverage.svg` is current and included in the change set when
   coverage moved

## 4. Align Agent Docs

If rules, workflows, or invariants changed:

1. Update `AGENTS.md`
2. Update affected `.github/skills/*/SKILL.md`
3. Update `.agent/workflows/*` / `.agent/agents.md` as needed
4. Keep Copilot sidecars accurate as thin summaries (no conflicting forks)

## 5. Acceptance

- Docs match implementation
- No stale release claims
- Lint + local tests green
- Badge and agent docs current
- Summarize migration/operational impact for maintainers
