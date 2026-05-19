---
name: sops
description: >
  Use this skill when encrypting, decrypting, editing, or managing secrets with
  `sops` (Secrets OPerationS). Triggers on requests like "encrypt a file with
  sops", "decrypt a sops-encrypted file", "edit secrets in sops", "rotate sops
  keys", "add a key to a sops file", "use SSH keys with sops", or any task
  involving sops-managed secrets — including YAML, JSON, ENV, and INI file
  formats, and any combination of age, SSH keys, PGP, AWS KMS, GCP KMS, or
  Azure Key Vault backends.
---

# sops

Encrypt, decrypt, and manage secrets files using `sops`.

## Orientation

Run the following commands before proceeding:

```bash
which -a sops
which sops
sops --version
sops --help
```

## Workflow

1. Confirm the tool is present: `sops --version`
2. Review flags: `sops --help`
3. Encrypt a file: `sops --encrypt --in-place secrets.yaml`
4. Decrypt a file: `sops --decrypt secrets.yaml`
5. Edit in place (decrypts, opens editor, re-encrypts on save): `sops secrets.yaml`
6. Rotate data key: `sops --rotate --in-place secrets.yaml`

## Key Backends

sops supports multiple key providers. Identify which is in use before operating:

```bash
# Inspect the sops metadata block to see which keys are configured
# The sops: block at the bottom of every file is always stored in plaintext
grep "recipient:" secrets.yaml
```

### age (most common for local/agent use)

```bash
# Generate a new age key
age-keygen -o key.txt

# Export the public key for .sops.yaml
cat key.txt | grep 'public key'

# Decrypt with a specific key file
SOPS_AGE_KEY_FILE=key.txt sops --decrypt secrets.yaml

# Or set the key directly
SOPS_AGE_KEY="AGE-SECRET-KEY-..." sops --decrypt secrets.yaml
```

### SSH keys as age recipients (sops v3.9.1+, reliable v3.13.1+)

sops supports using SSH public keys (`ssh-ed25519`, `ssh-rsa`) directly as age
recipients — no need to generate a separate age key if you already have SSH keys.

**Only `ssh-ed25519` and `ssh-rsa` are supported. `ecdsa-sha2-nistp256` and
other key types are not supported and will produce an error.**

**Version warning**: Although SSH recipient support was introduced in v3.9.1,
versions prior to v3.13.1 may reject SSH keys with `malformed recipient: mixed
case` even for valid `ssh-ed25519` keys. Install v3.13.1+ for reliable SSH key
support.

#### Encrypting with an SSH public key

```bash
# Pass the SSH public key string directly as the --age recipient
sops --encrypt --age "ssh-ed25519 AAAA... user@host" --in-place secrets.yaml

# The comment (user@host) is optional — key type + key data is sufficient
sops --encrypt --age "ssh-ed25519 AAAA..." --in-place secrets.yaml

# RSA also works
sops --encrypt --age "ssh-rsa AAAA..." --in-place secrets.yaml

# Multiple recipients: SSH key + age key (comma-separated)
sops --encrypt --age "ssh-ed25519 AAAA...,age1xxx..." --in-place secrets.yaml
```

The full public key string is stored in plaintext in the `recipient:` field of
the encrypted file's `sops:` metadata block.

#### Decrypting with an SSH private key

sops auto-discovers SSH private keys for decryption in this order:

1. `SOPS_AGE_SSH_PRIVATE_KEY_FILE` environment variable (explicit path)
2. `SOPS_AGE_SSH_PRIVATE_KEY_CMD` environment variable (command whose stdout is the SSH key)
3. `~/.ssh/id_ed25519`
4. `~/.ssh/id_rsa`

```bash
# Auto-discovery (uses ~/.ssh/id_ed25519 or ~/.ssh/id_rsa automatically)
sops --decrypt secrets.yaml

# Explicit key file via env var
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 sops --decrypt secrets.yaml

# Point to a non-default key location
SOPS_AGE_SSH_PRIVATE_KEY_FILE=/path/to/custom_key sops --decrypt secrets.yaml
```

#### Using SSH keys in .sops.yaml

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@host"
  # Mix SSH and age keys as multiple recipients (comma-separated)
  - path_regex: shared/.*\.yaml$
    age: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...,age1xxx..."
