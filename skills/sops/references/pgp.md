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

## sops + pgp

PGP (via `gpg`) is a well-established sops backend, useful when age is not
available or when GPG key infrastructure is already in place. sops delegates
all PGP operations to the system's `gpg` binary and `gpg-agent`.

### Approved setup

Prefer an existing approved encryption identity. If a new key is required,
load `gpg`, agree on identity, protection and recovery policy, and complete
that separately scoped setup. Do not generate an unprotected key merely to
make headless SOPS work.

1. Obtain the approved public-key fingerprint without exporting private keys.
2. Review the exact `.sops.yaml` path rule and add only that approved fingerprint,
   preserving unrelated rules. A sample rule (not a replacement for the file):

```yaml
creation_rules:
  - path_regex: secrets/approved\.yaml$
    pgp: "APPROVED_FULL_FINGERPRINT"
```

3. Encrypt only the approved file and verify with the authorized identity;
   pipe any decryption directly to the approved consumer, never tool output.

### Key lookup

sops invokes the system `gpg` binary for all PGP operations. GPG reads keys
from the keyring directory controlled by the `GNUPGHOME` environment variable
(default: `~/.gnupg`). To use an isolated or custom keyring:

```bash
# Point sops/gpg at a custom keyring directory
export GNUPGHOME=/path/to/custom/gnupg-dir
sops --decrypt secrets.yaml | approved-consumer
```

Decryption requires the GPG secret key corresponding to the fingerprint stored
in the file's `sops:` metadata block to be present in `GNUPGHOME`.

### Multiple recipients

Comma-separate fingerprints in `.sops.yaml`. sops encrypts the data key to
every listed fingerprint; any holder of a matching secret key can decrypt.

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    pgp: "AABBCCDDEEFF00112233445566778899AABBCCDD,1122334455667788990011AABBCCDDEEFF001122,FFEEDDCCBBAA99887766554433221100FFEEDDCC"
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

# After approval, update one exact encrypted file and verify before continuing
sops updatekeys path/to/approved.enc.yaml
```

### Exporting and sharing keys

Distribute the approved public key so other machines can encrypt to this
recipient. Do not export or replicate a private identity as routine setup.
Private-key export/import needs separate approval for the exact fingerprint,
destination, transfer and retention plan.

Before the private export example, set `APPROVED_PRIVATE_KEY_EXPORT` to the
approved absolute, non-existing file path in a verified owner-only directory
outside Git (directory mode `0700`, file mode `0600`). Verify real paths,
symlinks and ownership first; preserve existing files. The variables contain
paths/fingerprints, never private-key bytes. Never print or capture the exported
file; confirm its ownership/mode afterward without displaying its contents.

```bash
# Public export only; review identity/metadata before sharing or committing
gpg --export --armor "$APPROVED_FINGERPRINT" > sops-public.asc

# Separately approved private export; restrictive creation, no overwrite
(umask 077; set -C; gpg --export-secret-keys --armor "$APPROVED_FINGERPRINT" > "$APPROVED_PRIVATE_KEY_EXPORT")

# On the approved destination machine, after authorized private transfer
gpg --import sops-public.asc
gpg --import "$APPROVED_PRIVATE_KEY_EXPORT"

# Verify the selected identity without exporting private material
gpg --list-secret-keys --fingerprint "$APPROVED_FINGERPRINT"
```

### gpg-agent and passphrase handling

sops delegates decryption to `gpg`, which uses `gpg-agent` for passphrase
caching. A running `gpg-agent` is started automatically by modern `gpg`
installations on first use.

For an approved passphrase-protected identity, use an interactive terminal
when needed; do not disable protection for non-interactive / CI contexts:

```bash
# Set GPG_TTY so gpg-agent can prompt on the right terminal
export GPG_TTY=$(tty)
sops --decrypt secrets.yaml | approved-consumer

# Confirm gpg-agent is running
gpg-connect-agent /bye
```

In headless environments where no TTY is available, `gpg-agent` will fail to
prompt for a passphrase. Stop and arrange an owner-approved interactive or
managed-key workflow. Do not remove protection or cache a passphrase merely to
unblock automation.
