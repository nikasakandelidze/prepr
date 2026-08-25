# /prepr-close

Close the draft plan PR, delete its remote branch, and clean up local state. Destructive — always confirm with the user first.

## When to run

The user said the plan is finalized: "close it out", "we're done with the plan", "resolve the plan PR". Do **not** use for regular code PRs.

## Action

```bash
prepr close [PR] [--keep-branch] [--yes]
```

- `PR`: optional; falls back to the recorded "current" plan PR
- `--keep-branch`: close the PR but leave the branch (e.g. so it can be re-opened later)
- `--yes` / `-y`: skip the interactive confirmation. **Only** pass this if the user explicitly said yes in this turn.

## Guardrails

- Always show the PR URL and branch name to the user and get explicit approval before running with `--yes`.
- If `prepr review` shows unresolved comments, warn the user first.
- Never `git push --delete` the branch yourself — always go through the CLI so state gets cleaned up.
