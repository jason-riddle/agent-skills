---
name: nix
description: >
  Use this skill when working with the Nix package manager — installing
  packages, managing profiles, building derivations, or using nix flakes.
  Triggers on requests like "install with nix", "nix-env", "nix shell",
  "nix build", "nix flake", or any Nix package/environment management task.
---

# nix

Manage packages and environments using the `nix` CLI.

## Orientation

You must run the following commands before proceeding:

```bash
which -a nix
which nix
nix --version
nix --help
```

## Workflow

1. Confirm the tool is present: `nix --version`
2. Review subcommands: `nix --help`
3. Run a package without installing: `nix run nixpkgs#<package>`
4. Open a shell with packages: `nix shell nixpkgs#<package>`
5. Install to profile: `nix profile install nixpkgs#<package>`
6. Build a derivation: `nix build`
7. Update flake inputs: `nix flake update`

## Installing Unfree Packages

Some packages (e.g. `1password-cli`, `vscode`, `slack`) have unfree licenses and are blocked by default.

### The problem

The modern `nix` CLI (flake-based) runs in **pure evaluation mode** by default, which means:
- `~/.config/nixpkgs/config.nix` with `{ allowUnfree = true; }` is **ignored**
- `--option nixpkgs-config ...` is **not a recognized setting**
- The `NIXPKGS_ALLOW_UNFREE` env var is only read in `--impure` mode

### The solution

Always pass `--impure` when installing unfree packages:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure nixpkgs#<package>
```

Or, if `NIXPKGS_ALLOW_UNFREE=1` is already set in your shell environment (e.g. `.bashrc`):

```bash
nix profile add --impure nixpkgs#<package>
```

> **Note:** `--impure` is the critical flag — without it, nix ignores environment variables entirely.

### What doesn't work

| Method | Works? |
|---|---|
| `~/.config/nixpkgs/config.nix` `{ allowUnfree = true; }` | No — ignored by flake CLI |
| `--option nixpkgs-config '{ allowUnfree = true; }'` | No — unknown setting |
| `NIXPKGS_ALLOW_UNFREE=1` without `--impure` | No — env vars ignored in pure mode |
| `NIXPKGS_ALLOW_UNFREE=1` **with** `--impure` | **Yes** |

## Gotchas

- `nix --version` shows both Nix and (if Determinate Nix) the distribution version.
- Each subcommand has its own help: `nix run --help`, `nix shell --help`, etc.
- Experimental features (`nix flake`, `nix profile`) may require `--extra-experimental-features` on older installs.
- **`nix profile upgrade '<name>'` uses the package's display name, not the flake attribute.** The profile list shows `Name:` (e.g. `devenv`) and `Flake attribute:` (e.g. `legacyPackages.x86_64-linux.devenv`). Use the simple `Name` value: `nix profile upgrade devenv`. Passing `packages.x86_64-linux.devenv` or `legacyPackages.x86_64-linux.devenv` fails with `Package name '...' does not match any packages in the profile`.
- **`nix profile list` shows `Name` and `Flake attribute` separately.** To find a package's install name for `nix profile remove` / `nix profile upgrade`, grep the `Name:` field, not the `Flake attribute:` field.

## Troubleshooting

### "the user 'nixbld1' in the group 'nixbld' does not exist"

Fatal build error on multi-user Nix installs (Determinate Nix or standard
multi-user). The `nixbld` group exists but its member user accounts are
missing from `/etc/passwd`. The daemon enumerates group members at build
time and fails on the first missing user.

**Diagnose:**

```bash
# Confirm the group exists but its members don't
getent group nixbld
# nixbld:x:30000:nixbld1,nixbld2,...,nixbld32

getent passwd nixbld1
# (empty output = user is MISSING)

