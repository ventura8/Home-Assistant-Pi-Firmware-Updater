---
name: release-doc-and-badge-update
description: "Prepare release-safe documentation, coverage artifacts, and the tag/GitHub release for this project. Use when behavior changes require README/docs updates, when coverage badge and release notes must be refreshed, or when cutting a version tag."
argument-hint: "What changed and target release version"
---

# Release Doc and Badge Update

Playbook for user-facing docs, release notes, coverage artifacts, and the
version tag/GitHub release. Project law: `AGENTS.md`. Workflow entry:
`.agent/workflows/release.md`.

## When to Use

- Behavior or setup workflow changed and docs need updates
- Coverage changed and badge or release notes may be stale
- Preparing final change set for merge or release tagging
- Cutting the `vX.Y.Z` tag / GitHub Release once `manifest.json` version and
  docs are ready (existing tags: `v1.0.0`–`v1.0.3`, one per released
  `manifest.json` version)

## Hard Rules

- Documentation must match actual script prompts, paths, and requirements
- Coverage badge ships with coverage-affecting changes (`assets/coverage.svg`)
- Versioned notes under `docs/releases/` stay accurate — no stale claims
- On every task, update all relevant Markdown in the same change set (see
  `AGENTS.md`)
- Do not claim CI updates the badge; local regeneration is required

## Procedure

1. **Identify user-visible impact**
   - Setup prerequisites, SSH port, safety blocks, notify actions, entity names,
     failure messages, or uninstall behavior

2. **Bump the integration version everywhere it is authoritative**
   - Set `custom_components/pi_firmware_updater/manifest.json` `"version"` to the
     release version (for example `1.0.3`) — this is the single source of truth;
     do not invent a version from a branch name or a prior tag
   - Add `docs/releases/vX.Y.Z.md` matching that version
   - Link the latest release from `docs/Instructions.md` when cutting a release
   - Search the repo for stale prior version strings in docs/release indexes

3. **Update docs in lockstep**
   - `README.md` — setup, usage, warnings, screenshots captions if behavior
     changed meaningfully
   - `docs/Instructions.md` — index links when agent/doc tree changes
   - `docs/project_overview.md`, `docs/integration_logic.md`,
     `docs/development_standards.md`, `docs/ai_workflow.md` as relevant
   - `docs/releases/*` — versioned release/PR description markdown when cutting
     or documenting a release

4. **Regenerate coverage artifacts**
   - Run `./tests/run_tests.sh lint` first
   - Then run `./scripts/run_local_tests.ps1`
   - Confirm coverage ≥ 90% and that `assets/coverage.svg` / coverage summary
     reflect current results
   - Include badge in the commit set when it changed

5. **Consistency pass**
   - Cross-check README prerequisites against real add-on requirements
   - Cross-check blocked reasons / entity names against YAML + `host_check.sh`
   - Cross-check agent skill index vs files on disk
   - Confirm `manifest.json` version matches `docs/releases/vX.Y.Z.md`

6. **Write the GitHub Release description file**
   - Add `docs/releases/vX.Y.Z_github_description.md` alongside the full
     release page — this is the exact body pasted into the GitHub Release,
     not a duplicate of `vX.Y.Z.md`
   - H1 title: `# Home Assistant Pi Firmware Updater vX.Y.Z - <Short Theme Title>`
   - Short summary + key changes as bullets (not the full file inventory —
     that stays in `vX.Y.Z.md`)
   - End with the compare link, using the previous release tag:

     ```markdown
     **Full Changelog**: [vPREV...vX.Y.Z](https://github.com/ventura8/Home-Assistant-Pi-Firmware-Updater/compare/vPREV...vX.Y.Z)
     ```

   - Commit `docs/releases/vX.Y.Z_github_description.md` so the release tree
     is clean before tagging
   - Re-run `./tests/run_tests.sh lint` and `./scripts/run_local_tests.ps1`
     (when coverage or badge may have moved) on that clean tree

7. **Cut the tag (local, then confirm before publishing)**
   - Everything above must be committed first (docs, badge, `manifest.json`,
     GitHub Release description file) and lint + local tests green
   - Create an **annotated** tag locally named `v` + the `manifest.json`
     `"version"` value (version `X.Y.Z` → tag `vX.Y.Z`), on the commit that
     contains the finalized release description:

     ```bash
     git tag -a vX.Y.Z -m "vX.Y.Z: <Short Theme Title>"
     ```

   - **Do not push the tag or run `gh release create` without the user's
     explicit go-ahead** — a pushed tag and a published GitHub Release are
     both visible to others and awkward to undo. Report the tag is staged
     locally and ask before publishing.
   - Once confirmed:

     ```bash
     git push origin vX.Y.Z
     gh release create vX.Y.Z \
       --title "Home Assistant Pi Firmware Updater vX.Y.Z - <Short Theme Title>" \
       --notes-file docs/releases/vX.Y.Z_github_description.md
     ```

   - If the tag needs to move before publishing (extra fixup commit landed):
     1. Check whether the remote already has it:
        `git ls-remote --tags origin "refs/tags/vX.Y.Z"`
     2. If the remote tag **exists**, do **not** delete or force-update it —
        publish that tagged commit as-is, or bump to a new version instead
     3. If the remote tag is **absent**, delete and recreate the local tag only
        (`git tag -d vX.Y.Z`, then recreate) — never force-push a moved tag

8. **Maintainer summary**
   - Note migration steps, operational impact, and verification commands
   - State whether the tag/release was only staged locally or actually published

## Acceptance Checks

- [ ] `manifest.json` version matches the release notes filename/title
- [ ] README and docs match implementation
- [ ] Release notes do not claim removed features or outdated block rules
- [ ] Coverage badge current for the proposed changes
- [ ] All relevant Markdown updated in the same change set
- [ ] Lint + local tests green
- [ ] `docs/releases/vX.Y.Z_github_description.md` written with a working
      `Full Changelog` compare link against the correct previous tag
- [ ] Tag name is `v` + `manifest.json` `"version"` (version `X.Y.Z` → `vX.Y.Z`)
- [ ] Tag push / `gh release create` only done after explicit user confirmation
- [ ] Existing remote tags were not force-moved; local recreate only when remote
      tag is absent

## Do / Don’t

### Do

- Treat docs and badge as part of the product change
- Keep release markdown GitHub-ready
- Link agents to `AGENTS.md` as SSOT for rules
- Tag only after docs, badge, and tests are committed and green
- Ask before pushing a tag or publishing a GitHub Release

### Don't

- Leave placeholder notify IDs documented as if they were real device IDs
- Ship coverage drops without explanation and tests
- Duplicate conflicting policy across README and `AGENTS.md` — align them
- Push a tag or run `gh release create` without explicit user confirmation
- Force-move a tag that may already be public
