---
name: package-size-audit
description: >
  Use this skill when the user wants a read-only inventory of the largest
  installed packages, applications, tools, or package-manager disk usage —
  including requests such as "what packages use the most space," "largest
  Nix/APT/npm/Flatpak packages," or "audit installed package sizes." Report
  the top 15 entries for each available manager, with manager-specific scope
  and size caveats. Do not use it to delete packages, clear caches, or broadly
  scan the filesystem; package removal and cleanup require separate explicit
  authorization.
---

# Package size audit

Produce a reproducible, read-only, manager-by-manager inventory. Default to
15 largest entries per manager (or every entry when fewer than 15 are
installed). Report findings before proposing any cleanup.

## Scope and boundaries

- Detect a manager with `command -v <command>` before querying it. Skip absent
  managers and state that they were unavailable; do not install anything.
- Keep every measurement inside a package manager's own reported directory,
  profile, or package database. Do not use `du /`, `find $HOME`, or broad
  filesystem scans to discover packages.
- Keep package inventories and cache totals separate. A cache can be reported
  as one clearly labeled manager-owned total only when relevant; do not treat
  its files as installed packages.
- Never run uninstall, autoremove, prune, clean, garbage-collection, or
  cache-removal commands. Inventory and removal are separate workflows.

## Default workflow

1. Record each available manager and its precise scope.
2. Run its read-only inventory command below. Capture a top-15 table sorted
   largest-first; preserve fewer rows if fewer entries exist.
3. Report units, scope, and manager-specific caveats with each table.
4. Summarize only within manager boundaries. Do not add table totals across
   managers: stores, runtimes, and dependencies can overlap.
5. If the user asks to reclaim space, present the completed inventory first
   and request separate authorization for a manager-specific cleanup plan.

## Core inventories

### Nix profiles

Audit profile entries rather than the whole Nix store. This reports each
profile entry's *closure size*.

```bash
nix profile list --json \
  | jq -r '.elements[]? | .storePaths[]?' \
  | xargs -r nix path-info --json --closure-size \
  | jq -r 'to_entries
      | map({path: .key, bytes: .value.closureSize})
      | sort_by(.bytes) | reverse | .[:15][]
      | [(.bytes | tostring), .path] | @tsv'
```

Use `numfmt --field=1 --to=iec-i` on the resulting byte column when available.
If several Nix profiles matter, run the command for each profile/root rather
than silently substituting `/nix/store/*`.

**Caveat:** Closure sizes are useful attribution estimates, not reclaimable
space. Closures share store paths, so adding their sizes double-counts shared
dependencies. Nix store size, old generations, build results, and caches are
separate scopes.

### Debian/Ubuntu packages (APT/dpkg)

Use dpkg's installed-package database; APT is the frontend, while dpkg owns
this installed-size metadata.

```bash
dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\t${Installed-Size}\n' \
  | awk -F '\t' '$2 == "installed" {print $3 "\t" $1}' \
  | sort -nr -k1,1 \
  | head -n 15 \
  | numfmt --field=1 --from-unit=1024 --to=iec-i
```

**Caveat:** `Installed-Size` is package metadata in KiB, not a live disk scan.
It can omit generated data and can overlap package-owned files with other
accounting views. APT lists/cache files and dpkg's database are not package
entries; label them separately if requested.

### uv tools

Limit the package table to globally managed uv tool environments, not project
virtual environments or uv's cache.

```bash
tools_dir="$(uv tool dir)"
[ -d "$tools_dir" ] && du -sk "$tools_dir"/* 2>/dev/null \
  | sort -nr -k1,1 | head -n 15 \
  | numfmt --field=1 --from-unit=1024 --to=iec-i
```

Optional cache total, reported separately: `du -sh "$(uv cache dir)"`.

**Caveat:** each uv tool directory is usually an isolated environment; its
size includes that environment's Python packages. Do not attribute the uv
cache or arbitrary project `.venv` directories to installed uv tools.

### Globally installed npm packages

Inventory only the global npm root; local `node_modules` belong to individual
projects and are out of scope.

```bash
npm_root="$(npm root -g)"
npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 \
  | while IFS= read -r package_path; do
      [ -d "$package_path" ] || continue
      size_kib="$(du -sk "$package_path" | awk '{print $1}')"
      printf '%s\t%s\n' "$size_kib" "${package_path#"$npm_root"/}"
    done \
  | sort -nr -k1,1 | head -n 15 \
  | numfmt --field=1 --from-unit=1024 --to=iec-i
```

**Caveat:** global packages may share npm-managed dependencies or use symlinks;
this is directory usage, not guaranteed reclaimable space. Exclude npm cache
unless reporting it separately as a clearly labeled directory-size total,
for example `du -sh "$(npm config get cache)"`.

### Flatpak apps and runtimes

List user and system installations separately, and include runtimes because
Flatpak applications often depend on large shared runtime refs.

```bash
flatpak --user list --columns=ref,size \
  | sort -h -r -k2,2 | head -n 15
flatpak --system list --columns=ref,size \
  | sort -h -r -k2,2 | head -n 15
```

If a scope has no installation, report it as empty rather than failing the
audit.

**Caveat:** Flatpak refs can be shared among apps; a runtime's displayed size
is not additional reclaimable space for every app that uses it. User and
system stores are distinct. Do not conflate refs, unused refs, downloads, and
application data.

## Additional package families to consider

Include these only when installed and relevant to the user's environment;
keep every family in its own table and state its scope.

| Family | Read-only starting point | Scope warning |
| --- | --- | --- |
| Homebrew formulae | `brew list --formula -1`, then `du -sk "$(brew --prefix <formula>)"` per formula | Formula prefixes can share dependencies. Audit casks separately; their app/data locations vary. |
| `pipx` apps | `pipx environment --value PIPX_HOME`, then `du -sk "$PIPX_HOME/venvs"/*` | Count isolated pipx venvs, not system Python or project virtualenvs. |
| pnpm/Yarn globals | `pnpm root -g` or `yarn global dir`, then size only that manager-reported global location | Do not combine with npm; their stores/caches and symlink layouts differ. |
| Snap | `snap list --all` plus sizes under `/var/lib/snapd/snaps` when a retained-revision audit is requested | Snap files can include inactive revisions; report them as managed revision artifacts, not just active apps. |
| Cargo/Rustup | `cargo install --list` and `rustup toolchain list` | Cargo-installed binaries and Rust toolchains are different scopes; binaries alone cannot reliably attribute shared cargo state. |
| Conda/Mamba | `conda env list`, then size each listed environment path | Named environments can duplicate packages; package caches are separate. |
| RubyGems/Composer | Query the manager's global install directory, then size only its package directories | Avoid scanning language project dependencies or shared caches. |

## Reporting template

```markdown
## <manager> — <scope>

| Rank | Entry | Reported size | Measurement |
| ---: | --- | ---: | --- |
| 1 | <package/ref/path> | <size> | <metadata, closure, or directory> |

Caveat: <manager-specific non-reclaimability or overlap note>
```

End with a short list of managers checked, unavailable managers, and any
separate cache totals. Do not recommend a removal command unless separately
authorized after the inventory is shown.

## Gotchas

- A package's apparent size is not automatically reclaimable space. Shared
  dependencies, runtimes, hardlinks, and retained generations/revisions make
  simple sums misleading.
- Prefer package names or refs from the manager's own output. A bare directory
  basename can be ambiguous, especially for scoped npm packages.
- Do not silently expand scope from global packages to project dependencies,
  user data, caches, containers, or the whole filesystem.
- Do not use a cleanup command merely to calculate candidates. Read-only
  inventory must remain read-only.
