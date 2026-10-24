---
name: skills-update
description: >
  Use this skill when the user wants to update, upgrade, refresh, reinstall,
  or check installed agent skills, including "update my skills" or "pull the
  latest skill changes". Inspect exact source/target bundles, ownership,
  source links and intentional local overlays before any scoped update;
  prevent blanket updates or remove/re-add recovery from losing local policy.
---

# Update skills without losing local policy

Skill installation changes instructions and may overwrite local safety
controls. A request to check updates authorizes inspection, not installation.
Use explicit non-interactive scope only after the target/effect is approved;
`-y` suppresses prompts, not consent or ownership review.

## Preflight: no writes yet

1. Read applicable global, repository and nested guidance at both source and
   destination. Inspect worktree status, branch/upstream, remotes, lock
   provenance and actual discovery paths. Diagnose missing skills with
   `shelley-skill-discovery` when available; absence is not a reinstall cue.
2. Resolve the exact source repo/ref, skill name, agent, install scope, and
   destination. Inspect symlinks and their canonical targets; do not assume
   lock metadata equals the effective source. Confirm home-path expansion in
   the actual consumer context. Start with filesystem/link inspection and
   `shelley skill ls` where available. Use only an already-installed Skills
   CLI for additional read-only inventory after checking its help; do not
   bootstrap/download a CLI merely to inspect or silently auto-detect
   mutation scope.
3. Compare the **complete bundle**: relative paths, file bytes, scripts,
   references/assets, executable modes, symlinks and relevant lock changes,
   not only `SKILL.md`. Inspect the source diff and provenance before loading
   new third-party code/instructions. Identify intentional local overlays,
   added consent/privacy gates, and conflicting same-name skills.
4. Protect local differences. Stop on dirty target files, unexpected source
   changes, unclear ownership, missing source checkouts, or ambiguous targets.
   Do not reset, stash, truncate, replace, or overwrite local policy. A
   differing local bundle is not obsolete just because a source exists.

Missing helper instructions are a discovery problem, not permission to run
generators such as `gws generate-skills`. Locate the intended source and
effective catalog entry; if a required safety/auth helper remains unavailable,
stop the dependent work and report the missing path. Generate or install a
bundle only under a separately approved exact destination and ownership plan.

## Choose the owning update path

- **Source-linked bundle:** edit/publish the owning source repository under
  its guidance. Do not run a Skills CLI install/update across the link or
  replace the directory with a copy. Provision missing source checkouts
  separately; never deploy/Stow as an implicit repair.
- **Intentional local overlay:** preserve it in its owning repository.
  Review and merge selected upstream improvements while retaining local
  safety gates. Replacing the overlay requires explicit owner approval of
  the complete replacement and a private recovery plan.
- **Unmodified managed copy:** after full comparison and approval, use an
  exact named, explicit-scope update supported by the installed CLI. Check
  help before relying on a positional name: if it cannot guarantee the exact
  target, stop rather than fall back to a blanket operation.

Do not run blanket `skills update`, `--all`, wildcard-agent changes, or
implicit-scope updates over a mixed/source-linked/overlaid installation.
For a genuinely requested broad refresh, enumerate and approve the exact
safe target set first, exclude linked/overlaid/dirty bundles, then process
only verified targets individually. Stop if the CLI cannot preserve scope.

Read owner guidance before publishing. Where shared/private matching copies
exist, publish the canonical shared change first and compare the complete
private bundle before any refresh. A root-guide recipe is not permission to
replace a private customization. If guidance conflicts with protected source
links/local policy, stop and report rather than blindly follow an installer.

## Failure and recovery

An update error or renamed skill is **not** authorization to remove/re-add.
Inspect partial effects and report them; do not uninstall as an automatic
workaround. Obtain explicit approval for any migration, removal, reinstall,
lock rewrite, or replacement after showing exact targets and local diffs.
Keep private recovery material outside Git; do not invent a matching private
skill or a destination when none exists.

## Verify and report

Review exact bundle and lock diffs for only approved paths. Verify both
consumers when global installation is intended for OpenCode and Shelley:
already-installed CLI inventory where applicable, plus `shelley skill ls` and
`shelley skill cat <name>`
from `/tmp` and the relevant repository root. Confirm loaded bytes and unique
names, not just source existence. Recheck status, run repository validation,
and commit/push only task changes under owner guidance; stop on divergence,
missing upstream or access failures. Do not force-push or include unrelated
work. Record verified deployment state in the canonical Wiki when applicable.
Report updated/skipped targets, preserved overlays, checks and blockers;
never describe a source edit alone as deployment or live verification.
