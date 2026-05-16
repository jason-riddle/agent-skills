---
name: tailscale
description: >
  Use this skill when managing a Tailscale VPN connection, checking network
  status, or configuring Tailscale settings with the `tailscale` CLI. Triggers
  on requests like "connect to tailscale", "check tailscale status", "list
  tailscale peers", "tailscale up", or any Tailscale networking task.
---

# tailscale

Manage Tailscale VPN connections using the `tailscale` CLI.

## Orientation

You must run the following commands before proceeding:

```bash
which -a tailscale
which tailscale
tailscale --version
tailscale --help
```

## Workflow

1. Confirm the tool is present: `tailscale --version`
2. Review subcommands: `tailscale --help`
3. Check current status: `tailscale status`
4. Connect to the network: `tailscale up`
5. Disconnect: `tailscale down`
6. List peers: `tailscale status --peers`
7. Get your IP: `tailscale ip`

## Gotchas

- `tailscale --version` prints version and commit hash.
- Each subcommand has help: `tailscale up --help`, `tailscale status --help`, etc.
- Most commands require the `tailscaled` daemon to be running; check with `systemctl status tailscaled`.

## Reference

- No `man tailscale` available; use `tailscale --help` and `tailscale help <subcommand>` as the primary reference.