# Check the installer receipt for the exact UID range
cat /nix/receipt.json | python3 -c "
import json, sys
r = json.load(sys.stdin)
for a in r.get('actions', []):
    act = a.get('action', {})
    if act.get('action_name') == 'create_users_and_group':
        print(f\"group: {act['nix_build_group_name']} gid={act['nix_build_group_id']}\")
        print(f\"users: {act['nix_build_user_count']} prefix={act['nix_build_user_prefix']}\")
        print(f\"uid range: {act['nix_build_user_id_base']+1}..{act['nix_build_user_id_base']+act['nix_build_user_count']}\")
"
```

**Fix — recreate the build users matching the receipt (requires root):**

```bash
sudo bash -c '
set -euo pipefail
for i in $(seq 1 32); do
  uid=$((30000 + i))   # adjust base/count from receipt
  username="nixbld$i"
  getent passwd "$username" >/dev/null 2>&1 || \
    useradd -c "Nix build user $i" -d /var/empty -s /sbin/nologin \
            -g nixbld -u "$uid" -r -M "$username"
done
'
sudo systemctl restart nix-daemon
```

The `useradd` warning `uid 30001 is greater than SYS_UID_MAX 999` is expected
and harmless — Determinate Nix deliberately uses UIDs in the 30000 range to
avoid collisions with system users.

**Common cause on LXC containers:** a container `passwd` reset (host
re-provisioning, image refresh, or a `userdel` sweep) can wipe the nixbld
users while leaving the `nixbld` group entry and its stale member list
behind. `/etc/passwd` mtime will be newer than the daemon's start time —
a tell-tale sign. Recreating the users is the fix; do NOT edit
`/etc/nix/nix.conf` or change `build-users-group`.

### "unknown setting 'eval-cores'" (or any newer nix setting)

Warning (non-fatal) emitted when the running nix binary is older than the
nix that wrote `/etc/nix/nix.conf`. Common scenario: the system nix is
upgraded (writing newer settings to `nix.conf`), but a bundled nix (e.g.
inside devenv) is older and doesn't recognize the setting.

**Diagnose:**

```bash
# System nix version (the one that wrote nix.conf)
nix --version

# Check which nix binary is actually emitting the warning
# (devenv bundles its own nix; it may differ from the system nix)
readlink -f $(which devenv)
ls /nix/store/*-devenv-nix-*/bin/nix   # devenv's bundled nix version
```

If devenv's bundled nix is older than the system nix, upgrade devenv:

```bash
# Remove the old devenv (often installed from nixpkgs with an old bundled nix)
nix profile remove devenv

# Install the latest devenv from the official cachix/devenv flake
# (nixpkgs devenv lags behind; the cachix flake has the newest bundled nix)
nix profile install github:cachix/devenv#devenv --accept-flake-config
```

**Do NOT edit `/etc/nix/nix.conf`** to remove the setting — on Determinate
Nix installs the file is managed (header: `managed by Determinate; do not
modify`) and will be rewritten on the next Determinate upgrade. Fix the
bundled-nix-version mismatch instead.

### devenv 2.x requires explicit git-hooks flake input

devenv 1.x bundled `git-hooks.nix` as a built-in module. devenv 2.x
requires it as an explicit flake input in `devenv.yaml`. After upgrading
devenv 1.x → 2.x, `devenv print-dev-env` fails with:

```
Failed assertions:
 - To use 'git-hooks', run the following command:
     $ devenv inputs add git-hooks github:cachix/git-hooks.nix --follows nixpkgs
```

**Fix:**

```bash
devenv inputs add git-hooks github:cachix/git-hooks.nix --follows nixpkgs
```

This adds the `git-hooks` input to `devenv.yaml` with `nixpkgs` following
the existing nixpkgs input. No changes to `devenv.nix` are needed — the
`git-hooks.hooks.*` configuration works as before.

### Determinate Nix: daemon is socket-activated

On Determinate Nix installs, `nix-daemon.service` may show `disabled` even
when it's running. This is normal — it's socket-activated under
`determinate-nixd.socket`. Check the socket unit instead:

```bash
systemctl is-active nix-daemon.socket    # active
systemctl is-enabled nix-daemon.socket   # enabled
systemctl is-active nix-daemon           # active (but shows disabled for enable)
```

After modifying build users or nix config, restart with
`sudo systemctl restart nix-daemon` (the socket stays open; the daemon
process restarts).

### Recovering the build-user config from the installer receipt

Determinate Nix writes a full installation receipt to `/nix/receipt.json`.
This is the authoritative source for the expected build-user names, UIDs,
group name, and group GID. When recreating missing users, always match
the receipt exactly rather than guessing:

```bash
python3 << 'PYEOF'
import json
with open('/nix/receipt.json') as f:
    r = json.load(f)
for a in r.get('actions', []):
    act = a.get('action', {})
    if act.get('action_name') == 'create_users_and_group':
        for u in act.get('create_users', []):
            ua = u.get('action', {})
            print(f"{ua['name']}: uid={ua['uid']} gid={ua['gid']} comment='{ua['comment']}'")
PYEOF
```

The receipt also records the `state` of each action (`Completed`,
`Uncompleted`), which tells you whether the installer itself succeeded for
each user — useful for diagnosing partial-install failures.

## Reference

- `man nix` — may not be present on all installs; use `nix --help` and `nix <subcommand> --help` as the primary reference.
