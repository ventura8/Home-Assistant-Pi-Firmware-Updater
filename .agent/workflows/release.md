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

## 5. Cut the Tag and GitHub Release

1. Confirm everything above is committed and green (lint, tests, coverage,
   badge, docs).
2. Write `docs/releases/vX.Y.Z_github_description.md` (H1 title, key changes,
   `Full Changelog` compare link against the previous tag).
3. Commit the GitHub Release description file so the release tree is clean.
4. Re-run the quality gates on a clean working tree (`./tests/run_tests.sh lint`,
   then `./scripts/run_local_tests.ps1` when coverage or badge may have moved).
5. Create an annotated local tag named `v` + the `manifest.json` `"version"`
   value (for example version `1.0.4` → tag `v1.0.4`), pointing at the commit
   that contains the finalized release description.
6. **Stop and ask before publishing** — pushing the tag and running
   `gh release create` are visible to others and hard to undo. Only do so
   after the user explicitly confirms.

## 6. Acceptance

- Docs match implementation
- No stale release claims
- Lint + local tests green
- Badge and all relevant Markdown current
- `vX.Y.Z_github_description.md` present with a working compare link
- Tag name is `v` + `manifest.json` `"version"`; tag/release only pushed after
  confirmation
- Summarize migration/operational impact for maintainers
