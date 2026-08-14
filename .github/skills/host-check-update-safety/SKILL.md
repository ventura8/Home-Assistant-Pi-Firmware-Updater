---
name: host-check-update-safety
description: "Implement or review host_check.sh update safety logic. Use for HA OS board-status checks, SSD/NVMe boot blocking on Pi 3/4 family, fail-closed update behavior, and guarded update+reboot command chains."
argument-hint: "Change request or bug in host_check.sh feasibility logic"
---

# Host Check Update Safety

Safety-critical playbook for `custom_components/pi_firmware_updater/host_check.sh`.
Project law: `AGENTS.md`. Human detail: `docs/integration_logic.md`.

## When to Use

- Edits in `host_check.sh`
- Bugs in update blocking, feasibility checks, or update execution flow
- Any request affecting `blocked_reason`, `update_blocked`, or fallback detection

## Hard Rules

- Prefer HA CLI path when `ha` is available; honor supervisor block fields
- Fail closed in `--update` when blocked or readiness is untrusted
- Keep update and reboot chained with `&&`
- Keep monitor lines parseable by YAML sensors
- Never remove Pi 3/4-family SSD/NVMe boot blocking without an explicit,
  documented migration request
- Update unit tests in the same change set

## Feasibility Model

### Preferred path (HA CLI)

1. `command -v ha` succeeds
2. Query firmware status (raw JSON) with a short timeout
3. Require `result == ok` and payload keys:
   `current_version`, `latest_version`, `update_available`, `update_blocked`,
   `blocked_reason`
4. Types must be valid (non-empty version strings, bools for available/blocked,
   non-empty reason string)
5. Emit compact summary compatible with sensor parsing

If query or parse fails in **check** mode, fall through to local fallback.
If readiness cannot be validated in **update** mode, abort with exit status `1`.

### Fallback path (local)

1. Load EEPROM versions via `rpi-eeprom-update` (or emit blocked reasons on tool /
   query / parse failure)
2. Run `check_ssd_boot` / `classify_boot_device` for Pi 3/4-family models
3. Emit blocked or allowed summary; unblocked reason is `None`

### Update mode

- HA present: `validate_ha_update_readiness` then background
  `ha os boards raspberrypi firmware update && ha host reboot`
- HA absent: `validate_fallback_update_readiness` then background
  `rpi-eeprom-update -a && reboot`
- Launch with `nohup`; append logs to `/var/log/pi_firmware_update.log`
- Return quickly so Home Assistant shell commands do not time out waiting for
  reboot

## Blocked Reason Tokens

Stable tokens agents and YAML must continue to understand:

| Token | Meaning |
| --- | --- |
| `None` | Not blocked |
| `unsupported_boot_device_nvme` | Pi 3/4-family NVMe boot block |
| `unsupported_boot_device_ssd` | Pi 3/4-family USB/SSD-class boot block |
| `unsupported_boot_device` | Other unsupported / unknown boot device |
| `rpi_eeprom_update_missing` | Fallback tool missing |
| `eeprom_query_failed` | EEPROM query timed out or failed |
| `eeprom_version_parse_error` | Could not parse EEPROM versions |

Pi 3/4-family model match includes Raspberry Pi 3/4, Compute Module 3/4, and
Pi 400 (`model_requires_boot_block`). Allowed boot classes include mmcblk, loop,
and overlay paths; empty device classifies as unsupported.

## Procedure

1. Confirm current behavior against `docs/integration_logic.md` and existing
   tests in `tests/unit/host_check_test.bats` before changing logic
2. Preserve the two-path model and fail-closed `--update` semantics
3. Keep `emit_summary` field names and ordering stable unless sensors are updated
   in the same change set
4. Add or update Bats coverage for both success and blocked/fail-closed paths
5. Run `./tests/run_tests.sh lint` then `./scripts/run_local_tests.ps1`
6. If user-visible block reasons or UX change, update README/docs and agent docs

## Regression Checklist

- [ ] Pi 3/4-family SSD and NVMe boot block still enforced on fallback path
- [ ] HA CLI path still honors `update_blocked: true` from supervisor
- [ ] Missing/invalid HA JSON does not apply firmware in `--update`
- [ ] Non-blocked devices still report current/latest correctly
- [ ] Update+reboot remains `&&`-chained and backgrounded
- [ ] Monitor output still parseable by `command_line_sensors.yaml` /
      `template_sensors.yaml`
- [ ] Coverage stays ≥ 90%; badge updated if coverage moved

## Do / Don’t

### Do

- Fail closed on unknown or unparseable feasibility
- Keep background logging for post-mortem on real devices
- Mirror new branches with unit tests

### Don't

- Soften blocks to green tests
- Reboot without successful update (`|| reboot`, separate unguarded reboot, etc.)
- Change token strings casually — sensors and notifications may display them
- Drop required HA JSON keys from the parser without coordinated YAML updates

## Related

- Skill: `ha-yaml-integration-edits` for sensor/automation consumers
- Skill: `bats-kcov-test-authoring` for test placement
- Optional token table companion: keep this skill as SSOT unless a
  `reference.md` is added later for large expansions
