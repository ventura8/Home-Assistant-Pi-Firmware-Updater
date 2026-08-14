---
name: install-uninstall-script-maintenance
description: "Maintain install.sh and uninstall.sh for secure SSH setup and rollback. Use when changing key generation, host authorization flow, mobile_app notification ID injection, or cleanup semantics."
argument-hint: "Installer or uninstaller change scope"
---

# Install and Uninstall Script Maintenance

Playbook for `custom_components/pi_firmware_updater/install.sh` and
`uninstall.sh`. Project law: `AGENTS.md`. Overview: `docs/integration_logic.md`.

## When to Use

- Changing installer or uninstaller behavior
- Modifying SSH key handling, first-time setup, or rollback
- Adjusting mobile notification ID injection into YAML

## Hard Rules

- Keep setup and teardown **idempotent**
- Preserve RSA key flow and host SSH on port **22222**
- Do not persist passwords in files
- Mutate only intended YAML placeholders for notify IDs
- Uninstall reverses integration-created state only — no unrelated user deletion
- Exit codes must reflect real success/failure
- Component tests must cover changed behavior
- Never append a bare unrestricted pubkey to host `authorized_keys`
- Host forced-command wrapper must allowlist only fixed integration commands and
  must never execute caller stdin as a shell program
- Never allowlist deploy/upload ops on the permanent integration key
- Managed `authorized_keys` removal matches key blob + wrapper path only
- Install/refresh host file deployment uses password bootstrap only

## Install Expectations

1. Resolve config / SSH directories (defaults under `/config/...`, overridable in
   tests)
2. Ensure RSA key material exists (`$SSH_DIR/id_rsa` / `id_rsa.pub`). Generate
   with comment `pi_firmware_updater`. If private exists without pub, recover via
   `ssh-keygen -y` or abort before host auth.
3. Deploy host `host_check.sh` + `ssh_wrapper.sh` under
   `/root/.pi_firmware_updater/` and upsert restricted `authorized_keys`:
   `restrict,from="127.0.0.1",command="/root/.pi_firmware_updater/ssh_wrapper.sh" ...`
   Deployment uses the **password bootstrap channel** on port 22222 (not the
   restricted integration key). The wrapper allowlist must never include deploy
   or stdin-exec operations.
4. Wrapper allowlist: `pi_firmware_check`, `pi_firmware_update`,
   `pi_firmware_uninstall`, `exit` only
5. Refresh host scripts + auth on every install run via password bootstrap
6. Prompt for or accept `notify.mobile_app_*` ID and inject into YAML placeholders
7. Print clear terminal guidance for HAOS SSH add-on prerequisites

## Uninstall Expectations

1. Always treat host cleanup as a tracked outcome:
   - If local private key exists, run `pi_firmware_uninstall` over SSH first
   - If that fails **or** the key is absent, attempt password-bootstrap cleanup
     (SSH without `-i`) that strips wrapper-path `authorized_keys` lines and
     removes `/root/.pi_firmware_updater/`
   - If both attempts fail, emit manual remediation instructions and mark
     cleanup incomplete (non-zero)
2. Continue local cleanup regardless (remove local keys when present; revert
   notify placeholders)
3. Exit non-zero when host cleanup was incomplete; remain safe to re-run
4. Do not delete the whole custom component tree or unrelated `/config` content

## Procedure

1. Read current `install.sh` / `uninstall.sh` / `ssh_wrapper.sh` and component
   tests under `tests/component/`
2. Implement the smallest change that preserves idempotency and exit-code honesty
3. Keep prompts and error strings actionable for HAOS add-on setup failures
4. Update `tests/component/install_test.bats` and
   `tests/component/uninstall_test.bats` (and e2e if workflow-visible)
5. Run lint + `./scripts/run_local_tests.ps1`
6. Update README / docs when user-facing setup steps change
7. Update agent docs when install invariants change

## Regression Checklist

- [ ] Fresh install creates usable restricted key + host wrapper on 22222
- [ ] Re-install refreshes restricted auth without corrupting keys/YAML
- [ ] Mobile ID injection only hits intended notify action lines
- [ ] Uninstall cleans host auth before deleting local keys when possible
- [ ] Missing-key / failed SSH cleanup exits non-zero after local cleanup
- [ ] Second uninstall remains safe to re-run
- [ ] No password material written to disk
- [ ] Coverage ≥ 90%; badge updated if needed

## Do / Don’t

### Do

- Fail closed when host SSH prerequisites are missing
- Keep `CONFIG_DIR` / `SSH_DIR` overridable for tests
- Mirror new branches with component/e2e coverage
- Document that `/config/.ssh/id_rsa` is backup-sensitive

### Don't

- Widen uninstall to wipe arbitrary user files
- Switch to password-based host auth in committed defaults
- Append unrestricted pubkeys or skip `from=` / forced-command restrictions
- Filter `authorized_keys` by comment text alone
- Silence incomplete host cleanup with exit 0
