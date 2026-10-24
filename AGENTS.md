# Agent Skills Repository Guide

## Ownership and preflight

Read applicable guidance, branch/upstream, remotes and exact target status
before editing. Stop on unexpected target edits or ambiguous ownership;
preserve unrelated work. Load `skill-md-authoring` for skill edits and
`skills-update` before installation, update, removal or source-link changes.

This repository owns public bundles under `skills/<name>/`, including their
references, scripts and assets. Keep relative references inside their bundle.
Keep consent/privacy gates in the entry `SKILL.md`; global guidance is not
inherited by every consumer or subagent. Do not copy private configuration,
credentials or local operational evidence into this public repository.

## Publishing and downstream review

1. Edit only the authorized source bundle; review the complete diff, file
   modes, links, frontmatter and bundled references.
2. Run appropriate validation, then commit and push task paths to `origin`
   when the task authorizes publication. For delegated source-only work,
   leave commits/pushes to the parent. Stop on divergence/access failures.
3. If a same-name private bundle exists in `secret-agent-skills`, compare the
   complete bundles and both owning guides. Same name does not mean identical
   scope: private customizations and local safety overlays are intentional
   until reviewed otherwise. Publish the public source first, then merge only
   approved applicable changes into the private source and publish it separately.
   If no private counterpart exists, report that no matching refresh is needed.
4. Treat deployment as a separate, authorized step. Source-linked installs
   already read their owning checkout; do not install through a symlink,
   replace it with a copy, or run Stow as an implicit repair. Review local
   overlays in their owning repository, not by reinstalling a source bundle.
5. Only for an approved, verified unmodified managed copy may an exact,
   named/scope-limited CLI refresh be appropriate after its canonical source
   is published. Inspect installed CLI help; stop if exact scope cannot be
   guaranteed. Never blanket-update, remove/re-add on failure, rewrite locks
   cosmetically, or use `-y` as authorization.

After approved changes, verify loaded bytes and discovery in each intended
consumer/working directory. Source edits alone are not deployment or runtime
verification; report what was actually checked and any skipped refresh.
