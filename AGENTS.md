# Agent Skills Repository Guide

## Deprecated source

This checkout is deprecated for future skill authoring. The consolidated
private repository at `~/code/src/github.com/jason-riddle/skills/` owns
source bundles under `skills/<name>/`; read its root `AGENTS.md` and
`docs/migration.md` before proposing or making changes there.

This checkout and its Git history remain available for provenance and
reference. Dotfiles-shared skill copies migrated to the consolidated source
have been removed from this worktree; do not recreate those copies or source
links here. Other legacy bundles may remain and are not automatically
migrated or approved for deletion. The public `android-remote-control` bundle
is a distinct legacy workflow, not the canonical Shelley skill; do not use it
as a replacement for the consolidated private Shelley bundle. Keep this
checkout and unrelated content unless separately authorized review says
otherwise.

## Safety and review

Before any authorized edit here, inspect applicable guidance, branch,
upstream, remotes and exact target status. Stop on unexpected target edits
or ambiguous ownership; preserve unrelated work. Do not copy private
configuration, evidence or credentials into this public repository.

Deployment is separate from source changes. Protect source links and local
overlays; do not install through links, blanket-update, remove and reinstall
as recovery, or run Stow as an implicit repair. Load `skills-update` before
installation, update, removal or source-link changes. Verify intended
consumer discovery and loaded bytes after approved deployment, and report
source, publication and runtime verification separately.

Commit or push only when authorized; for delegated source-only work leave
both to the parent. Stop on divergence or access failures.