```

#### Passphrase-protected SSH keys

sops will prompt for the passphrase interactively. In non-interactive / agent
contexts (no terminal), decryption with a passphrase-protected key will fail
with:

```
failed to obtain passphrase: could not read passphrase for "<path>":
standard input is not a terminal, and /dev/tty is not available: open /dev/tty: no such device or address
```

Use an unprotected key (or one loaded into `ssh-agent`) for automated contexts.

### PGP / GPG

```bash
# Encrypt with a GPG key fingerprint
sops --encrypt --pgp <FINGERPRINT> secrets.yaml

# List available GPG keys
gpg --list-secret-keys --keyid-format LONG
```

### AWS KMS

```bash
# Encrypt with a KMS key ARN
sops --encrypt --kms arn:aws:kms:us-east-1:123456789012:key/... secrets.yaml

# Ensure AWS credentials are set (env vars or ~/.aws/credentials)
aws sts get-caller-identity
```

## .sops.yaml Configuration

Use a `.sops.yaml` file at the project root to specify default key rules so you
don't have to pass flags every time:

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: .*\.env$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    # Optional: restrict which keys get encrypted (default: encrypt all)
    encrypted_regex: "^(password|token|secret|key|credential)$"
```

Check for an existing `.sops.yaml`:

```bash
ls .sops.yaml 2>/dev/null && cat .sops.yaml
```

## Common Operations

### Encrypt a new file

```bash
# With .sops.yaml configured (picks up rules automatically)
sops --encrypt --in-place secrets.yaml

# Explicitly specifying an age recipient
sops --encrypt --age age1xxx... --output secrets.enc.yaml secrets.yaml
```

### Decrypt to stdout (never writes plaintext to disk)

```bash
sops --decrypt secrets.yaml
```

### Extract a single value

```bash
sops --decrypt --extract '["database"]["password"]' secrets.yaml
```

### Add a new key recipient

```bash
# Edit the sops metadata to add a recipient, then rotate
sops --rotate --add-age age1newrecipient... --in-place secrets.yaml
```

### Remove a key recipient

```bash
sops --rotate --rm-age age1oldrecipient... --in-place secrets.yaml
```

### Update keys (re-encrypt with current .sops.yaml rules)

```bash
# Interactive: shows diff of key changes and prompts "Is this okay? (y/n)"
sops updatekeys secrets.yaml

# Non-interactive (automation / scripts) — skip the prompt
sops updatekeys --yes secrets.yaml
```

Prints `File <path> already up to date` if the keys already match `.sops.yaml`.

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
sops --decrypt secrets.yaml
```

### Key lookup order

sops searches for age private keys in this order and uses the first match:

1. `SOPS_AGE_SSH_PRIVATE_KEY_FILE` (explicit path to SSH private key)
2. `SOPS_AGE_SSH_PRIVATE_KEY_CMD` (command whose stdout is the SSH private key)
3. `~/.ssh/id_ed25519` (SSH auto-discovery)
4. `SOPS_AGE_KEY` (raw age key material, inline)
5. `SOPS_AGE_KEY_FILE` (path to age identity file)
6. `SOPS_AGE_KEY_CMD` (command whose stdout is the age key)
7. `~/.config/sops/age/keys.txt` (default location — no env var needed)
8. `~/.ssh/id_rsa` (SSH auto-discovery fallback)

### Multiple recipients (team / multi-environment)

```bash
# In .sops.yaml — comma-separate public keys
creation_rules:
  - path_regex: .*\.yaml$
    age: >-
      age1alice...,
      age1bob...,
      age1ci...
```

```bash
# On the command line
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
    age: age1ql3z7...
```

For `.env` files, encrypt all non-comment lines:

```yaml
creation_rules:
  - path_regex: \.env.*
    encrypted_regex: "^(?!#).*"
    age: age1ql3z7...
```

### Key rotation

```bash
# Add a new recipient and rotate the data key in one step
sops --rotate --add-age age1newkey... --in-place secrets.yaml

# Remove an old recipient
sops --rotate --rm-age age1oldkey... --in-place secrets.yaml

# Re-encrypt all files after updating .sops.yaml recipients
find . -name "*.enc.yaml" | xargs -I{} sops updatekeys {}
```

### Git filter integration (auto-encrypt on commit)

Store only encrypted files in git; decrypt transparently on checkout:

```bash
# scripts/encrypt.sh
export SOPS_AGE_RECIPIENTS=$(<public-age-keys.txt)
sops --encrypt --input-type yaml --output-type yaml --age "$SOPS_AGE_RECIPIENTS" "$1"

