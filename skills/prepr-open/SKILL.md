---
name: prepr-open
description: Publish a planning document (e.g. the current plan-mode plan, a Grill-Me plan, or any design doc) as a draft GitHub pull request on a temporary branch so teammates can review it inline. Use whenever the user asks to "share this plan for review", "open a plan PR", "publish this plan", or similar. Returns the PR URL. Requires git, gh, jq.
---

# prepr-open

Opens a plan file as a **draft pull request** on a fresh temporary branch (`plan/<timestamp>-<slug>`), so the team can review the plan the same way they review code. The heavy lifting is done by a bundled bash CLI — this skill just decides *what* to publish and *how* to invoke it.

## When to use

Trigger on any of:

- "Publish this plan for review" / "open a plan PR" / "share the plan on GitHub"
- The user has just finished a plan-mode session and wants team feedback
- The user hands you a markdown plan and says "get eyes on this"

Do **not** use this for regular code-change PRs — those go through the normal `gh pr create` flow. This skill is specifically for review of *planning documents*.

## Preconditions (check first, fail fast)

1. `git`, `gh`, and `jq` on PATH.
2. Current working directory is inside a git repo with a GitHub remote.
3. `gh auth status` succeeds.
4. A plan file exists. If the user hasn't given you one, ask:
   - "Which file should I publish?" (offer obvious candidates: `PLAN.md`, `.claude/plan.md`, the file just written in plan mode).

If any check fails, tell the user and stop. Do not attempt to work around missing auth.

## How to invoke

The CLI is at `<package-root>/bin/prepr` (on PATH when installed via npm; also symlinked next to the installed skills). It is fast — one worktree, one push, one `gh pr create` call.

```bash
prepr open <plan-file> [--title "Title"] [--base main] [--reviewer @teammate] [--label plan]
```

- `<plan-file>`: path to the markdown file (required).
- `--title`: PR title. Defaults to the first `# H1` in the file, prefixed with `"Plan: "`.
- `--base`: base branch to open against. Defaults to the repo's default branch.
- `--reviewer`: GitHub handle to request as reviewer (repeatable via commas).
- `--label`: label to apply (must already exist in the repo).

## What it does

1. Fetches `origin/<base>` (quiet).
2. Creates a temporary worktree checked out on a new branch `plan/<UTC-timestamp>-<slug>`.
3. Copies the plan file into that worktree (preserving its `.md` name, or renaming to `PLAN.md`).
4. Commits, pushes, and opens a **draft** PR whose body includes the plan inline (so reviewers can comment either on the file diff or on the PR conversation).
5. Records the PR as the repo's "current plan PR" in `~/.prepr/state/<owner>__<repo>/current` so subsequent `prepr review` / `prepr close` calls don't need the PR number.
6. Removes the worktree — the user's working tree is untouched.

## After it runs

- Print the returned URL to the user.
- Suggest the follow-up:
  - `prepr review` — to check for comments (see the [[prepr-review]] skill).
  - `prepr close`  — when the plan is finalized (see the [[prepr-close]] skill).

## Guardrails

- **Do not edit the plan file** before publishing unless the user explicitly asks. The point of the review is to get feedback on what *they* wrote.
- **Do not push to a base branch.** The CLI always creates a new `plan/*` branch — trust it. If the user asks to publish "on main", clarify first.
- If the plan file is not under git, that's fine — the CLI copies it into a worktree.
