---
name: flatpak
description: >
  Use this skill when installing, removing, or managing applications with
  `flatpak`. Triggers on requests like "install a flatpak app", "list flatpak
  apps", "update flatpaks", "add a flatpak remote", or any Flatpak package
  management task.
---

# flatpak

Manage sandboxed applications using `flatpak`.

## Orientation

You must run the following commands before proceeding:

```bash
which -a flatpak
which flatpak
flatpak --version
flatpak --help
```

## Workflow

1. Confirm the tool is present: `flatpak --version`
2. Review subcommands: `flatpak --help`
3. Add a remote: `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`
4. Install an app: `flatpak install flathub <app.id>`
5. List installed: `flatpak list`
6. Update all: `flatpak update`
7. Remove an app: `flatpak uninstall <app.id>`

## Gotchas

- Each subcommand has its own help: `flatpak install --help`, `flatpak list --help`, etc.
- App IDs are reverse-DNS style (e.g., `org.mozilla.firefox`).

## Reference

- `man flatpak` — top-level reference.
- `man flatpak-install`, `man flatpak-list`, etc. — per-subcommand man pages.
