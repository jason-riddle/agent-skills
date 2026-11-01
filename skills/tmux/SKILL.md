---
name: tmux
description: >
  Use this skill when the user wants to run, reconnect to, inspect, or
  troubleshoot a tmux session or keep a long-running command available after
  a terminal or SSH disconnect, even if tmux is not named. Distinguish local
  tool background jobs from sessions on a remote host. Load ssh for remote
  access; this skill does not authorize the command or its side effects.
---

# tmux and long-running commands

## Workflow

1. Establish the target host, account, working directory, command, expected
   side effects, and permission to run or inspect it. For remote work load
   `ssh` and follow the host's access guidance. A session or its output may
   contain sensitive data; read only what the user authorized. Do not
   interfere with another agent's work.
2. For a command that must outlive an SSH client, consider a **detached
   session on the remote host**, not merely a local backgrounded SSH process.
   Confirm tmux availability and choose a unique session name; identify the
   account and any nondefault server/socket. Root and user sessions may be
   separate. Do not install or change privilege settings without authorization.
3. Plan a private, appropriately permissioned log and a distinct completion
   status marker when useful. Ensure the launched command records its actual
   exit code, including failures; avoid exposing secrets in command lines,
   logs, shell history, or session output. Interactive authentication and
   commands requiring a terminal may need a separate approved handoff.
4. Launch only the authorized command and confirm the tool actually executed
   the launch. A successful session launch is not command completion. If the
   launch response is ambiguous or says it was not executed, do not assume
   it started or blindly retry: check for an existing run first, if allowed.
5. When the user authorizes follow-up, inspect the correct host/account,
   session, log and completion marker. A missing session or marker is
   inconclusive; an exit code or log must be interpreted in context. Report
   launch, completion and output verification separately. Do not attach to,
   kill, restart, or clean up an existing job without appropriate approval.

## Gotchas

- A shell-tool background job is local to that tool environment; it is not
  the same as a remote tmux session and does not guarantee remote survival.
  A detached tmux session is also not a guarantee against host restart,
  server termination, command failure, or an application timeout.
- Check the current tool's own background and lifetime behavior rather than
  assuming a fixed timeout. Do not poll or sleep if the tool forbids it.
- tmux does not repair command-specific prerequisites or make reruns
  idempotent. Check the application's documented state and safety requirements
  before any retry, cleanup, or destructive action.
