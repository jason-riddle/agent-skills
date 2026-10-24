Read [the entry safety gates](../SKILL.md#safety-gates) first. These are
task-selected examples, not a setup checklist or authorization. Check
installed help before relying on version-specific behavior. Never send
decrypted values/private keys to tool output; pipe to the approved consumer
or use an approved owner-only destination outside Git. Key generation,
exports, passphrase policy, filters and recipient changes need explicit scope.

`approved-consumer` below is a placeholder for the specifically approved process,
not a command to run as-is. Verify that it accepts stdin and does not echo, log or
include secrets in errors. Use pipeline failure checks. Do not route secret bytes
through `cat`/`tee`, command substitution, tracing or captured tool output. Review
both producer and consumer stderr handling before agent use; potentially sensitive
diagnostics belong only in a separately approved private destination, with only
sanitized status reported. Do not put raw keys in command arguments, inline
environment assignments, shell history or logs.
If a plaintext file is necessary, separately approve its exact absolute path in
an owner-only directory outside Git and verify private ownership/mode; never
use decryption `--in-place` on repository ciphertext. `--yes` is never consent:
approve the exact file and recipient diff before any noninteractive key update.

## sops + age

age is the simplest and most portable sops backend. No cloud dependencies, no
GPG keyring — just a key file.

### Quick setup

```bash
# 1. Generate a dedicated sops age key
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
# Public key is printed to stderr — copy it for .sops.yaml

# 2. Get the public key at any time
age-keygen -y ~/.config/sops/age/keys.txt

# 3. Create .sops.yaml in the repo root
cat > .sops.yaml << EOF
creation_rules:
  - path_regex: .*\.yaml$
    age: age1ql3z7...   # paste public key here
EOF

# 4. Encrypt
sops --encrypt --in-place secrets.yaml

# 5. Decrypt (sops finds key at ~/.config/sops/age/keys.txt automatically)
sops --decrypt secrets.yaml | approved-consumer
```

### Key lookup order

sops searches for private keys (both SSH and age) in this order and uses the
first match:

1. `SOPS_AGE_SSH_PRIVATE_KEY_FILE` — explicit path to SSH private key
2. `SOPS_AGE_SSH_PRIVATE_KEY_CMD` — command whose stdout is the SSH private key
3. `SOPS_AGE_KEY` — raw age key material; do not set inline or print it.
   Prefer an approved identity-file path instead.
4. `SOPS_AGE_KEY_FILE` — path to age identity file
5. `SOPS_AGE_KEY_CMD` — command whose stdout is the age key
6. `~/.config/sops/age/keys.txt` — default age key location (no env var needed)
7. `~/.ssh/id_ed25519` — SSH auto-discovery (ed25519)
8. `~/.ssh/id_rsa` — SSH auto-discovery fallback (RSA)

Note: the SOPS error message only lists the env-var locations (items 1–5).
Auto-discovery paths (items 6–8) are tried silently after the env-var checks.
If decryption fails with "no identity matched any of the recipients," verify
your key is at one of the auto-discovery paths or set an env var explicitly.

### Multiple recipients

Prefer a YAML sequence with one recipient per item. In SOPS 3.13.3, a folded
scalar (`>-`) with multiple keys separated only by newlines was parsed as one
recipient, so the additional key could not decrypt. A `#` line inside that
scalar was also treated as recipient text. Comma-separated recipients on one
line remain supported.

```yaml
# CORRECT — one recipient per YAML sequence item
creation_rules:
  - path_regex: .*\.yaml$
    age:
      - age1alice...
      - age1bob...
      - age1ci...
  # SSH recipients
  - path_regex: .*\.env$
    age:
      - ssh-ed25519 AAAA...
      - ssh-ed25519 BBBB...
  # Mix age and SSH recipients
  - path_regex: .*\.env$
    age:
      - age1xxx...
      - ssh-ed25519 AAAA...
```

```bash
# On the command line (also comma-separated)
sops --encrypt --age "age1alice...,age1bob..." -o secrets.enc.yaml secrets.yaml
```

### SOPS_AGE_RECIPIENTS env var (alternative to --age flag)

```bash
export SOPS_AGE_RECIPIENTS="age1alice...,age1bob..."
sops --encrypt secrets.yaml   # uses SOPS_AGE_RECIPIENTS automatically
```

### Partial encryption with encrypted_regex

Encrypt only the sensitive keys; leave non-sensitive values readable in diffs:

```yaml
creation_rules:
  - path_regex: .*\.yaml$
    encrypted_regex: "^(password|api_key|token|secret|credential)$"
    age: "age1ql3z7..."
```

For `.env` files, encrypt all non-comment lines:

```yaml
creation_rules:
  - path_regex: \.env.*
    encrypted_regex: "^(?!#).*"
    age: "age1ql3z7..."
```

### Two approaches: SSH keys vs age keys

**Approach 1: SSH keys (no new keys to generate)**

If you already have an `ssh-ed25519` key pair at `~/.ssh/id_ed25519`, use it
directly — no need to install or generate a separate age key:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: .*\.yaml$
    age: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@host"
```

```bash
# Encrypt and decrypt — sops auto-discovers ~/.ssh/id_ed25519
sops --encrypt --in-place secrets.yaml
sops --decrypt secrets.yaml | approved-consumer
```

Works with `ssh-rsa` keys too, but `ssh-ed25519` is preferred. Only
`ssh-ed25519` and `ssh-rsa` are supported — `ecdsa` and other types produce
errors.

**Approach 2: Dedicated age key (no SSH key required)**

Generate a standalone age key pair — useful if you don't want to tie sops to
your SSH keys, or for CI/automation:

```bash
# Generate a key pair
age-keygen -o ~/.config/sops/age/keys.txt
# Public key is printed to stderr — copy it for .sops.yaml

# Or retrieve the public key later:
age-keygen -y ~/.config/sops/age/keys.txt
```

```yaml
# .sops.yaml
creation_rules:
  - path_regex: .*\.yaml$
    age: "age1ql3z7..."
```

```bash
# Encrypt and decrypt — sops auto-discovers ~/.config/sops/age/keys.txt
sops --encrypt --in-place secrets.yaml
sops --decrypt secrets.yaml | approved-consumer
```

Both approaches support auto-discovery, explicit env vars, and mixing keys
for multiple recipients. Choose based on whether you want to reuse SSH keys
or keep sops keys separate.

### Key rotation

```bash
# Add a new recipient and rotate the data key in one step
sops --rotate --add-age age1newkey... --in-place secrets.yaml

# Remove an old recipient
sops --rotate --rm-age age1oldkey... --in-place secrets.yaml

# After approval, update one exact encrypted file and verify before continuing
sops updatekeys path/to/approved.enc.yaml
```

### Git filter integration

A decrypting smudge filter writes plaintext into a repository working tree and
can expose it through diffs or tool output. Do not configure or test such a
filter under this skill's outside-Git plaintext boundary. Keep ciphertext in
Git and pipe decryption directly to the approved consumer instead. Any different
workflow requires separate review of its storage, permissions and disclosure
policy; encryption approval alone does not authorize installing a filter.

### Run a command with secrets in the environment

```bash
# Inject flat (non-nested) YAML keys as env vars
sops exec-env flat_secrets.enc.yaml 'your-command'

# sops exec-env fails on nested YAML keys:
# "cannot use complex value in environment; offending key <key>"
# Use a flat top-level structure (DB_HOST: val, not database: {host: val})
```

### Check encryption status

```bash
sops filestatus secrets.yaml
# {"encrypted":true} or {"encrypted":false}
```
