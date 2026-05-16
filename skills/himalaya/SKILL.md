---
name: himalaya
description: >
  Use this skill when managing emails from the command line with `himalaya` —
  reading, writing, sending, searching, or organizing messages and folders.
  Triggers on requests like "check my email", "send an email", "list messages",
  "search inbox", "download attachments", "manage email accounts", or any
  email task using the himalaya CLI.
---

# himalaya

Manage emails from the command line using the `himalaya` CLI.

## Orientation

Run the following commands before proceeding:

```bash
which -a himalaya
which himalaya
himalaya --version
himalaya --help
```

## Workflow

1. Confirm the tool is present: `himalaya --version`
2. Review subcommands: `himalaya --help`
3. List configured accounts: `himalaya account list`
4. List folders/mailboxes: `himalaya folder list`
5. List envelopes in inbox: `himalaya envelope list`
6. Read a message: `himalaya message read <id>`
7. Write and send a message: `himalaya message write`
8. Search messages: `himalaya envelope list --filter "subject:foo"`
9. Download attachments: `himalaya attachment download <id>`

## Common Workflows

### List messages in a folder

```bash
# List inbox (default)
himalaya envelope list

# List a specific folder
himalaya envelope list --folder Sent

# Output as JSON
himalaya -o json envelope list
```

### Read a message

```bash
himalaya message read <id>
himalaya message read <id> --folder Sent
```

### Send a message

```bash
# Interactive compose
himalaya message write

# Send from a file
himalaya message send < message.eml
```

### Manage folders

```bash
himalaya folder list
himalaya folder create "Archive"
himalaya folder purge "Trash"
```

### Use a specific account

```bash
himalaya -a work envelope list
himalaya -a personal message read <id>
```

### Generate shell completions

```bash
himalaya completion bash >> ~/.bashrc
himalaya completion zsh >> ~/.zshrc
```

## Debugging Authentication

If `himalaya folder list` returns `Incorrect username, password or access token`:

1. Check the config: `cat ~/.config/himalaya/config.toml`
2. Locate the `backend.auth.raw` and `message.send.backend.auth.raw` fields — both must be updated when rotating a key.
3. Many providers (e.g. Fastmail) require an **app-specific password**, not the account login password. Generate one from the provider's security/privacy settings.
4. After updating the config, re-run `himalaya folder list` to confirm — a successful folder listing means both IMAP auth and the key are valid.
5. For deeper output, run with `--debug` or `--trace`:
   ```bash
   himalaya --debug folder list
   himalaya --trace folder list
   ```
6. If auth still fails after updating the key, verify the login field matches the full email address the app password was generated for.

## Gotchas

- The config file is typically at `~/.config/himalaya/config.toml`. If missing, himalaya will launch a setup wizard on first run.
- Multiple config files can be merged using `:` as delimiter in `--config` or `HIMALAYA_CONFIG`.
- `himalaya --version` prints the version with compiled feature flags (e.g. `+imap +smtp`); confirm required backends are compiled in.
- Each subcommand has its own help: `himalaya message --help`, `himalaya envelope --help`, etc.
- Use `-o json` for machine-readable output in scripts.
- The `manual` subcommand can generate man pages: `himalaya manual /tmp/man`.
- Both `backend.auth.raw` (IMAP) and `message.send.backend.auth.raw` (SMTP) use the same app password — update both when rotating credentials.

## Reference

- `man himalaya` — primary reference if man pages are installed.
- `himalaya --help` and `himalaya <subcommand> --help` — always available.
- `himalaya manual <dir>` — generate man pages locally.
