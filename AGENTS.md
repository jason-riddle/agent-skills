# Agent Skills Repository Guide

## Publishing Skill Changes

When modifying a skill in this repository:

1. Update the relevant file under `skills/<skill-name>/`.
2. Review the diff and run appropriate validation.
3. Commit the change.
4. Push the commit to `origin`.
5. Refresh the matching skill from `secret-agent-skills` when that repository
   contains the same skill.

The refresh must happen after the source commit has been pushed so the skills
CLI can install the current repository contents:

```bash
npx -y skills add jason-riddle/secret-agent-skills \
  --skill <skill-name> -a opencode -g -y
```

For example, if `skills/disk-cleanup/SKILL.md` was updated and committed in
`agent-skills`, run:

```bash
npx -y skills add jason-riddle/secret-agent-skills \
  --skill disk-cleanup -a opencode -g -y
```

Do not run the refresh before pushing the source change. If the skill does not
exist in `secret-agent-skills`, report that no refresh was performed instead of
inventing a destination skill.
