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

## Key Backends

sops supports multiple key providers. Identify which is in use before operating:

```bash
# Inspect the sops metadata block to see which keys are configured
# The sops: block at the bottom of every file is always stored in plaintext
grep "recipient:" secrets.yaml
```

### age (most common for local/agent use)

After separate key-generation approval, set `APPROVED_AGE_KEY_FILE` to the
verified absolute destination outside Git in an owner-only directory. Keep
private-key bytes out of commands and output; obtain only the public key with
`age-keygen -y`.

```bash
# Generate a new private identity file with restrictive permissions
(umask 077; age-keygen -o "$APPROVED_AGE_KEY_FILE")

# Output only the public recipient for .sops.yaml
age-keygen -y "$APPROVED_AGE_KEY_FILE"

# Supply a file path, never a raw private-key literal
SOPS_AGE_KEY_FILE="$APPROVED_AGE_KEY_FILE" sops --decrypt secrets.yaml | approved-consumer
```

### SSH keys as age recipients (sops v3.9.1+, reliable v3.13.1+)

sops supports using SSH public keys (`ssh-ed25519`, `ssh-rsa`) directly as age
recipients — no need to generate a separate age key if you already have SSH keys.

**Only `ssh-ed25519` and `ssh-rsa` are supported. `ecdsa-sha2-nistp256` and
other key types are not supported and will produce an error.**

**Version warning**: Although SSH recipient support was introduced in v3.9.1,
versions prior to v3.13.1 may reject SSH keys with `malformed recipient: mixed
case` even for valid `ssh-ed25519` keys. Verify installed behavior; report any
needed upgrade for approval rather than installing as an automatic repair.

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
sops --decrypt secrets.yaml | approved-consumer

# Explicit key file via env var
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 sops --decrypt secrets.yaml | approved-consumer

# Point to a non-default key location
SOPS_AGE_SSH_PRIVATE_KEY_FILE=/path/to/custom_key sops --decrypt secrets.yaml | approved-consumer
```

#### Using SSH keys in .sops.yaml

```yaml
creation_rules:
  # Single SSH key
  - path_regex: secrets/.*\.yaml$
    age: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@host"
  # Multiple SSH keys (comma-separated, single line)
  - path_regex: shared/.*\.yaml$
    age: "ssh-ed25519 AAAA...,ssh-ed25519 BBBB..."
  # Mix SSH and age keys
  - path_regex: mixed/.*\.yaml$
    age: "ssh-ed25519 AAAA...,age1xxx..."
```

The comment (`user@host`) in SSH keys is optional — key type + key data is sufficient.
See [multiple-recipient syntax](age-ssh.md#multiple-recipients)
before editing a multi-key rule.

#### Passphrase-protected SSH keys

sops will prompt for the passphrase interactively. In non-interactive / agent
contexts (no terminal), decryption with a passphrase-protected key will fail
with:

```
failed to obtain passphrase: could not read passphrase for "<path>":
standard input is not a terminal, and /dev/tty is not available: open /dev/tty: no such device or address
```

Stop if the approved identity cannot be used in this context. Arrange an
owner-approved interactive or managed-key workflow; do not strip a passphrase
or create an unprotected replacement to bypass the failure.

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
    age: "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  - path_regex: .*\.env$
    age: "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
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

### Decrypt directly to the approved consumer

```bash
sops --decrypt secrets.yaml | approved-consumer
```

### Extract a single value for the approved consumer

```bash
sops --decrypt --extract '["database"]["password"]' secrets.yaml | approved-consumer
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

# Only after approval of this exact file and recipient diff; --yes is not consent
sops updatekeys --yes secrets.yaml
```

Prints `File <path> already up to date` if the keys already match `.sops.yaml`.
