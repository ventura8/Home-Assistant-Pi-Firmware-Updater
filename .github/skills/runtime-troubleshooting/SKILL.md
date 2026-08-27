---
name: runtime-troubleshooting
description: >-
  Diagnose a running (already-installed) integration: SSH auth failures on
  port 22222, stuck/missing sensors, silent notifications, or a failed
  firmware update. Use when a user reports the integration misbehaving on a
  real HA instance, not when editing script logic itself.
argument-hint: "Symptom report from a live Home Assistant / Pi install"
---

# Runtime Troubleshooting

Diagnostic playbook for a deployed `pi_firmware_updater` install. Project law:
`AGENTS.md`. For changing the underlying logic (not just diagnosing it), hand
off to `host-check-update-safety`, `ha-yaml-integration-edits`, or
`install-uninstall-script-maintenance` once the root cause is known.

## When to Use

- "The sensor never updates" / "shows unknown" / "update button does nothing"
- "SSH command fails" / "permission denied" / "wrapper rejects command"
- "Firmware update ran but didn't reboot" / "log file is empty"
- Any bug report against a live install where the fix location is not yet known

## Evidence to Collect First

Ask for or inspect, in order:

1. HA logs: **Settings → System → Logs**, filtered for `pi_firmware_updater`
   or `command_line` (shell_command/sensor errors surface here, not in a
   dedicated integration log)
2. Host-side firmware log: `/var/log/pi_firmware_update.log` — empty or absent
   means **no update output was captured**, not proof that `--update` never
   launched (a backgrounded command can start silent, or a prior/cleared log
   can be ambiguous). Use HA shell_command/action result, SSH probe exit
   status, and other host-side evidence to distinguish “not launched” from
   “started but silent.”
3. Manual SSH probe from the HA host, mirroring `shell_commands.yaml` /
   `command_line_sensors.yaml`. Provision the host key in `known_hosts` first,
   then connect with host-key verification enabled (do not use
   `StrictHostKeyChecking=no` for diagnostics):

   ```bash
   ssh-keyscan -p 22222 -H <pi-host> > /tmp/pi-host.keys
   # List fingerprints; verify each out-of-band (HA host console, Pi display, or
   # another trusted channel) before trusting any key:
   ssh-keygen -lf /tmp/pi-host.keys
   # Append only key lines whose fingerprints were verified. If not every scanned
   # key is confirmed, select the matching line(s) instead of the whole file:
   #   # Replace ssh-ed25519 with the verified host-key type (ecdsa / rsa / etc.).
   #   grep ' <verified-host-key-type> ' /tmp/pi-host.keys >> /config/.ssh/known_hosts
   # Only if every fingerprint in the scan was verified may you append all lines:
   #   cat /tmp/pi-host.keys >> /config/.ssh/known_hosts
   chmod 600 /config/.ssh/known_hosts
   rm -f /tmp/pi-host.keys
   timeout 30s ssh -p 22222 \
       -o StrictHostKeyChecking=yes \
       -o UserKnownHostsFile=/config/.ssh/known_hosts \
       -i /config/.ssh/id_rsa \
       root@<pi-host> pi_firmware_check
   ```

4. Whether `/config/.ssh/id_rsa` and `id_rsa.pub` both exist and are readable
   by the HA container user

## Common Failure Modes → Likely Cause

| Symptom | Likely cause | Where to look |
| --- | --- | --- |
| `Permission denied (publickey)` | Key missing/mismatched, or `authorized_keys` entry missing/malformed on host | `install.sh` re-run; `docs/integration_logic.md` key flow |
| `pi_firmware_updater: command denied` | Caller sent something other than the four allowlisted operations (`pi_firmware_check`, `pi_firmware_update`, `pi_firmware_uninstall`, `exit`) | `ssh_wrapper.sh` — never widen the allowlist to "fix" this |
| Sensor stuck on `unknown`/`unavailable` | `command_line_sensors.yaml` command failing or timing out, or `emit_summary` fields drifted | Skill `ha-yaml-integration-edits`; verify field names against `host_check.sh` |
| Update runs, no reboot | Update command in the `&&` chain failed (check `/var/log/pi_firmware_update.log`), or `ha`/`rpi-eeprom-update` missing | Skill `host-check-update-safety` |
| Update attempted on blocked device | Should be impossible — fail-closed check bypassed or `blocked_reason` misread by caller | Treat as a safety bug, not a config issue; escalate to `host-check-update-safety` |
| Notification never fires | Action handler / notify ID wiring broken, likely stale placeholder from an install/uninstall run | Skill `install-uninstall-script-maintenance` |
| Uninstall leaves host key behind | Password-bootstrap cleanup was not attempted or failed, or host-side cleanup remained incomplete | Re-run uninstall password-bootstrap path per `install-uninstall-script-maintenance`; do not hand-delete unrelated `authorized_keys` entries |

## Hard Rules While Diagnosing

- Never suggest widening the `ssh_wrapper.sh` allowlist, disabling
  `StrictHostKeyChecking` permanently, or logging the private key to debug —
  these are safety regressions, not fixes
- Never suggest applying firmware manually to "unblock" a user without first
  confirming *why* the fallback or HA-CLI check reported blocked
- A diagnosis is not a fix: once root cause is identified, route to the
  matching skill (table above) rather than patching ad hoc in this pass

## Reporting Back

End with: symptom, root cause (or ruled-out causes if still open), evidence
consulted (log lines / commands run), and the skill to use next if a code
change is needed.

## Related

- `host-check-update-safety` — feasibility/update logic itself
- `install-uninstall-script-maintenance` — SSH/key/YAML wiring changes
- `ha-yaml-integration-edits` — sensor/automation edits once cause is known