# scripts/decrypt.sh
export SOPS_AGE_KEY_FILE=$(pwd)/secrets/age-key.txt
sops --decrypt --input-type yaml --output-type yaml "$1"

# Configure the git filter
git config --local filter.sops.smudge "$(pwd)/scripts/decrypt.sh %f"
git config --local filter.sops.clean  "$(pwd)/scripts/encrypt.sh %f"
git config --local filter.sops.required true

# Enable for specific files via .gitattributes
echo 'secrets.yaml filter=sops' >> .gitattributes
```

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

## sops + pgp

PGP (via `gpg`) is a well-established sops backend, useful when age is not
available or when GPG key infrastructure is already in place. sops delegates
all PGP operations to the system's `gpg` binary and `gpg-agent`.

### Quick setup

```bash
# 1. Generate a dedicated GPG key (batch mode, no passphrase, RSA 4096)
cat > /tmp/sops-keygen.conf << EOF
%echo Generating sops PGP key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Subkey-Usage: encrypt
Name-Real: sops-secrets
Name-Comment: sops encryption key
Name-Email: sops@local
Expire-Date: 0
%no-protection
%commit
%echo done
EOF
gpg --batch --generate-key /tmp/sops-keygen.conf
rm /tmp/sops-keygen.conf

# 2. Get the full fingerprint (40 hex characters, no spaces)
gpg --list-keys --fingerprint sops@local
# Copy the fingerprint line, e.g.:
#   Key fingerprint = AABB CCDD EEFF 0011 2233  4455 6677 8899 AABB CCDD
# Strip spaces: AABBCCDDEEFF00112233445566778899AABBCCDD

FP="AABBCCDDEEFF00112233445566778899AABBCCDD"   # replace with yours

# 3. Create .sops.yaml in the repo root
cat > .sops.yaml << EOF
creation_rules:
  - path_regex: .*\.yaml$
    pgp: "$FP"
EOF

# 4. Encrypt
sops --encrypt --in-place secrets.yaml

# 5. Decrypt (sops invokes gpg, which uses the keyring at ~/.gnupg)
sops --decrypt secrets.yaml
```

### Key lookup

sops invokes the system `gpg` binary for all PGP operations. GPG reads keys
from the keyring directory controlled by the `GNUPGHOME` environment variable
(default: `~/.gnupg`). To use an isolated or custom keyring:

```bash
# Point sops/gpg at a custom keyring directory
export GNUPGHOME=/path/to/custom/gnupg-dir
sops --decrypt secrets.yaml
```

Decryption requires the GPG secret key corresponding to the fingerprint stored
in the file's `sops:` metadata block to be present in `GNUPGHOME`.

### Multiple recipients

Comma-separate fingerprints in `.sops.yaml`. sops encrypts the data key to
every listed fingerprint; any holder of a matching secret key can decrypt.

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    pgp: >-
      AABBCCDDEEFF00112233445566778899AABBCCDD,
      1122334455667788990011AABBCCDDEEFF001122,
      FFEEDDCCBBAA99887766554433221100FFEEDDCC
```

```bash
# On the command line (comma-separated, no spaces around commas)
sops --encrypt --pgp "FP1,FP2,FP3" --in-place secrets.yaml
```

### Partial encryption with encrypted_regex

```yaml
creation_rules:
  - path_regex: .*\.yaml$
    encrypted_regex: "^(password|api_key|token|secret|credential)$"
    pgp: "AABBCCDDEEFF00112233445566778899AABBCCDD"
```

### Key rotation

```bash
# Add a new PGP recipient and rotate the data key in one step
sops --rotate --add-pgp NEWFINGERPRINT --in-place secrets.yaml

# Remove an old PGP recipient
sops --rotate --rm-pgp OLDFINGERPRINT --in-place secrets.yaml

# Re-encrypt all files after updating .sops.yaml recipients
find . -name "*.yaml" | xargs -I{} sops updatekeys --yes {}
```

### Exporting and sharing keys

Distribute the public key so other machines can encrypt to this recipient.
The private key is required for decryption and must be imported on every
machine that needs to decrypt.

