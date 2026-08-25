# Using prepr with Codex (or any non-Claude agent)

The skills in this package are just Markdown instructions + a bash CLI. Any agent that can run a shell command can drive them — the SKILL.md files are the Claude Code entry point, but Codex, Cursor, Cline, Aider, and shell users can all invoke the same `prepr` binary directly.

## Option 1 — Codex custom prompts

Codex reads custom prompts from `~/.codex/prompts/*.md` (user scope) or `.codex/prompts/*.md` inside a repo (project scope). Copy the three files in this directory to either location:

```bash
mkdir -p ~/.codex/prompts
cp examples/codex/prepr-open.md   ~/.codex/prompts/
cp examples/codex/prepr-review.md ~/.codex/prompts/
cp examples/codex/prepr-close.md  ~/.codex/prompts/
```

Then invoke from Codex with `/prepr-open PLAN.md`, `/prepr-review`, `/prepr-close`.

## Option 2 — Just tell the agent to run the CLI

The CLI is small and self-documenting. In any agent, you can say:

> Run `prepr open PLAN.md` and give me the URL.
> Run `prepr review` and summarize the NEW section.
> Run `prepr close` after confirming with me.

The three SKILL.md files under `skills/` describe the exact behaviors and guardrails — copy/paste their bodies into a system prompt if you want the same discipline in an agent that doesn't have a native "skill" concept.

## Requirements

- `git`, `gh` (authenticated), `jq` on PATH
- Node 18+ *only* if you install via `npx` — the CLI itself is bash
