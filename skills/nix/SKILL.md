---
name: nix
description: >
  Use this skill when working with the Nix package manager — installing
  packages, managing profiles, building derivations, or using nix flakes.
  Triggers on requests like "install with nix", "nix-env", "nix shell",
  "nix build", "nix flake", or any Nix package/environment management task.
---

# nix

Manage packages and environments using the `nix` CLI.

## Orientation

You must run the following commands before proceeding:

```bash
which -a nix
which nix
nix --version
nix --help
```

## Workflow

1. Confirm the tool is present: `nix --version`
2. Review subcommands: `nix --help`
3. Run a package without installing: `nix run nixpkgs#<package>`
4. Open a shell with packages: `nix shell nixpkgs#<package>`
5. Install to profile: `nix profile install nixpkgs#<package>`
6. Build a derivation: `nix build`
7. Update flake inputs: `nix flake update`

## Installing Unfree Packages

Some packages (e.g. `1password-cli`, `vscode`, `slack`) have unfree licenses and are blocked by default.

### The problem

The modern `nix` CLI (flake-based) runs in **pure evaluation mode** by default, which means:
- `~/.config/nixpkgs/config.nix` with `{ allowUnfree = true; }` is **ignored**
- `--option nixpkgs-config ...` is **not a recognized setting**
- The `NIXPKGS_ALLOW_UNFREE` env var is only read in `--impure` mode

### The solution

Always pass `--impure` when installing unfree packages:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure nixpkgs#<package>
```

Or, if `NIXPKGS_ALLOW_UNFREE=1` is already set in your shell environment (e.g. `.bashrc`):

```bash
nix profile add --impure nixpkgs#<package>
```

> **Note:** `--impure` is the critical flag — without it, nix ignores environment variables entirely.

### What doesn't work

| Method | Works? |
|---|---|
| `~/.config/nixpkgs/config.nix` `{ allowUnfree = true; }` | No — ignored by flake CLI |
| `--option nixpkgs-config '{ allowUnfree = true; }'` | No — unknown setting |
| `NIXPKGS_ALLOW_UNFREE=1` without `--impure` | No — env vars ignored in pure mode |
| `NIXPKGS_ALLOW_UNFREE=1` **with** `--impure` | **Yes** |

## Gotchas

- `nix --version` shows both Nix and (if Determinate Nix) the distribution version.
- Each subcommand has its own help: `nix run --help`, `nix shell --help`, etc.
- Experimental features (`nix flake`, `nix profile`) may require `--extra-experimental-features` on older installs.

## Reference

- `man nix` — may not be present on all installs; use `nix --help` and `nix <subcommand> --help` as the primary reference.
