---
name: age
description: >
  Use this skill when encrypting or decrypting files with `age` — generating
  key pairs, encrypting to one or more recipients, decrypting with an identity
  file, or using SSH keys as recipients. Triggers on requests like "encrypt
  this file with age", "decrypt an age file", "generate an age key", "use my
  SSH key with age", or "share a secret with multiple recipients using age".
---

# age

Encrypt and decrypt files using the `age` tool.

## Orientation

Run the following commands before proceeding:

```bash
which -a age age-keygen
age --version
age-keygen --help
```

## Key Concepts

- **Recipient**: a public key (age or SSH) used to encrypt. Anyone with the matching private key can decrypt.
- **Identity**: a private key file (`-i`) used to decrypt.
- A file can have multiple recipients; any one matching identity can decrypt it.
- `age` and `age-keygen` are separate binaries; verify both are present.

## Workflow

1. Confirm the tool is present: `age --version`
2. Generate a key pair: `age-keygen -o key.txt` (prints public key to stderr; secret key goes to `key.txt`)
3. Extract just the public key: `age-keygen -y key.txt`
4. Encrypt to a recipient: `age -r <public-key> -o output.age input.txt`
5. Encrypt from stdin: `echo "secret" | age -r <public-key> > output.age`
6. Decrypt: `age -d -i key.txt -o output.txt input.age`
7. Decrypt from stdin: `age -d -i key.txt < output.age`

## Common Workflows

### Generate a key pair

```bash
# Generate and save to a file (public key printed to stderr)
age-keygen -o key.txt

# Print the public key only (useful for scripting)
age-keygen -y key.txt

# Generate a post-quantum hybrid key (ML-KEM-768 + X25519)
age-keygen -pq -o pq_key.txt
```

The key file format:
```
# created: 2026-01-01T00:00:00Z
# public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
AGE-SECRET-KEY-1...
```

### Encrypt to a single recipient

```bash
# From a file
age -r age1ql3z7... -o secret.age plaintext.txt

# From stdin
echo "my secret" | age -r age1ql3z7... > secret.age

# Armor (PEM output, safe for text/email embedding)
echo "my secret" | age -r age1ql3z7... --armor > secret.age.pem
```

### Encrypt to multiple recipients

```bash
# Inline — any recipient can decrypt
age -r age1alice... -r age1bob... -o secret.age plaintext.txt

# From a recipients file (one public key per line; # = comment)
age -R public-age-keys.txt -o secret.age plaintext.txt
```

Recipients file format:
```
# Alice
age1alice...
# Bob
age1bob...
```

### Decrypt

```bash
# To a file
age -d -i key.txt -o output.txt secret.age

# To stdout (pipe to consumer — avoids writing plaintext to disk)
age -d -i key.txt secret.age | some-command

# Multiple identity files (unused ones are silently ignored)
age -d -i key1.txt -i key2.txt secret.age
```

### Use SSH keys as recipients

`age` natively supports `ssh-ed25519` and `ssh-rsa` public keys as recipients.
`ecdsa-sha2-nistp256` and other types are **not supported** and produce an error.

```bash
# Encrypt to an SSH public key
age -r "$(cat ~/.ssh/id_ed25519.pub)" -o secret.age plaintext.txt

# Decrypt with the SSH private key
age -d -i ~/.ssh/id_ed25519 secret.age
```

### Pipe workflows (no files on disk)

```bash
# Encrypt a directory into a single encrypted archive, never touching disk
tar -czf - ~/data | age -r age1ql3z7... > backup.tar.gz.age

# Decrypt and extract directly
age -d -i key.txt backup.tar.gz.age | tar -xzf -
```

## Using age with SOPS

`age` is the most common backend for `sops`. The key integration points:

1. **Generate a dedicated age key** for sops (keep it separate from other keys):
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
   sops auto-discovers keys at `~/.config/sops/age/keys.txt` — no env var needed.

2. **Get the public key** to put in `.sops.yaml`:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   ```

3. **Add to `.sops.yaml`** at the repo root:
   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       age: "age1ql3z7..."
   ```

4. **Multiple recipients** (team members): comma-separate public keys on a
   single quoted line. **Do NOT use YAML folded scalar (`>-`)** — sops
   concatenates multi-line keys into one invalid space-joined string and
   decryption fails:
   ```yaml
   creation_rules:
     - path_regex: .*\.yaml$
       age: "age1alice...,age1bob..."
   ```

See the `sops` skill for full sops + age workflows, key rotation, and troubleshooting.

## Gotchas

- `age-keygen` with no arguments prints the full key file to stdout (including the `# public key:` comment and the `AGE-SECRET-KEY-...` line). Pass `-o` to save to a file instead; the public key is then printed to stderr.
- `age-keygen -o` will **not** overwrite an existing file — it exits with an error: `age-keygen: error: failed to open output file "key.txt": open key.txt: file exists`. This is the opposite of `age -o`, which silently overwrites.
- `age-keygen -y key.txt` converts an identity file to a recipients file (one public key per line, no comments) — useful in scripts to get the public key(s) without parsing the `# public key:` comment. A file with multiple keys produces multiple output lines.
- `ecdsa-sha2-nistp256` SSH keys produce: `age: error: unknown recipient type: "ecdsa-sha2-nistp256 ..."` — only `ssh-ed25519` and `ssh-rsa` work.
- Passphrase encryption (`-p`) requires an interactive terminal. In non-interactive/agent contexts it fails: `age: error: could not read passphrase: standard input is not a terminal, and /dev/tty is not available: open /dev/tty: no such device or address`
- Wrong key at decrypt: `age: error: no identity matched any of the recipients` — the file is intact, just the wrong key.
- Missing identity file (`-i nonexistent.txt`): `age: error: reading "nonexistent.txt": failed to open file: open nonexistent.txt: no such file or directory`
- Multiple identity files with `-i`: unused ones are silently ignored, so it is safe to pass all your keys.
- Output file (`-o`) is overwritten without warning if it already exists.

## Reference

- No `man age` on all systems; use `age --help` and `age-keygen --help` as the primary reference.
- `age --version` — confirm version; post-quantum (`-pq`) requires age v1.3+.
