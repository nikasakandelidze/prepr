# /prepr-open

Publish a planning document as a **draft GitHub pull request** on a fresh temporary branch so teammates can review it inline.

## When to run

The user asked to share a plan for review, publish a plan-mode output, or open a "plan PR". Do **not** use this to open regular code-change PRs.

## Preconditions

- `git`, `gh` (authenticated), `jq` on PATH
- Current directory is inside a git repo with a GitHub remote
- A markdown plan file exists (ask which one if unclear)

## Action

Run:

```bash
prepr open <plan-file> [--title "T"] [--base main] [--reviewer @user] [--label plan]
```

- `--title` defaults to the first `# H1` in the file
- `--base` defaults to the repo's default branch
- The CLI creates a temporary worktree, commits only the plan file on a new `plan/<timestamp>-<slug>` branch, pushes it, and opens a **draft** PR whose body embeds the plan

## After

- Print the returned URL to the user
- Suggest `prepr review` for checking comments later
- Do NOT edit the plan file yourself unless the user asks
