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

# SOPS

Use SOPS for structured-secret encryption and recipient management. Load
`secret-stewardship` when choosing stores, recovery policy or delivery boundaries;
use `age` or `gpg` for their standalone key operations. Do not merge those scopes
or treat an encryption task as permission to redesign secret storage.

## Safety gates

- Confirm the exact files, operation, intended consumer and approved recipients
  before reading secret material or changing anything. Read owning repository
  guidance and exact target status; stop on unexpected changes or unclear ownership.
- Inspect only necessary public metadata first. Never print plaintext, private
  keys, tokens or secret-derived verification hashes in chat, logs or tool output.
  Decryption to stdout is safe only when piped directly to the approved consumer,
  not captured by the agent. Any required plaintext destination must be explicitly
  approved, owner-only and outside Git; avoid persistent plaintext by default.
- If no authorized identity can decrypt, **stop and preserve the original
  ciphertext byte-for-byte**. Do not create placeholder/guessed plaintext, overwrite
  the encrypted file, remove recipients or widen access as recovery. Report the
  missing authorized identity without exposing secrets; lack of a local key does
  not establish permanent loss.
- Recipient changes, key generation/export, rotation, passphrase-policy changes,
  Git filters and persistent secret delivery each need their own approved scope.
  Do not union all discovered recipients across files. `--yes` is not consent.
- Preserve key protection and access boundaries when automation cannot unlock a
  key. Do not strip passphrases, make an unprotected replacement or bypass path
  rules to unblock a command. Ask for an approved recovery/unlock plan.

## Workflow

1. Identify the installed binary/version and read `sops --help` plus the relevant
   subcommand help. Do not install or upgrade as an implicit prerequisite.
2. Determine the file's actual content format, encryption status and public
   recipient metadata. `.enc` does not mean binary; use the matching explicit
   input/output type when ambiguous. `sops filestatus <file>` checks status.
3. Read existing `.sops.yaml` rules and the relevant reference below. Check rules
   against the exact path the operation uses; do not broaden a regex or change
   recipients silently. Preserve unrelated configuration.
4. Choose only the requested operation. For an approved change to existing
   ciphertext, retain a private recovery copy, process one exact file at a time,
   and inspect the recipient/config diff before mutation.
5. Verify encryption status, intended recipient access and payload preservation
   without exposing secret values. Stop on the first failure and preserve the
   original. Report paths, actions and verification limits, not secret contents.

## Load only the needed reference

- [Operations and configuration](references/operations.md): basic backend
  selection, `.sops.yaml`, encrypt/edit/decrypt/extract and scoped recipient updates.
- [age and SSH](references/age-ssh.md): authorized setup, recipient syntax,
  identity lookup, rotation, Git-filter and environment-delivery examples.
- [PGP](references/pgp.md): approved GPG-backed setup, keyring, export/import
  and unlock handling; standalone key setup remains a separately gated task.
- [Troubleshooting](references/troubleshooting.md): format/path matching,
  missing identities, passphrase failures and safe recipient migration.

These references retain recorded version-specific examples; verify installed
behavior before acting. They do not authorize a blanket setup or migration.
