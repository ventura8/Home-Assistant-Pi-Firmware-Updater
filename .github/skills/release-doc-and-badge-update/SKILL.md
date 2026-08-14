---
name: release-doc-and-badge-update
description: "Prepare release-safe documentation and coverage artifacts for this project. Use when behavior changes require README/docs updates or when coverage badge and release notes must be refreshed consistently."
argument-hint: "What changed and target release version"
---

# Release Doc and Badge Update

Playbook for user-facing docs, release notes, and coverage artifacts. Project law:
`AGENTS.md`. Workflow entry: `.agent/workflows/release.md`.

## When to Use

- Behavior or setup workflow changed and docs need updates
- Coverage changed and badge or release notes may be stale
- Preparing final change set for merge or release tagging

## Hard Rules

- Documentation must match actual script prompts, paths, and requirements
- Coverage badge ships with coverage-affecting changes (`assets/coverage.svg`)
- Versioned notes under `docs/releases/` stay accurate — no stale claims
- Agent docs update in the same change set when rules/behavior change
- Do not claim CI updates the badge; local regeneration is required

## Procedure

1. **Identify user-visible impact**
   - Setup prerequisites, SSH port, safety blocks, notify actions, entity names,
     failure messages, or uninstall behavior

2. **Bump the integration version everywhere it is authoritative**
   - Set `custom_components/pi_firmware_updater/manifest.json` `"version"` to the
     release version (for example `1.0.3`)
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

6. **Maintainer summary**
   - Note migration steps, operational impact, and verification commands

## Acceptance Checks

- [ ] `manifest.json` version matches the release notes filename/title
- [ ] README and docs match implementation
- [ ] Release notes do not claim removed features or outdated block rules
- [ ] Coverage badge current for the proposed changes
- [ ] `AGENTS.md` / skills / workflows updated if law or procedures changed
- [ ] Lint + local tests green

## Do / Don’t

### Do

- Treat docs and badge as part of the product change
- Keep release markdown GitHub-ready
- Link agents to `AGENTS.md` as SSOT for rules

### Don't

- Leave placeholder notify IDs documented as if they were real device IDs
- Ship coverage drops without explanation and tests
- Duplicate conflicting policy across README and `AGENTS.md` — align them
