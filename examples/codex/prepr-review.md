# /prepr-review

Pull all comments on a plan PR opened by `/prepr-open`, split them into NEW / OPEN / RESOLVED, and surface what needs attention.

State is tracked locally at `~/.prepr/state/<owner>__<repo>/pr-<n>.json` — GitHub's own thread-resolution UI is **not** consulted. "Resolved" only means the user acknowledged it via `--ack`.

## When to run

The user asked "any feedback yet?", "what did they say on the plan?", "pull the plan PR comments", or similar.

## Action

```bash
prepr review [PR] [--ack ID[,ID...]] [--reset] [--json]
```

- `PR`: number, `owner/repo#n`, or URL. Omit to use the repo's current plan PR.
- `--ack ID[,ID...]`: mark those comment IDs as resolved (e.g. `--ack rc-2091834,ic-901`)
- `--reset`: forget all local state so everything re-appears as NEW
- `--json`: emit machine-readable JSON

## After

1. Highlight the **NEW** section — those are what the user most needs to see
2. For each NEW comment, summarize: author, location, and what the plan would need to change
3. **Do NOT edit the plan file.** Only the human updates it. When they say "I addressed X", run `prepr review --ack <id>` for them.
4. If the user says the plan is finalized, hand off to `/prepr-close`.
