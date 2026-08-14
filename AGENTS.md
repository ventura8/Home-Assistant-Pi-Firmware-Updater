# Project Agent Rules & Development Guidelines

This file is the always-on agent law for **Home Assistant Pi Firmware Updater**.
Copilot sidecars and skills summarize or operationalize these rules; they must not
conflict with them. Prefer this file plus the matching skill when guidance
diverges.

## Project Overview

HACS-compatible Home Assistant integration that monitors and updates Raspberry Pi
bootloader (EEPROM) firmware from HA. The Home Assistant container reaches the
host OS over SSH on port **22222** using RSA keys. Safety is fail-closed: unsafe
or untrusted upgrade conditions never apply firmware.

### Critical paths

- `custom_components/pi_firmware_updater/` — product scripts and HA YAML
  - `host_check.sh` — host-side feasibility, monitor output, `--update`
  - `install.sh` / `uninstall.sh` — SSH setup and rollback
  - `*.yaml` — sensors, shell commands, notifications, action handler, apply script
  - `manifest.json` — HACS/integration metadata
- `tests/` — Bats unit / component / e2e, `run_tests.sh`, `transform_coverage.py`
- `assets/coverage.svg` — coverage badge (updated locally, not by CI alone)
- `docs/` — human and agent-adjacent engineering docs
- `.github/skills/` — operational playbooks
- `.agent/` — mode registry and workflows

### Human doc index

- `docs/Instructions.md` — documentation map
- `docs/project_overview.md` — goals and layout
- `docs/integration_logic.md` — SSH, feasibility, UI contracts
- `docs/development_standards.md` — lint, coverage, local workflow
- `docs/ai_workflow.md` — agent workflow summary (points here for full law)

## Mandatory Quality Gates

- First gate: `./tests/run_tests.sh lint`
- Full local CI parity: `./scripts/run_local_tests.ps1`
- Keep maximum line length at **140** for all non-Markdown sources and configs
- Markdown line-length is intentionally not enforced
- Maximum cyclomatic complexity per function: **10** (enforced on product shell)
- **No suppressions**: never use `# shellcheck disable`, yamllint disables,
  markdownlint disable wraps, or other lint ignores to pass checks
- Autofix with project-supported formatters/delinters before hand-editing lint
  failures; then fix what remains
- Keep CI workflows and local scripts aligned; update both together
- Use exact dependency versions when changing CI tooling pins

### Lint inventory (via `./tests/run_tests.sh lint`)

ShellCheck, shfmt (check mode), YamlLint, markdownlint, hadolint, actionlint,
JSON manifest validation (`manifest.json`), cyclomatic complexity, and
non-Markdown 140-character line-length checks.

## Mandatory Test and Coverage Gates

- Run tests through `./scripts/run_local_tests.ps1` for local parity with CI
- Maintain at least **90%** total coverage for Bash product paths
- Regenerate coverage outputs when behavior changes
- Coverage badge is **not** updated by CI alone; commit `assets/coverage.svg`
  when coverage changes (`tests/transform_coverage.py`, usually via the local
  PowerShell runner)
- Keep fixing until lint, tests, and coverage are green — do not stop after the
  first failure report, and never loosen safety checks or suppressions to make
  gates pass

### Test layout

- `tests/unit/` — script logic and edge cases (includes `host_check_test.bats`)
- `tests/component/` — install/uninstall and integration interactions
- `tests/e2e/` — end-to-end workflow simulation

## Cross-Platform Compatibility

Development is mixed Windows/Linux.

- Prefer cross-platform-safe mocks
- Do not mock Unix-only primitives (`os.mknod`, `signal.SIGKILL`, etc.) without
  platform guards
- Prefer behavior-level mocks over low-level OS primitives
- Condition platform-specific assumptions on `sys.platform` when Python helpers
  are involved

## Firmware Safety Invariants

These rules apply to any change that touches update feasibility or execution.
Detail and procedures live in `.github/skills/host-check-update-safety/SKILL.md`.

### Two-path feasibility model

1. **Preferred**: if `ha` CLI is available, query supervisor firmware status
   (`ha os boards raspberrypi firmware`) and honor supervisor block fields
2. **Fallback**: local EEPROM query plus model/boot-device checks when `ha` is
   missing or HA query/parse fails for monitor mode

### Fail-closed update mode

- In `--update` mode, abort with non-zero status when blocked or when readiness
  cannot be trusted (HA parse failure, missing tools, blocked boot device)
- Never apply firmware to “make tests pass” or to simplify error handling

### Official update path

- Prefer `ha os boards raspberrypi firmware update && ha host reboot` when `ha`
  is present; otherwise `rpi-eeprom-update -a && reboot`
- Update and reboot must stay chained with `&&` so reboot depends on update
  success
- Background via `nohup`; return quickly for HA’s shell-command timeout
- Log outputs and status to `/var/log/pi_firmware_update.log`

### Pi 3/4-family SSD/NVMe boot block (fallback path)

On Raspberry Pi 3/4 family (including CM3/CM4, CM4S, Pi 400), non-mmcblk /
non-loop / non-overlay boot devices are blocked. Reported reasons include:

- `unsupported_boot_device_nvme`
- `unsupported_boot_device_ssd`
- `unsupported_boot_device`

