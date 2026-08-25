# Publishing prepr

Checklist for open-sourcing your fork of `prepr` on GitHub and (optionally) npm.

## 1. Fill in your identity

Edit `package.json`:

```jsonc
{
  "name": "prepr",                        // or "@yourscope/prepr"
  "author": "Your Name <you@example.com>",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/<you>/prepr.git"
  }
}
```

If you use a scoped name (`@yourscope/prepr`), you'll need `--access public` when you publish, since scoped packages default to private.

If the bare `prepr` name is already taken on npm (check with `npm view prepr` — if it errors with 404, it's free), scope it. Suggested scoped fallbacks:

- `@nikasakana/prepr`
- `@<your-github-user>/prepr`
- `prepr-cli`  (unscoped alternative)

Also drop your copyright line in `LICENSE`.

## 2. Push to GitHub

```bash
cd /path/to/prepr
git init
git add .
git commit -m "chore: initial commit"
git branch -M main
git remote add origin git@github.com:<you>/prepr.git
git push -u origin main
```

Recommended: add repo **topics** like `claude-code-skill`, `codex`, `agent-skill`, and `pull-request` so it's discoverable.

## 3. Publish to npm

```bash
npm login              # if you haven't already
npm publish            # for an unscoped name
# or
npm publish --access public   # for @yourscope/prepr
```

Verify it installs cleanly in an empty directory:

```bash
cd $(mktemp -d)
npm install -g prepr             # or your scoped name
prepr --help
prepr-install                    # → ~/.claude/skills/prepr-*
```

## 4. Tag a release

```bash
git tag v0.1.0
git push --tags
gh release create v0.1.0 --generate-notes
```

## 5. Optional: distribute as a Claude Code plugin

Claude Code plugins live in `~/.claude/plugins/`. To distribute this package as a plugin instead of / in addition to raw skills, add a `plugin.json` at the repo root that points at `skills/`. See the Claude Code docs for the current schema; the SKILL.md files as-written should work under any plugin wrapper because they're standard `name` + `description` frontmatter.

## 6. Ongoing maintenance

- Bump `version` in `package.json`, tag, `npm publish`.
- Because the CLI is bash and depends only on `gh`/`git`/`jq`, there is essentially no dependency tree to keep patched — CI can be minimal (a shellcheck run on `lib/prepr.sh` is plenty).
