---
name: 1password
description: >
  Use this skill when working with the 1Password CLI (`op`) — managing secrets,
  vaults, items, accounts, or injecting credentials. Triggers on requests like
  "get a secret from 1Password", "sign in to op", "list vaults", "create an item",
  or "inject env vars from 1Password".
---

# 1Password CLI (`op`)

Interact with 1Password vaults and secrets via the `op` CLI.

## This Setup

This environment uses a **service account** for agent access. Key facts:

- **Vault:** `Automation` — the dedicated vault for agent-accessible secrets.
- **Service account token** is stored at: `op://Automation/agent-automation-token/credential`
- **Permissions:** `read_items` only. The agent cannot create or modify items.
- To write new items, the human must use an interactive session (`eval $(op signin)`) or the 1Password web UI.
- The service account was created with `--expires-in 90d` (90 days max). Check expiry if auth fails unexpectedly.

**Bootstrap pattern — always start a session this way:**

```bash
export OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://Automation/agent-automation-token/credential")
op whoami   # verify before proceeding
```

Note: to run `op read` above, `OP_SERVICE_ACCOUNT_TOKEN` must already be set in the environment. The first time (or after rotation), the human must export the token manually.

## Orientation

Run these commands first to understand the environment:

```bash
which op
op --version
op account list
op whoami
```

## Authentication

### Preferred: Service Account Token (non-interactive, works in agent sessions)

Service accounts require no interactive auth and work in headless/automated contexts.

**Setup (one-time, requires an interactive session or web UI):**

1. Create a non-built-in vault if needed (service accounts cannot access Personal/Private/Employee/Shared built-in vaults):
   ```bash
   op vault create Automation
   ```
2. Create the service account with access to that vault:
   ```bash
   op service-account create "agent-automation" --expires-in 90d --vault Automation:read_items,write_items
   ```
   - The token is shown **only once** — save it to 1Password immediately.
   - Available permissions: `read_items`, `write_items` (requires `read_items`), `share_items` (requires `read_items`)
   - Include `--can-create-vaults` if the service account needs to create vaults.

3. Save the token as an `API Credential` item in the Automation vault:
   ```bash
   eval $(op signin)
   op item create \
     --category "API Credential" \
     --title "agent-automation-token" \
     --vault Automation \
     "credential=ops_..."
   ```

4. Verify the reference works:
   ```bash
   op read "op://Automation/agent-automation-token/credential"
   ```

**Usage:**

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
op whoami        # verify
op vault list    # should list accessible vaults
```

Set `OP_SERVICE_ACCOUNT_TOKEN` in the environment before running any `op` commands. No `op signin` needed.

### Fallback: Manual session (interactive terminals only)

Not suitable for agent sessions — the session token only lives in the shell that ran `eval $(op signin)` and cannot be passed to subprocesses automatically.

```bash
eval $(op signin)
op whoami
```

Session tokens expire after 30 minutes of inactivity.

## Common Workflows

### Get a username and password

```bash
# Human-readable
op item get "Item Name" --vault VaultName

# Get just the username
op item get "Item Name" --vault VaultName --fields username

# Get just the password
op item get "Item Name" --vault VaultName --fields password

# Both as JSON
op item get "Item Name" --vault VaultName --fields username,password --format json
```

### Get a one-time password (OTP / TOTP)

```bash
# Get the current OTP code
op item get "Item Name" --vault VaultName --otp

# Or via secret reference
op read "op://VaultName/Item Name/one-time password"
```

### Read a secret by reference

```bash
op read "op://VaultName/ItemName/fieldname"

# Examples:
op read "op://Automation/MyService/password"
op read "op://Automation/MyService/username"
```

### List vaults and items

```bash
op vault list
op item list --vault VaultName
op item list --vault VaultName --format json
```

### Inject secrets into a process

```bash
# Inject as env vars using op run
op run -- env  # shows injected vars
op run -- your-command

# Inject into a config file template
op inject -i template.env -o .env
```

### Inspect item fields (without revealing values)

```bash
op item get "Item Name" --format json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for f in d.get('fields', []):
    print(f['id'], f.get('label',''), f.get('type',''))
"
```

## Token Rotation

When the token expires or is compromised:

1. Human creates a new service account (permissions are immutable — can't reuse old one):
   ```bash
   eval $(op signin)
   op service-account create "agent-automation-v2" --expires-in 90d --vault Automation:read_items,write_items
   ```
2. Save the new token to 1Password:
   ```bash
   op item edit "agent-automation-token" --vault Automation "credential=ops_NEW_TOKEN"
   ```
   Or create a new item if the old service account is being retired.
3. Update any `.env` files or shell profiles that hardcode the old token.
4. Revoke the old service account at `start.1password.com` → Developer → Service Accounts.

## Gotchas

- Service accounts **cannot** access built-in vaults: Personal, Private, Employee, or the default Shared vault. Create a dedicated vault (e.g. `Automation`) for agent-accessible secrets.
- Service account permissions and vault access are **immutable** after creation. To change them, revoke and create a new service account.
- The service account token is shown **only once** at creation — save it immediately.
- `op signin` is a no-op in headless/agent contexts when app integration (`system_auth_latest_signin`) is configured. Use `OP_SERVICE_ACCOUNT_TOKEN` instead.
- The service account in this setup has `read_items` only. Attempts to create/edit items will return a `(101) You do not have permission` error. The human must perform writes interactively.
- Every subcommand has its own `--help`: `op item --help`, `op vault --help`, etc.
- `op run -- <command>` injects secrets as env vars; use `op inject` for config file templating.
- `op --version` must be 2.18.0 or later for service account support.
- Never paste or log the token in plaintext — treat it like a password.

## Reference

- No `man op` available; use `op --help` and `op <subcommand> --help` as the primary reference.
- Service account docs: https://developer.1password.com/docs/service-accounts/get-started/