Other fail-closed fallback reasons include `rpi_eeprom_update_missing`,
`eeprom_query_failed`, and `eeprom_version_parse_error`. Unblocked reason is
`None`.

### Monitor output contract

- Keep `emit_summary` / HA-formatted lines parseable by YAML sensors
- Preserve fields: `current_version`, `latest_version`, `update_available`,
  `update_blocked`, `blocked_reason`
- Respect Home Assistant’s **255-character** state limit; put verbose detail in
  attributes

## Home Assistant Contract Stability

Do not rename or remove without an explicit migration request:

- Entity: `sensor.pi_firmware_monitor`
- Action: `INSTALL_PI_FIRMWARE`
- Attributes: `update_blocked`, `blocked_reason`, version attributes used by
  notifications
- Shell command / script wiring used by apply + action handler paths
- Include structure documented in README configuration snippets

Blocked UX must remain explicit on both dashboard persistent notification and
mobile action paths (`Upgrade Blocked` state).

YAML edit procedures: `.github/skills/ha-yaml-integration-edits/SKILL.md`.

## Install / Uninstall Invariants

- SSH to host on port **22222**; RSA key flow expected by the integration
- Setup must be idempotent (re-run must not corrupt keys/YAML)
- Host authorization must use a restricted `authorized_keys` entry:
  `restrict,from="127.0.0.1",command="/root/.pi_firmware_updater/ssh_wrapper.sh"`
  with key comment / marker `pi_firmware_updater`
- The host wrapper allowlists only fixed ops: `pi_firmware_check`,
  `pi_firmware_update`, `pi_firmware_uninstall`, and `exit` — never execute
  caller stdin as a shell program; never allowlist deploy/upload ops
- Host file deployment and auth upsert use the **password bootstrap channel**
  on port 22222 (separate from the restricted integration key)
- Managed `authorized_keys` cleanup matches **key blob + wrapper path** (never
  comment-only deletion of unrelated admin keys)
- Re-running install must refresh host `host_check.sh`, wrapper, and restricted
  `authorized_keys` via password bootstrap
- If `id_rsa` exists without `id_rsa.pub`, regenerate the pub via `ssh-keygen -y`
  or abort before host authorization; reject empty/malformed pubs before remote
  mutation
- Uninstall must attempt host cleanup even when the local private key is absent
  (try `pi_firmware_uninstall` when key present; otherwise/after failure try
  password-bootstrap cleanup); missing-key or failed cleanup is incomplete:
  emit manual remediation and exit non-zero while still continuing local
  key/YAML cleanup (safe to re-run)
- Host cleanup (when key present) prefers `pi_firmware_uninstall` **before**
  deleting local keys
- Mobile notify ID injection targets only intended placeholders in
  `update_notification.yaml` and `action_handler.yaml`
- Uninstall reverts integration-owned notify actions; do not delete unrelated
  user content
- Treat `/config/.ssh/id_rsa` as sensitive (included in HA backups by default)

Procedures: `.github/skills/install-uninstall-script-maintenance/SKILL.md`.

## Command Execution

1. Prefer repository scripts from the repo root
2. Run lint before chasing test failures
3. Stream command output live in the CLI so progress is visible
4. Keep fixing until `./tests/run_tests.sh lint` and
   `./scripts/run_local_tests.ps1` succeed with coverage ≥ 90%
5. Prefer focused edits over broad refactors on fix-only requests

## Always Update Agent Docs

**Mandatory on every change** that alters project rules, workflows, safety
behavior, HA contracts, install semantics, or validation commands:

- Update root `AGENTS.md` when law/invariants change
- Update the relevant skill under `.github/skills/*/SKILL.md`
- Update workflows under `.agent/workflows/` when the procedure changes
- Update thin sidecars only when routing or short summaries would otherwise lie

Treat stale agent docs as incomplete work (same as missing tests or a stale
coverage badge). Capture new invariants, failure modes, preferred commands, and
do/don’t lessons — not a changelog dump.

## Agent Modes and Skills

Mode registry: `.agent/agents.md`

| Mode | Entry |
| --- | --- |
| Explore | `.agent/workflows/explore.md` |
| Fix | `.agent/workflows/fix.md` + `ha-firmware-fix-pass` |
| Pipeline | `.github/skills/pipeline-runner/SKILL.md` |
| YAML Integration | `ha-yaml-integration-edits` |
| Host Safety | `host-check-update-safety` |
| Installer Maintenance | `install-uninstall-script-maintenance` |
| Test Authoring | `bats-kcov-test-authoring` |
| Release | `.agent/workflows/release.md` + `release-doc-and-badge-update` |
| PR comments | `.github/skills/resolve-pr-comments/SKILL.md` |

Skills index: `.github/skills/README.md`

### Core customization files

- `.github/instructions/project.instructions.md` (+ file-scoped siblings)
- `.github/agents/project.agent.md`
- `.github/prompts/project.prompt.md`
- `.github/copilot-instructions.md`
- `.agent/agents.md`
- `.agent/workflows/*.md`

## Standard Usage

- Lint and format gate: `./tests/run_tests.sh lint`
- Full local validation: `./scripts/run_local_tests.ps1`
