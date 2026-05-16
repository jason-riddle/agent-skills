---
name: gpg
description: >
  Use this skill when encrypting, decrypting, signing, or verifying files and
  data with GPG (GnuPG / PGP). Triggers on requests like "encrypt a file with
  GPG", "decrypt a PGP message", "sign a file with GPG", "verify a GPG
  signature", "generate a GPG key", "export a public key", "import a GPG key",
  "manage the GPG keyring", "set key trust", "revoke a key", or any GPG/PGP
  key management or cryptography task.
---

# gpg

Encrypt, decrypt, sign, verify, and manage keys using `gpg` (GnuPG).

## Orientation

Run the following commands before proceeding:

```bash
which -a gpg
which gpg
gpg --version
gpg --list-keys
gpg --list-secret-keys
```

## Key Generation

### Non-interactive (batch mode — preferred in agent contexts)

```bash
cat > keygen-batch.txt << 'EOF'
%no-protection
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Subkey-Type: RSA
Subkey-Length: 4096
Subkey-Usage: encrypt
Name-Real: Alice Smith
Name-Email: alice@example.com
Expire-Date: 1y
%commit
EOF

gpg --batch --generate-key keygen-batch.txt
```

Notes:
- `%no-protection` omits a passphrase. Remove it to prompt for one (interactive only).
- `ed25519`/`cv25519` key types in batch mode require GnuPG 2.3+; fall back to `RSA` if the batch file errors with `invalid algorithm`.
- A revocation certificate is automatically saved to `~/.gnupg/openpgp-revocs.d/<FINGERPRINT>.rev` on creation.

### Interactive (full key generation)

```bash
gpg --full-generate-key
```

## Listing Keys

```bash
# Public keys (human-readable)
gpg --list-keys
gpg --list-keys --keyid-format LONG
gpg --list-keys --with-fingerprint

# Secret keys
gpg --list-secret-keys --keyid-format LONG

# Machine-readable colon-delimited output
gpg --list-keys --with-colons

# Extract key ID from colon output
gpg --list-keys --with-colons | awk -F: '/^pub/{print $5}'

# Extract fingerprint from colon output
gpg --list-keys --with-colons | awk -F: '/^fpr/{print $10}'
```

## Key Import and Export

```bash
# Export public key (ASCII armored)
gpg --export --armor alice@example.com > alice-pub.asc
gpg --export --armor <FINGERPRINT> > key.asc

# Export secret key (keep secure — treat like a password)
gpg --export-secret-keys --armor alice@example.com > alice-sec.asc

# Import a key
gpg --import alice-pub.asc

# Extract public key(s) from a secret key file
gpg --import alice-sec.asc   # imports both pub and sec
```

## Trust

```bash
# Set ultimate trust non-interactively (use for your own keys after import)
echo "<FINGERPRINT>:6:" | gpg --import-ownertrust

# Export current trust assignments (for backup/migration)
gpg --export-ownertrust > ownertrust.txt
gpg --import-ownertrust < ownertrust.txt
```

Trust values: `2`=unknown, `3`=untrusted, `4`=marginal, `5`=full, `6`=ultimate.

`gpg --edit-key` trust prompts require an interactive terminal — use `--import-ownertrust` for non-interactive contexts.

## Encryption

```bash
# Encrypt to a recipient (by email or fingerprint)
gpg --encrypt --recipient alice@example.com --armor input.txt > encrypted.asc

# Encrypt to a file (binary)
gpg --encrypt --recipient alice@example.com -o encrypted.gpg input.txt

# Encrypt to multiple recipients
gpg --encrypt --recipient alice@example.com --recipient bob@example.com input.txt

# Symmetric encryption (passphrase only, no key needed)
gpg --symmetric --armor --batch --passphrase "yourpass" -o encrypted.asc input.txt

# Encrypt and sign in one step
gpg --encrypt --sign --recipient alice@example.com --armor input.txt
```

## Decryption

```bash
# Decrypt to stdout
gpg --decrypt encrypted.asc

# Decrypt to file
gpg --decrypt -o output.txt encrypted.gpg

# Decrypt symmetric (non-interactive)
gpg --decrypt --batch --passphrase "yourpass" encrypted.asc

# Pipe decrypt
cat encrypted.asc | gpg --decrypt
```

## Signing and Verification

