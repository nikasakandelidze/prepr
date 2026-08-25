---
name: prepr-review
description: Pull all comments (conversation, inline diff, and reviews) from a plan PR opened by prepr-open, split them into NEW / OPEN / RESOLVED buckets, and surface the ones that need attention. Tracks resolved state locally — the agent does not rely on GitHub's own thread-resolution UI. Use whenever the user asks "any feedback?", "what did they say on the plan PR?", "pull the plan comments", etc.
---

# prepr-review

Fetches feedback on the plan PR and shows the user what still needs their attention. State is tracked locally (`~/.prepr/state/<owner>__<repo>/pr-<n>.json`) so that:

- **NEW** = comment seen for the first time on this fetch.
- **OPEN** = comment we've surfaced before but the user hasn't marked resolved.
- **RESOLVED** = user explicitly acknowledged it (see `--ack` below).

This means the *user* controls what "resolved" means. GitHub's own "resolved thread" UI is not consulted (it only applies to inline review threads anyway).

## When to use

- User asks: "any feedback on the plan?" / "check the plan PR for comments" / "what's outstanding?"
- After teammates have had time to review — this is safe to call repeatedly; the state tracks progress.

## Preconditions

- `git`, `gh`, `jq` on PATH.
- Inside the same repo where the plan PR was published (state is keyed to `owner/repo`).
- If no `PR` is given, a "current" plan PR must have been recorded by `prepr open`. Otherwise, ask the user for the PR number/URL.

## How to invoke

```bash
prepr review [PR] [--ack ID[,ID...]] [--reset] [--json]
```

- `PR`: number (`123`), slug (`owner/repo#123`), or URL. Optional — falls back to the repo's current plan PR.
- `--ack ID[,ID...]`: mark those comment IDs as resolved. IDs are the bracketed tokens the tool prints (e.g. `[rc-2091834]`). Does **not** touch GitHub.
- `--reset`: forget all local seen/resolved state for this PR (useful if you want everything re-surfaced as NEW).
- `--json`: emit a machine-readable report instead of the human-formatted one — useful if you want to re-render or filter in-agent.

## Output shape

Human mode prints:

```
Plan PR owner/repo#123  (https://github.com/…/pull/123)
  New: 2   Open: 3   Resolved: 4

── TO ADDRESS (new since last fetch) (2) ──
• [rc-2091834] inline — @alice 2026-08-25T18:02:11Z
  PLAN.md:42
  https://github.com/…#discussion_r2091834
  │ I'd split step 3 into 3a/3b — the DB migration
  │ can't run in the same transaction.

…
── STILL OPEN (previously surfaced) (3) ──
• [ic-901] conversation — @bob …
```

JSON mode returns `{new:[...], open:[...], resolved:[...]}` with the same records.

## What to do with the output

1. Present the NEW section prominently to the user — those are the comments that most need attention.
2. Summarize each: who said what, on which line, and (importantly) what change the plan would need.
3. **Do not edit the plan file yourself.** The rule for this skill set: only the *human* updates the plan. Once they've updated it, they can mark the addressed comments resolved with `prepr review --ack <id>[,<id>…]`.
4. If the user says "mark #… as resolved", run the `--ack` form for them.
5. If the plan is done, hand off to [[prepr-close]].

## Speed notes

The three comment surfaces (issue comments, inline review comments, review submissions) are fetched in parallel via `gh api --paginate`. Typical latency: 1–3 seconds for small PRs. There is no polling, no LLM in the loop.

## Guardrails

- Never call `gh api` yourself to fetch comments — use the CLI so the state file stays consistent.
- If the user changed repos and there is no current PR, ask for the PR reference; do **not** guess.
- Do not re-`--ack` IDs the user didn't name. Acking is an explicit action.
