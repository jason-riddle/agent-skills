---
name: npm
description: >
  Use this skill when managing Node.js packages or running scripts with `npm`.
  Triggers on requests like "install npm packages", "run npm scripts",
  "publish to npm", "update dependencies", "npm init", or any Node.js
  package management task.
---

# npm

Manage Node.js packages and scripts using `npm`.

## Orientation

You must run the following commands before proceeding:

```bash
which -a npm
which npm
npm --version
npm --help
```

## Workflow

1. Confirm the tool is present: `npm --version`
2. Review subcommands: `npm --help` or `npm help <subcommand>`
3. Initialize a project: `npm init`
4. Install dependencies: `npm install`
5. Install a specific package: `npm install <package>`
6. Run a script: `npm run <script>`
7. Publish a package: `npm publish`

## Gotchas

- `npm --version` prints only the npm version; use `node --version` separately for Node.js version.
- Each subcommand has help: `npm install --help`, `npm run --help`, etc.
- Use `npm ci` instead of `npm install` in CI environments for reproducible installs.

## Reference

- `man npm` — available on most systems.
- `npm help <subcommand>` — detailed subcommand docs (e.g., `npm help install`).
