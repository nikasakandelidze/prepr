---
name: prepr-close
description: Close the draft plan PR, delete its remote branch, and clean up local state — used when the plan has been finalized and no longer needs review. Confirms with the user before destructive action. Use when the user says "we're done with the plan", "close the plan PR", "the plan is finalized", or similar.
---

# prepr-close

Wraps up a plan review lifecycle: closes the draft PR opened by `prepr-open` and deletes the remote branch it was published on. Also clears the local "current plan PR" marker and per-PR state file, so a subsequent `prepr open` starts fresh.

## When to use

- User confirms the plan is done: "close it out", "we're good", "plan is final", "resolve the plan PR".
- After all outstanding comments have been addressed (see [[prepr-review]] to check).

Do **not** use this to close normal code PRs. This is only for the plan-review branches created by [[prepr-open]].

## Preconditions

- `git`, `gh`, `jq` on PATH.
- Inside the same repo where the plan PR was published, or the user has given you a PR reference.

## How to invoke

```bash
prepr close [PR] [--keep-branch] [--yes]
```

- `PR`: optional; falls back to the recorded "current" plan PR.
- `--keep-branch`: close the PR but leave the remote branch in place (e.g. if the user wants to re-open later).
- `--yes` / `-y`: skip the interactive confirmation. Only pass this if the user explicitly said "yes, close it".

## What it does

1. Resolves the PR reference (arg → current marker → error).
2. Looks up the branch name (from local state or from the PR itself).
3. Prints a summary and asks for `y/N` confirmation — **unless** `--yes` was passed.
4. `gh pr close <n>` with a short comment noting closure via prepr.
5. Deletes the remote branch via `gh api -X DELETE repos/…/git/refs/heads/<branch>` (single round trip, no local checkout needed).
6. Best-effort local cleanup: `git worktree prune` and `git branch -D` in case anything lingers.
7. Removes the local state file for this PR and clears the "current" marker if it pointed at this PR.

## Guardrails — **read carefully**

- This is a destructive action (closes a PR, deletes a remote branch). **Confirm with the user before running it** — do not pass `--yes` unless they've explicitly agreed *in this turn*.
- If there are **NEW** or **OPEN** feedback comments (check via [[prepr-review]] first if unsure), warn the user and confirm they still want to close.
- Never run `git push --delete` yourself for a plan branch — always route through this CLI so the state file gets cleaned up.
- Do not re-open a closed plan PR from this skill. If the user wants to re-open, they can run `gh pr reopen <n>` themselves.

## Speed notes

Total wall time: usually under 2 seconds (one `gh pr close` + one `gh api DELETE`). No polling, no rebase, no local checkout of the branch required.
