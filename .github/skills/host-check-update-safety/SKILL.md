---
name: host-check-update-safety
description: "Implement or review host_check.sh update safety logic. Use for HA OS board-status checks, SSD/NVMe boot blocking on Pi 3/4 family, fail-closed update behavior, and guarded update+reboot command chains."
argument-hint: "Change request or bug in host_check.sh feasibility logic"
---

# Host Check Update Safety

## When to Use
- Edits in custom_components/pi_firmware_updater/host_check.sh.
- Bugs in update blocking, feasibility checks, or update execution flow.
- Any request affecting blocked_reason, update_blocked, or fallback detection behavior.

## Procedure
1. Confirm current behavior against docs/integration_logic.md before changing logic.
2. Preserve the two-path feasibility model:
   - Preferred path: query supervisor API via ha CLI.
   - Fallback path: local model and boot-device checks.
3. Preserve safety policy:
   - If feasibility status cannot be trusted, fail closed.
   - In --update mode, abort with non-zero status when blocked or unknown.
4. Keep official update path guarded:
   - Update command and reboot chained with && so reboot depends on update success.
   - Background execution returns quickly and logs outputs/status in /var/log/pi_firmware_update.log.
5. Ensure monitor-facing output remains parseable by YAML sensors.
6. Update or add tests in tests/unit/host_check_test.bats and broader suites as needed.

## Regression Checklist
- Pi 3/4-family SSD and NVMe boot block remains enforced.
- Non-blocked devices still report current/latest values correctly.
- Update mode never applies firmware when blocked or query parsing fails.
