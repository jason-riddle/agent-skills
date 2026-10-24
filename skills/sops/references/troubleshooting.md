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

## Gotchas

- **Represent multiple `.sops.yaml` recipients as a YAML sequence, one key per item.** SOPS 3.13.3 tests confirmed this works for age and SSH recipients, including comments between sequence items. In that version, a folded scalar with recipients separated only by newlines silently became one recipient; a comment inside the scalar became recipient text. A single-line comma-separated string is also supported.
- **Choose input type from the content, not the filename suffix.** For encrypted files with ambiguous suffixes such as `.env.enc`, identify the actual format and pass the matching `--input-type` to `sops updatekeys` or decrypt operations; an `.enc` extension does not imply binary.
- **`--age` does not bypass `.sops.yaml` path matching in the recorded examples.** A missing rule can produce `error loading config: no matching creation rules found` even with explicit recipients. Inspect the actual input path, content format and intended rule. Stop for review of an exact-path correction; do not evade the configured policy by changing directories, renaming secret files or adding a catch-all rule.
- **`sops updatekeys` applies `.sops.yaml` path matching to the encrypted filename it operates on.** A rule matching plaintext `\.env$` does not match `.env.enc`; likewise, `values\.ya?ml$` does not match `values.enc.yaml`. Include patterns for the encrypted paths when using `updatekeys`, while preserving any rules needed for encrypting plaintext files. With SOPS 3.13.3, `SOPS_CONFIG=/path/to/config sops updatekeys --yes --input-type FORMAT FILE` worked; `--config` after the `updatekeys` subcommand was rejected in the tested version.
- **Binary format (`--input-type binary --output-type binary`) stores metadata as JSON appended to the blob.** Unlike YAML/JSON formats where the `sops:` block is at the bottom of a text file, binary format embeds a JSON object at the end of the binary data. To extract recipient info, find the last `{` byte in the file and parse forward as JSON:
  ```python
  import json
  with open('secrets.enc', 'rb') as f:
      data = f.read()
  for i in range(len(data) - 1, -1, -1):
      if data[i:i+1] == b'{':
          try:
              meta = json.loads(data[i:])
              if 'sops' in meta:
                  recipients = meta['sops'].get('age', [])
                  print(f"{len(recipients)} recipients")
                  break
          except json.JSONDecodeError:
              continue
  ```
- **If no available key can decrypt a file, stop and locate an authorized matching identity before changing it.** SOPS encrypts the data key to each recipient; without a matching private key the existing payload cannot be rewrapped. Do not replace it with guessed or placeholder plaintext. The encrypted file's metadata lists recipients; compare them to verified public-key fingerprints without exposing plaintext.
- `sops --decrypt` emits plaintext to stdout: never run it bare in an agent tool. Pipe directly to the approved non-logging consumer. If persistent plaintext is separately approved, use its verified owner-only absolute destination outside Git, not a relative output path or decryption `--in-place`.
- `sops secrets.yaml` (no flags) opens the file for interactive editing. In a non-interactive agent context, always use `--decrypt`, `--encrypt`, or `--extract` explicitly.
- The `sops` metadata block at the bottom of every file (`sops:` key in YAML) is always stored in plaintext. Sensitive key metadata (key ARNs, age recipients, full SSH public keys) is visible to anyone with file access.
- `encrypted_regex` in `.sops.yaml` controls which keys are encrypted. Keys not matching the regex are stored in plaintext — useful for non-secret config alongside secrets, but easy to misconfigure.
- sops uses the data key to encrypt values; the data key itself is encrypted by each recipient key. Rotating (`--rotate`) generates a new data key and re-encrypts all values.
- AWS KMS requires valid AWS credentials at both encrypt and decrypt time.
- `sops updatekeys` re-encrypts the data key for all recipients currently listed in `.sops.yaml`. When keys change it shows a diff and prompts `Is this okay? (y/n)` — only after exact-file/recipient-diff approval may automation skip the prompt with `sops updatekeys --yes secrets.yaml`; `--yes` is never consent. Prints `File <path> already up to date` if nothing changed.
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