```bash
# Clearsign — plaintext with embedded signature (readable without gpg)
echo "message" | gpg --clearsign > signed.asc

# Detached signature — separate .sig/.asc file alongside original
gpg --detach-sign --armor file.txt        # produces file.txt.asc
gpg --verify file.txt.asc file.txt

# Binary signature
gpg --sign -o file.txt.gpg file.txt
gpg --verify file.txt.gpg

# Specify signing key explicitly
gpg --clearsign --default-key <FINGERPRINT> file.txt
```

## Key Deletion

```bash
# Must delete secret key before public key
gpg --delete-secret-keys --batch --yes <FINGERPRINT>
gpg --delete-key --batch --yes <FINGERPRINT>

# Delete both in one command
gpg --delete-secret-and-public-key --batch --yes <FINGERPRINT>
```

## Key Expiry

```bash
# Set expiry non-interactively (requires GnuPG 2.1.22+)
gpg --quick-set-expire <FINGERPRINT> 1y
gpg --quick-set-expire <FINGERPRINT> 0        # never expires
```

## Keyserver Operations

```bash
# Send public key to a keyserver
gpg --keyserver keys.openpgp.org --send-keys <FINGERPRINT>

# Search keyserver
gpg --keyserver keys.openpgp.org --search-keys alice@example.com

# Receive a key by fingerprint
gpg --keyserver keys.openpgp.org --recv-keys <FINGERPRINT>
```

Keyserver operations require network access and `dirmngr` to be running. Failures here do not affect local keyring operations.

## gpg-agent

```bash
# Restart gpg-agent (fixes most "server older than us" warnings)
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

# Kill all GnuPG daemons
gpgconf --kill all

# List socket and directory locations
gpgconf --list-dirs
```

## Non-Interactive / Agent Context Tips

- Pass `--batch --yes` to suppress interactive prompts.
- Use `--no-tty` when running in environments without a terminal.
- Use `--passphrase` or `--passphrase-fd 0` to supply passphrases non-interactively (only works with `--batch`).
- Use `--trust-model always` to bypass trust prompts when encrypting to imported keys that haven't been trusted yet.
- Use `--status-fd 1` to get machine-readable `[GNUPG:]` status tokens on stdout.

## gpg + sops

`gpg` keys can be used as sops recipients. Quick start:

```bash
# 1. Get your full fingerprint
gpg --list-keys --fingerprint you@example.com
# Copy the 40-character hex fingerprint (remove spaces)

# 2. Create .sops.yaml at the repo root
cat > .sops.yaml << EOF
creation_rules:
  - path_regex: .*\.yaml$
    pgp: "AABBCCDDEEFF00112233445566778899AABBCCDD"
EOF

# 3. Encrypt a file
sops --encrypt --in-place secrets.yaml

# 4. Decrypt a file
sops --decrypt secrets.yaml
```

The secret key must be present in the GPG keyring (`~/.gnupg` or `$GNUPGHOME`)
on any machine that needs to decrypt.

See the `sops` skill for full workflows: multiple recipients, key rotation,
`encrypted_regex`, and CI/non-interactive passphrase handling.

## Gotchas

- **`gpg --delete-key` fails if a secret key exists.** Delete the secret key first with `--delete-secret-keys`, or use `--delete-secret-and-public-key`.
- **`gpg --edit-key` requires an interactive terminal** for trust and expiry changes. Use `--import-ownertrust` and `--quick-set-expire` instead.
- **The `gpg-agent` version mismatch warning** (`server 'gpg-agent' is older than us`) is cosmetic when the installed gpg was updated but the running agent is stale. Fix with `gpgconf --kill gpg-agent`.
- **`problem with fast path key listing: IPC parameter error`** is a known issue when `gpg` and `gpg-agent` versions differ. Restart the agent to suppress it.
- **Encrypting to an unknown recipient** (not in keyring) fails with `No data` — import the recipient's public key first.
- **Revocation certificates are auto-generated** at `~/.gnupg/openpgp-revocs.d/<FINGERPRINT>.rev` on key creation. Back them up separately.
- **`--batch --generate-key` does not support `ed25519`/`cv25519`** on GnuPG < 2.3. Use `RSA` in batch files for wider compatibility; use `--full-generate-key` interactively for modern key types.
- **Secret key export contains the private key in plaintext** (when `%no-protection` was used). Treat it like a password and never commit it to a repository.
- **Short key IDs (8 hex chars) are insecure** — different keys can share the same short ID. Always use full fingerprints or long key IDs.

## Reference

- `man gpg` — primary flag and option reference.
- `man gpg-agent` — agent configuration and pinentry options.
- `gpgconf --list-dirs` — socket and homedir locations.
- `gpg --dump-options` — full list of all available options.
