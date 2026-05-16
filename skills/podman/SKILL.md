---
name: podman
description: >
  Use this skill when building, running, or managing containers with `podman`.
  Triggers on requests like "run a container with podman", "build a podman
  image", "list containers", "podman compose", or any container management
  task using Podman.
---

# podman

Build and manage containers using `podman`.

## Orientation

You must run the following commands before proceeding:

```bash
which -a podman
which podman
podman --version
podman --help
```

## Workflow

1. Confirm the tool is present: `podman --version`
2. Review subcommands: `podman --help`
3. Pull an image: `podman pull <image>`
4. Run a container: `podman run <image>`
5. List containers: `podman ps -a`
6. Build an image: `podman build -t <tag> .`
7. Stop/remove a container: `podman stop <id>` / `podman rm <id>`

## Gotchas

- `podman --version` confirms the version; check it before using newer features.
- Each subcommand has help: `podman run --help`, `podman build --help`, etc.
- Podman is daemonless and rootless by default — behavior may differ from Docker in this regard.

## Reference

- `man podman` — top-level reference.
- `man podman-run`, `man podman-build`, etc. — per-subcommand man pages.