sops prints all env-var locations it searched. The full lookup order (including
silent auto-discovery) is documented in the
[Key lookup order](age-ssh.md#key-lookup-order) section.
Treat recorded lookup/version behavior as guidance to verify against the
installed version, not permission to search arbitrary private identities.

Workaround: set `SOPS_AGE_KEY_FILE` (for age keys) or
`SOPS_AGE_SSH_PRIVATE_KEY_FILE` (for SSH keys) explicitly:

```bash
# For age keys
SOPS_AGE_KEY_FILE=/path/to/key.txt sops --decrypt secrets.yaml | approved-consumer

# For SSH keys
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 sops --decrypt secrets.yaml | approved-consumer
```

### `SOPS_SSH_PRIVATE_KEY_FILE` is silently ignored

The correct variable is `SOPS_AGE_SSH_PRIVATE_KEY_FILE`. The version missing
`_AGE_` is not recognized and produces no warning — sops just falls through to
auto-discovery and then fails if `~/.ssh/id_ed25519` is absent or wrong.

### Unsupported SSH key type

`ecdsa-sha2-nistp256` and other non-`ed25519`/`rsa` SSH key types produce:

```
failed to parse input, unknown recipient type: "ecdsa-sha2-nistp256 ..."
```

Use an approved `ssh-ed25519` or `ssh-rsa` identity. If none is available,
stop for separately authorized key provisioning and protection policy; do not
generate an unprotected replacement as automatic recovery.

### Passphrase-protected key in non-interactive context

Fails with: `standard input is not a terminal, and /dev/tty is not available: open /dev/tty: no such device or address`

Stop and arrange an authorized interactive unlock or managed-key workflow.
Do not remove the passphrase, export a private key, or assume an SSH agent can
satisfy SOPS without checking the installed version's supported integration.

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
case`. Confirm `sops --version` and supported behavior; if an upgrade is
needed, report it for approval rather than installing as an implicit repair.

### Authorized recipient migrations

Do not collect a system-wide union of recipients or give every key access to
every file. Establish the approved file-to-recipient mapping with the owner;
keep unrelated files and recipient policies unchanged. Review the exact
`.sops.yaml` rules and encrypted file paths before any scoped `updatekeys` or
rotation. A failed decryption is not authorization to widen access.

If no authorized available identity can decrypt an existing file, **stop and
preserve its ciphertext byte-for-byte**. Report the blocker using public
recipient metadata only. Do not declare the secret permanently lost merely
because this host lacks a key; another authorized identity or backup may exist.
Do not overwrite it with guessed or placeholder plaintext, regenerate it, or
remove its recipients. Recovery or replacement requires a separate owner-approved
plan that preserves the original ciphertext.

For an approved migration with a working identity, process one exact file at a
time. Preserve a private recovery copy of ciphertext, retain the content format,
review the recipient diff, and verify authorized decryption and payload equality
without printing plaintext or secret-derived hashes. Stop on the first failure;
never continue a batch with unverified output. `--yes` skips a prompt only after
the exact recipient/file change has been approved.

### `.sops.yaml` creation rules match against the filename sops operates on

`path_regex` is matched against the path of the file sops is reading/writing,
not against a separate `--output` target. If you pass `--output /tmp/out.yaml`
with an input file named `secrets.yaml`, sops matches the rule against
`secrets.yaml`, not `/tmp/out.yaml`.

When generating ciphertext via `--output`, review the rule against the actual
input path. Do not copy plaintext into the repository ciphertext filename to
force a match. If temporary plaintext is explicitly approved, use an owner-only
location outside Git and review a narrowly scoped rule/configuration that matches
that input; write only encrypted output to the approved repository destination.
Preserve existing ciphertext until encryption and authorized verification succeed.

### dotenv input/output format

An earlier report of a dotenv metadata parse failure was not reproduced in an
isolated SOPS 3.13.3 roundtrip test containing comments and a blank value; that
test preserved the file byte-for-byte. Explicitly select `--input-type dotenv`
and `--output-type dotenv` when the content is dotenv, and test against the
installed SOPS version before relying on behavior across versions.
