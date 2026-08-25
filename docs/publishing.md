# Publishing prepr

`prepr` is distributed **from GitHub** (tags → releases). Publishing to the npm registry is optional — users install with `npm install github:<you>/prepr#<tag>` either way.

Checklist for open-sourcing your fork.

## 1. Fill in your identity

Edit `package.json`:

```jsonc
{
  "name": "prepr",
  "author": "Your Name <you@example.com>",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/<you>/prepr.git"
  },
  "homepage": "https://github.com/<you>/prepr",
  "bugs": { "url": "https://github.com/<you>/prepr/issues" }
}
```

Also drop your copyright line in `LICENSE`.

## 2. Push to GitHub

```bash
cd /path/to/prepr
git init -b main
git add .
git commit -m "chore: initial commit"
git remote add origin git@github.com:<you>/prepr.git
git push -u origin main
```

Add repo **topics** so it's discoverable:

```bash
gh repo edit <you>/prepr --add-topic claude-code-skill,codex,agent-skill,pull-request,planning
```

## 3. Cut a release

The tag is your version boundary. Users install by tag; the Releases page becomes the changelog.

```bash
# Bump version in package.json first (already 0.1.0 for the first release).
git tag v0.1.0
git push --tags
gh release create v0.1.0 --generate-notes
```

Verify a clean install works end-to-end:

```bash
cd $(mktemp -d)
npm install -g github:<you>/prepr#v0.1.0
prepr --help
prepr-install                    # → ~/.claude/skills/prepr-*
```

## 4. Later releases

For each new version:

```bash
# 1. Bump "version" in package.json (semver).
# 2. Commit the bump:
git commit -am "release: v0.2.0"
git push
# 3. Tag and release:
git tag v0.2.0
git push --tags
gh release create v0.2.0 --generate-notes
```

`--generate-notes` scans commits since the previous tag and drafts a Markdown changelog for you. Edit it in the browser after if you want.

## 5. Optional: publish to the npm registry too

Only worth it if you want people to type `npm i prepr` without knowing your GitHub handle.

```bash
npm login
# If the bare name is taken (check with `npm view prepr`), scope it:
#   "name": "@yourscope/prepr"  → then:
npm publish --access public
# Unscoped:
npm publish
```

## 6. Optional: distribute as a Claude Code plugin

Claude Code plugins live in `~/.claude/plugins/`. To ship this as a plugin instead of / in addition to raw skills, add a `plugin.json` at the repo root pointing at `skills/`. The SKILL.md files as-written are standard `name` + `description` frontmatter and work under any plugin wrapper.

## Ongoing maintenance

- Because the CLI is bash + `gh` + `git` + `jq`, there's essentially no dependency tree to keep patched.
- Recommended CI (minimal): `shellcheck lib/prepr.sh bin/prepr` on every push.