```bash
# Export public key (safe to share / commit)
gpg --export --armor sops@local > sops-public.asc

# Export private key (keep secret — store outside the repo)
gpg --export-secret-keys --armor sops@local > sops-private.asc

# Import on another machine
gpg --import sops-public.asc
gpg --import sops-private.asc

# Verify import
gpg --list-secret-keys --fingerprint sops@local
```

### gpg-agent and passphrase handling

sops delegates decryption to `gpg`, which uses `gpg-agent` for passphrase
caching. A running `gpg-agent` is started automatically by modern `gpg`
installations on first use.

Keys generated with `%no-protection` (no passphrase) work without any
interaction. For passphrase-protected keys in non-interactive / CI contexts:

```bash
# Set GPG_TTY so gpg-agent can prompt on the right terminal
export GPG_TTY=$(tty)
sops --decrypt secrets.yaml

# Confirm gpg-agent is running
gpg-connect-agent /bye
```

In headless environments where no TTY is available, `gpg-agent` will fail to
prompt for a passphrase. Use passphrase-free keys or pre-cache the passphrase
with `gpg-preset-passphrase` before invoking sops.

## Gotchas

- `sops --decrypt` prints to stdout; use `--output file.yaml` or `--in-place` to write to disk. Writing decrypted secrets to disk is usually undesirable — prefer stdout piped directly to the consuming process.
- `sops secrets.yaml` (no flags) opens the file for interactive editing. In a non-interactive agent context, always use `--decrypt`, `--encrypt`, or `--extract` explicitly.
- The `sops` metadata block at the bottom of every file (`sops:` key in YAML) is always stored in plaintext. Sensitive key metadata (key ARNs, age recipients, full SSH public keys) is visible to anyone with file access.
- `encrypted_regex` in `.sops.yaml` controls which keys are encrypted. Keys not matching the regex are stored in plaintext — useful for non-secret config alongside secrets, but easy to misconfigure.
- sops uses the data key to encrypt values; the data key itself is encrypted by each recipient key. Rotating (`--rotate`) generates a new data key and re-encrypts all values.
- AWS KMS requires valid AWS credentials at both encrypt and decrypt time.
- `sops updatekeys` re-encrypts the data key for all recipients currently listed in `.sops.yaml`. When keys change it shows a diff and prompts `Is this okay? (y/n)` — pass `--yes` to skip in automation: `sops updatekeys --yes secrets.yaml`. Prints `File <path> already up to date` if nothing changed.
- `sops --encrypt` without `--age`, `--kms`, etc. and without a matching `.sops.yaml` rule prints: `config file not found, or has no creation rules, and no keys provided through command line options` — not an encryption failure; it means no key was configured.

## Troubleshooting: sops + age

### "no identity matched any of the recipients"

The key you are presenting does not match any recipient in the file. Distinct
from a missing key error. Check which recipients are in the file:

```bash
grep "recipient:" secrets.yaml
```

Then verify your key's public key matches one of those recipients:

```bash
age-keygen -y ~/.config/sops/age/keys.txt
# or
age-keygen -y "$SOPS_AGE_KEY_FILE"
```

### Key not found / verbose "did not find keys" error

sops prints all locations it searched. The full lookup order is:
`SOPS_AGE_SSH_PRIVATE_KEY_FILE`, `SOPS_AGE_SSH_PRIVATE_KEY_CMD`,
`SOPS_AGE_KEY`, `SOPS_AGE_KEY_CMD`, `SOPS_AGE_KEY_FILE`,
`~/.config/sops/age/keys.txt`, `~/.ssh/id_ed25519`, `~/.ssh/id_rsa`.

Workaround: set `SOPS_AGE_KEY_FILE` explicitly to the correct path:

```bash
SOPS_AGE_KEY_FILE=/path/to/key.txt sops --decrypt secrets.yaml
```

The full lookup order (from the error message) is:
`SOPS_AGE_SSH_PRIVATE_KEY_FILE`, `SOPS_AGE_SSH_PRIVATE_KEY_CMD`,
`~/.ssh/id_ed25519`, `SOPS_AGE_KEY`, `SOPS_AGE_KEY_FILE`,
`SOPS_AGE_KEY_CMD`, `~/.config/sops/age/keys.txt`, `~/.ssh/id_rsa`.

### `SOPS_SSH_PRIVATE_KEY_FILE` is silently ignored

