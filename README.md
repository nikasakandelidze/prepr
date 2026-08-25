# prepr

> **pre-PR** — the review that happens *before* the code PR.

Agent-agnostic **skills** — for Claude Code, Codex, or any agent that can run a shell command — that treat *planning documents* the way we treat code: as something you open a pull request for, get review on, iterate on, and close out.

Three tiny skills, backed by one fast bash CLI (`gh` + `git` + `jq`, no LLM in the hot path):

| Skill           | What it does                                                                                              |
| --------------- | --------------------------------------------------------------------------------------------------------- |
| `prepr-open`    | Turns a markdown plan into a **draft PR** on a temporary `plan/<timestamp>-<slug>` branch. Returns the URL. |
| `prepr-review`  | Fetches PR comments (conversation + inline + reviews), splits into **NEW / OPEN / RESOLVED**, tracks state locally so nothing gets missed. The agent **does not** edit the plan — that stays a human decision. |
| `prepr-close`   | Closes the draft PR and deletes the remote branch once the plan is finalized. Confirms before destructive action. |

---

## Why

Modern code review has shifted upstream: reviewing the **plan** matters more than reviewing the diff. But sharing a plan-mode output still means "copy the markdown, paste it into Slack / a Notion doc / a PR description by hand." `prepr` automates that loop end-to-end without asking the agent to be slow or clever about it — every operation is one or two `gh` calls.

---

## Requirements

- `git`
- [`gh`](https://cli.github.com/) (authenticated: `gh auth login`)
- `jq`
- Node 18+ *only if you install via `npm`/`npx`* — the CLI itself is bash

---

## Install

### Option A — via npm (recommended once published)

```bash
# Global install (adds `prepr` to your PATH):
npm install -g prepr

# Then wire up the Claude Code skills:
prepr-install              # → ~/.claude/skills/prepr-*
# or, per-repo:
prepr-install --project    # → ./.claude/skills/prepr-*
```

You can also run it without a global install:

```bash
npx prepr open PLAN.md
```

### Option B — clone the repo

```bash
git clone https://github.com/<you>/prepr.git ~/tools/prepr
export PATH="$HOME/tools/prepr/bin:$PATH"       # add to your shell rc
node ~/tools/prepr/bin/prepr-install.js         # installs skills to ~/.claude/skills
```

### Option C — Codex / other agents

See [`examples/codex/README.md`](examples/codex/README.md). Short version: copy the three `examples/codex/prepr-*.md` files into `~/.codex/prompts/` and invoke via `/prepr-open`, `/prepr-review`, `/prepr-close`.

---

## Usage

### 1. Open a plan PR

```bash
# after plan-mode / hand-writing PLAN.md
prepr open PLAN.md --reviewer @teammate --label plan
```

Output:

```
Draft plan PR opened.
  Repo:    my-org/my-app
  Branch:  plan/20260825-123045-add-billing-refactor
  Base:    main
  File:    PLAN.md
  Title:   Plan: Add billing refactor
  URL:     https://github.com/my-org/my-app/pull/427

PR=427 URL=https://github.com/my-org/my-app/pull/427
```

The PR number is now recorded as the repo's "current" plan PR — later commands don't need it.

### 2. Review the feedback

```bash
prepr review
```

```
Plan PR my-org/my-app#427  (https://github.com/my-org/my-app/pull/427)
  New: 2   Open: 1   Resolved: 0

── TO ADDRESS (new since last fetch) (2) ──
• [rc-2091834] inline — @alice 2026-08-25T18:02:11Z
  PLAN.md:42
  https://github.com/my-org/my-app/pull/427#discussion_r2091834
  │ Step 3 mixes a schema change with a data backfill;
  │ split into 3a (add nullable column) and 3b (fill + enforce NOT NULL).
…
```

Once you (the human) have updated the plan to address a comment, mark it resolved:

```bash
prepr review --ack rc-2091834
```

**State handling.** GitHub's own "resolved thread" UI only applies to inline review threads and requires reviewer clicks — we don't rely on it. Instead, `prepr` tracks two things locally per PR (at `~/.prepr/state/<owner>__<repo>/pr-<n>.json`):

- **seen** — comments already surfaced. Next fetch splits new vs. old.
- **resolved** — comments you explicitly `--ack`'d.

Everything that is new-and-unresolved shows up as **TO ADDRESS**.

### 3. Close it out

```bash
prepr close
# → confirms interactively, then closes PR and deletes the remote branch
```

If you want to skip the prompt (e.g. from an agent that already confirmed with the user):

```bash
prepr close --yes
```

---

## Design notes

- **Fast.** Every subcommand is one or two `gh`/`git` invocations. `prepr review` fetches all three comment surfaces (issue comments, inline review comments, review submissions) in parallel via `gh api --paginate`.
- **Non-invasive.** `prepr open` runs entirely in a throwaway `git worktree`, so your working tree, uncommitted changes, and current branch are untouched.
- **Agent-agnostic.** The SKILL.md files are Claude Code entry points; Codex + other agents get equivalent prompt files under `examples/codex/`. The heavy lifting is in `bin/prepr` — any agent that can run a shell command can drive it.
- **Human keeps the pen.** The rule for `prepr-review` is explicit: the agent surfaces comments and summarizes them but **does not edit the plan**. Updates come from the human; the agent only marks things resolved when told.

---

## Publishing this package

If you're forking this repo to publish your own version, see [`docs/publishing.md`](docs/publishing.md) for the full checklist. TL;DR:

1. Set `name`, `author`, and `repository.url` in `package.json`.
2. `git init && git remote add origin git@github.com:<you>/prepr.git && git push -u origin main`
3. `npm login` and `npm publish` (or `npm publish --access public` if you use a scoped name).
4. Tag a release: `git tag v0.1.0 && git push --tags`.

---

## Layout

```
prepr/
├── bin/
│   ├── prepr                 # bash CLI — the actual worker
│   └── prepr-install.js      # Node installer for the Claude Code skill dir
├── lib/
│   └── prepr.sh              # sourced by the CLI; keeps distribution as one package
├── skills/
│   ├── prepr-open/SKILL.md   # Claude Code skill: open a plan PR
│   ├── prepr-review/SKILL.md #   … fetch + bucket comments, track state locally
│   └── prepr-close/SKILL.md  #   … close PR + delete branch
├── examples/codex/           # Codex-friendly variants of the same three skills
├── docs/publishing.md        # how to release to GitHub + npm
├── package.json
├── LICENSE                   # MIT
└── README.md                 # you are here
```

---

## License

[MIT](LICENSE)
