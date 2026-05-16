---
name: skills-update
description: >
  Use this skill when the user wants to update, upgrade, or refresh their
  installed agent skills to the latest versions — for example "update my
  skills", "upgrade skills", "check for skill updates", "my skills are
  out of date", or "pull the latest skill changes". Uses the `npx skills`
  CLI in a fully non-interactive way.
---

# Update Skills

Update installed agent skills to their latest versions using the `npx skills`
CLI non-interactively.

## Global skill paths (OpenCode)

OpenCode reads global skills from two locations:

- `~/.agents/skills/` — where `npx skills add ... -g` installs by default
- `~/.config/opencode/skills/` — manually managed or legacy installs

Both are checked by `npx -y skills ls -g --json`.

## Workflow

1. Audit what is currently installed before updating:

   ```bash
   npx -y skills ls -g --json
   ```

2. Determine scope based on user intent:
   - **Global only (most common for OpenCode)** → `-g -y`
   - **Project only** → `-p -y`
   - **Auto-detect** → `-y` (uses project scope if CWD contains
     `skills-lock.json` or `.agents/`, otherwise global)

3. Run the update:

   ```bash
   # Global skills only (recommended default for OpenCode)
   npx -y skills update -g -y

   # Project skills only
   npx -y skills update -p -y

   # A single named skill (global)
   npx -y skills update <skill-name> -g -y

   # All skills, auto-detected scope
   npx -y skills update -y
   ```

4. Report the results to the user: which skills were updated, which were
   already up to date, and any errors.

5. If any skill failed to update, check whether the source repo has changed
   and re-add it:

   ```bash
   npx -y skills remove <skill-name> --agent '*' -y
   npx -y skills add <owner>/<repo> --skill <skill-name> -a opencode -g -y
   ```

## Installing this skill

To install `skills-update` itself globally for OpenCode:

```bash
npx -y skills add jason-riddle/agent-skills --skill skills-update -a opencode -g -y
```

## Gotchas

- Two `-y` flags are needed: the outer one (`npx -y`) silences npx's package
  download prompt; the inner one (`skills update -y`) skips the CLI's own
  scope prompt. Omitting either causes an interactive hang.
- `skills update -y` (no `-g`/`-p`) auto-detects scope based on CWD. Prefer
  `-g -y` explicitly when updating global OpenCode skills to avoid ambiguity.
- Skills installed as copies are updated in place; no manual file copying needed.
- If a skill's `name` changed upstream, `update` will not rename it — remove
  the old name and re-add.
- `DISABLE_TELEMETRY=1` can be prepended to suppress anonymous usage telemetry.