The correct variable is `SOPS_AGE_SSH_PRIVATE_KEY_FILE`. The version missing
`_AGE_` is not recognized and produces no warning — sops just falls through to
auto-discovery and then fails if `~/.ssh/id_ed25519` is absent or wrong.

### Unsupported SSH key type

`ecdsa-sha2-nistp256` and other non-`ed25519`/`rsa` SSH key types produce:

```
failed to parse input, unknown recipient type: "ecdsa-sha2-nistp256 ..."
```

Use `ssh-ed25519` (preferred) or `ssh-rsa`. Generate a new key if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_sops -N ""
```

### Passphrase-protected key in non-interactive context

Fails with: `standard input is not a terminal, and /dev/tty is not available: open /dev/tty: no such device or address`

Options:
- Use a key without a passphrase for automation.
- Load the key into `ssh-agent` before running sops:
  ```bash
  ssh-add ~/.ssh/id_ed25519
  # sops will use the agent automatically
  ```

### `exec-env` fails with "cannot use complex value in environment"

`sops exec-env` only works with flat (non-nested) top-level keys. Nested YAML
like `database: {host: ...}` cannot be flattened into env vars. Restructure the
secrets file to use flat keys (`DB_HOST`, `DB_PASSWORD`) or use `--extract` to
pull individual values.

### `.env` files: values not encrypted

If `encrypted_regex: "^(?!#).*"` is set but values appear in plaintext after
encrypt, check the `sops_unencrypted_suffix` field in the file. sops `.env`
format stores metadata as `sops_*` lines appended to the file — the plaintext
appearance is correct; the actual value lines are encrypted.

### "config file not found, or has no creation rules, and no keys provided"

No `.sops.yaml` matching the file path, and no `--age` / `--kms` flag passed.
Either add a matching `creation_rules` entry to `.sops.yaml` or pass `--age`
explicitly:

```bash
sops --encrypt --age age1ql3z7... secrets.yaml
```

### sops version check

SSH recipient support (`ssh-ed25519`, `ssh-rsa`) was introduced in **sops
v3.9.1** but is unreliable before **v3.13.1**. Versions in the v3.9.x–v3.12.x
range may reject valid `ssh-ed25519` keys with `malformed recipient: mixed
case`. Always install v3.13.1+ when using SSH keys as recipients.
Always confirm: `sops --version`.

### `.sops.yaml` creation rules match against the filename sops operates on

`path_regex` is matched against the path of the file sops is reading/writing,
not against a separate `--output` target. If you pass `--output /tmp/out.yaml`
with an input file named `secrets.yaml`, sops matches the rule against
`secrets.yaml`, not `/tmp/out.yaml`.

Consequence: when generating an encrypted file via `--output`, the *input*
filename must match the creation rule, OR write the plaintext to the final
destination filename first and then `--encrypt --in-place`:

```bash
# WRONG: rule for \.env\.enc\.yaml$ won't match /tmp/plain.yaml
sops --encrypt --output .env.enc.yaml /tmp/plain.yaml  # rule miss -> error

# CORRECT: write plaintext to the final name, then encrypt in-place
cp /tmp/plain.yaml .env.enc.yaml
sops --encrypt --in-place .env.enc.yaml  # rule matches .env.enc.yaml
```

### dotenv input/output format has a metadata parse bug

`sops --encrypt --input-type dotenv --output-type dotenv` appears to succeed
but the resulting file cannot be decrypted — sops fails with:

```
parsing time "" as "2006-01-02T15:04:05Z07:00": cannot parse "" as "2006"
```

**Workaround**: convert `.env` key=value pairs to a flat YAML file first, then
encrypt as YAML. Flat YAML (`KEY: value`) works reliably and can be sourced
back as environment variables via `sops exec-env` or manual export.

```bash
# Convert .env to flat YAML, then encrypt
grep -E '^[A-Z_]+=' .env | python3 -c "
import sys
for line in sys.stdin:
    k, v = line.strip().split('=', 1)
    print(f'{k}: {repr(v)}')
" > secrets.enc.yaml
sops --encrypt --in-place secrets.enc.yaml
```

## Reference

- `man sops` — may not be present; use `sops --help` and `sops <subcommand> --help` as the primary reference.
- `sops --version` — confirm binary is present and note version before troubleshooting.
- `sops filestatus <file>` — quick check whether a file is encrypted.
