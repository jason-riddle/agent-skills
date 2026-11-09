# Agent Skills Repository Guide

## Deprecated source

This checkout is deprecated for future skill authoring. The consolidated
private repository at `~/code/src/github.com/jason-riddle/skills/` owns
source bundles under `skills/<name>/`; read its root `AGENTS.md` and
`docs/migration.md` before proposing or making changes there.

This checkout and its Git history remain available for reference and
rollback. Some consumers may still link here: deprecation does not mean
deployment, link migration, or checkout retirement is complete. Do not
delete or repoint anything without separately authorized review.

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
