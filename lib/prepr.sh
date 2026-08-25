# prepr core — sourced by bin/prepr.
# Keeps everything in one file so distribution is a single package.
# Every path through the CLI is designed to complete in a few seconds:
# no LLM calls, no polling loops — just gh/git/jq.

# ---------- utilities ----------

prepr_die() { echo "prepr: $*" >&2; exit 1; }

prepr_need() {
  command -v "$1" >/dev/null 2>&1 || prepr_die "required tool not found: $1"
}

prepr_check_deps() {
  prepr_need git
  prepr_need gh
  prepr_need jq
}

prepr_usage() {
  cat <<'EOF'
prepr — publish planning docs as draft PRs, collect review, close them out.

  prepr open   <plan-file> [--title T] [--base B] [--reviewer U] [--label L]
  prepr review [PR] [--ack ID[,ID...]] [--reset] [--json]
  prepr close  [PR] [--keep-branch] [--yes]
  prepr status

PR may be a number (123), a slug (owner/repo#123), or a URL.
If omitted, the "current" plan PR for the repo is used (recorded at open time).
EOF
}

# Fail loudly if the cwd isn't a GitHub repo gh can see. Call this at the
# start of a subcommand so later $(...) uses of prepr_repo_slug are guaranteed
# to succeed (prepr_die inside command substitution only kills the subshell).
prepr_ensure_repo() {
  gh repo view --json nameWithOwner -q .nameWithOwner >/dev/null 2>&1 \
    || prepr_die "gh could not resolve the current repo — is 'origin' a GitHub remote and are you 'gh auth login'ed?"
}

# owner/repo for the current git remote. Precondition: prepr_ensure_repo passed.
prepr_repo_slug() {
  gh repo view --json nameWithOwner -q .nameWithOwner
}

# Return the git repo top-level directory. Precondition: prepr_ensure_repo
# (or an equivalent 'we're inside a repo' check) has been called upstream.
prepr_repo_root() {
  git rev-parse --show-toplevel
}

prepr_default_branch() {
  gh repo view --json defaultBranchRef -q .defaultBranchRef.name
}

prepr_state_dir() {
  local slug root
  slug="$(prepr_repo_slug)"
  root="${PREPR_HOME:-$HOME/.prepr}"
  mkdir -p "$root/state/${slug//\//__}"
  echo "$root/state/${slug//\//__}"
}

prepr_current_file() { echo "$(prepr_state_dir)/current"; }

prepr_state_file() {
  local num="$1"
  echo "$(prepr_state_dir)/pr-${num}.json"
}

prepr_slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-40
}

prepr_title_from_file() {
  local f="$1" t
  t="$(grep -m1 -E '^#[[:space:]]+' "$f" | sed -E 's/^#+[[:space:]]+//')"
  [ -n "$t" ] && { echo "$t"; return; }
  basename "$f" | sed -E 's/\.[Mm][Dd]$//'
}

# Resolve a PR argument (number / owner/repo#num / URL / empty) to a number.
# If empty, reads from the "current" marker.
prepr_resolve_pr_arg() {
  local arg="${1:-}"
  if [ -z "$arg" ]; then
    local cur="$(prepr_current_file)"
    [ -s "$cur" ] || prepr_die "no PR given and no current plan PR recorded (run 'prepr open' first, or pass a PR number)"
    cat "$cur"
    return
  fi
  if [[ "$arg" =~ /pull/([0-9]+) ]]; then echo "${BASH_REMATCH[1]}"; return; fi
  if [[ "$arg" =~ \#([0-9]+)$ ]];   then echo "${BASH_REMATCH[1]}"; return; fi
  if [[ "$arg" =~ ^[0-9]+$ ]];      then echo "$arg";              return; fi
  prepr_die "could not parse PR reference: $arg"
}

# ---------- open ----------

prepr_open() {
  # Early help — must work even outside a repo / without deps installed.
  for a in "$@"; do case "$a" in -h|--help)
    echo "prepr open <plan-file> [--title T] [--base B] [--reviewer U] [--label L]"; return 0 ;;
  esac; done

  prepr_check_deps
  prepr_ensure_repo

  local plan_file="" title="" base="" reviewer="" label=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title)    title="$2"; shift 2 ;;
      --base)     base="$2"; shift 2 ;;
      --reviewer) reviewer="$2"; shift 2 ;;
      --label)    label="$2"; shift 2 ;;
      -h|--help)  echo "prepr open <plan-file> [--title T] [--base B] [--reviewer U] [--label L]"; return 0 ;;
      -*)         prepr_die "unknown flag: $1" ;;
      *)          [ -z "$plan_file" ] && plan_file="$1" || prepr_die "unexpected arg: $1"; shift ;;
    esac
  done

  [ -n "$plan_file" ] || prepr_die "usage: prepr open <plan-file>"
  [ -f "$plan_file" ] || prepr_die "plan file not found: $plan_file"

  local repo_root plan_abs slug
  repo_root="$(prepr_repo_root)"
  plan_abs="$(cd -P "$(dirname "$plan_file")" && pwd)/$(basename "$plan_file")"
  slug="$(prepr_repo_slug)"

  [ -z "$base" ] && base="$(prepr_default_branch)"
  [ -z "$title" ] && title="Plan: $(prepr_title_from_file "$plan_abs")"

  git -C "$repo_root" fetch --quiet origin "$base" || prepr_die "could not fetch origin/$base"

  local ts branch worktree
  ts="$(date -u +%Y%m%d-%H%M%S)"
  branch="plan/${ts}-$(prepr_slugify "$title")"
  worktree="$(mktemp -d -t prepr-XXXXXX)"

  git -C "$repo_root" worktree add -q -b "$branch" "$worktree" "origin/$base"

  # shellcheck disable=SC2064
  trap "git -C '$repo_root' worktree remove --force '$worktree' >/dev/null 2>&1 || true" EXIT

  local dest
  case "$plan_abs" in
    *.md|*.MD|*.markdown) dest="$worktree/$(basename "$plan_abs")" ;;
    *)                    dest="$worktree/PLAN.md" ;;
  esac
  cp "$plan_abs" "$dest"

  git -C "$worktree" add "$(basename "$dest")"
  git -C "$worktree" -c commit.gpgsign=false commit -q -m "plan: $title"
  git -C "$worktree" push -q -u origin "$branch"

  local body_file="$worktree/.pr-body.md"
  {
    echo "> Draft plan for review. Created by prepr."
    echo
    echo "**Plan file:** \`$(basename "$dest")\`"
    echo
    echo "---"
    echo
    cat "$dest"
  } > "$body_file"

  local args=(pr create --draft --base "$base" --head "$branch" --title "$title" --body-file "$body_file")
  [ -n "$reviewer" ] && args+=(--reviewer "$reviewer")
  [ -n "$label" ]    && args+=(--label    "$label")

  local url
  url="$(cd "$worktree" && gh "${args[@]}")" \
    || prepr_die "gh pr create failed"

  local num
  num="$(echo "$url" | sed -E 's|.*/pull/([0-9]+).*|\1|')"

  echo -n "$num" > "$(prepr_current_file)"

  local sf; sf="$(prepr_state_file "$num")"
  jq -n \
    --arg pr    "${slug}#${num}" \
    --arg url   "$url" \
    --arg br    "$branch" \
    --arg base  "$base" \
    --arg file  "$(basename "$dest")" \
    --arg title "$title" \
    '{pr:$pr,url:$url,branch:$br,base:$base,file:$file,title:$title,seen:{},resolved:{}}' \
    > "$sf"

  cat <<EOF
Draft plan PR opened.
  Repo:    $slug
  Branch:  $branch  (base: $base)
  File:    $(basename "$dest")
  Title:   $title
  URL:     $url

PR=$num URL=$url
EOF
}

# ---------- review ----------

prepr_review() {
  for a in "$@"; do case "$a" in -h|--help)
    echo "prepr review [PR] [--ack ID[,ID...]] [--reset] [--json]"; return 0 ;;
  esac; done

  prepr_check_deps
  prepr_ensure_repo

  local pr_arg="" ack="" reset=0 as_json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --ack)   ack="$2"; shift 2 ;;
      --reset) reset=1; shift ;;
      --json)  as_json=1; shift ;;
      -h|--help) echo "prepr review [PR] [--ack ID[,ID...]] [--reset] [--json]"; return 0 ;;
      -*)      prepr_die "unknown flag: $1" ;;
      *)       [ -z "$pr_arg" ] && pr_arg="$1" || prepr_die "unexpected arg: $1"; shift ;;
    esac
  done

  local num slug sf
  num="$(prepr_resolve_pr_arg "$pr_arg")"
  slug="$(prepr_repo_slug)"
  sf="$(prepr_state_file "$num")"
  [ -f "$sf" ] || echo '{"seen":{},"resolved":{}}' > "$sf"

  if [ -n "$ack" ]; then
    local tmp; tmp="$(mktemp)"
    local ids_json
    ids_json="$(echo "$ack" | tr ',' '\n' | jq -R . | jq -s .)"
    jq --argjson ids "$ids_json" '
      .resolved = ((.resolved // {}) + (reduce $ids[] as $i ({}; .[$i|tostring] = (now|todate))))
    ' "$sf" > "$tmp" && mv "$tmp" "$sf"
    echo "Marked resolved: $ack"
    return
  fi

  if [ "$reset" -eq 1 ]; then
    local tmp; tmp="$(mktemp)"
    jq '.seen = {} | .resolved = {}' "$sf" > "$tmp" && mv "$tmp" "$sf"
    echo "State reset for PR #$num."
    return
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  gh api --paginate "repos/$slug/issues/$num/comments" > "$tmpdir/issue.json" &
  local p1=$!
  gh api --paginate "repos/$slug/pulls/$num/comments" > "$tmpdir/review.json" &
  local p2=$!
  gh api --paginate "repos/$slug/pulls/$num/reviews" > "$tmpdir/reviews.json" &
  local p3=$!
  wait $p1 $p2 $p3

  local unified
  unified="$(
    jq -s '
      (.[0] | add // [] | map({
        id: ("ic-" + (.id|tostring)),
        kind: "conversation",
        author: (.user.login // "unknown"),
        created: .created_at,
        url: .html_url,
        body: (.body // ""),
        path: null, line: null
      }))
      +
      (.[1] | add // [] | map({
        id: ("rc-" + (.id|tostring)),
        kind: "inline",
        author: (.user.login // "unknown"),
        created: .created_at,
        url: .html_url,
        body: (.body // ""),
        path: (.path // null),
        line: (.line // .original_line // null)
      }))
      +
      (.[2] | add // [] | map(select((.body // "") != "" or .state == "CHANGES_REQUESTED")) | map({
        id: ("rv-" + (.id|tostring)),
        kind: ("review-" + ((.state // "COMMENTED")|ascii_downcase)),
        author: (.user.login // "unknown"),
        created: .submitted_at,
        url: .html_url,
        body: (.body // "(no summary)"),
        path: null, line: null
      }))
      | sort_by(.created)
    ' "$tmpdir/issue.json" "$tmpdir/review.json" "$tmpdir/reviews.json"
  )"

  local report
  report="$(
    jq -n \
      --argjson all "$unified" \
      --slurpfile st "$sf" \
      '
      ($st[0].seen // {})     as $seen |
      ($st[0].resolved // {}) as $resolved |
      {
        new:        ($all | map(select($seen[.id]     | not) | select($resolved[.id] | not))),
        open:       ($all | map(select($seen[.id])          | select($resolved[.id] | not))),
        resolved:   ($all | map(select($resolved[.id])))
      }
      '
  )"

  local tmp; tmp="$(mktemp)"
  jq --argjson all "$unified" '
    .seen = ((.seen // {}) + (reduce $all[] as $c ({}; .[$c.id] = $c.created)))
    | .last_fetched_at = (now|todate)
  ' "$sf" > "$tmp" && mv "$tmp" "$sf"

  if [ "$as_json" -eq 1 ]; then
    echo "$report"
    return
  fi

  local new_n open_n res_n url
  new_n="$(echo "$report"  | jq '.new       | length')"
  open_n="$(echo "$report" | jq '.open      | length')"
  res_n="$(echo "$report"  | jq '.resolved  | length')"
  url="$(jq -r '.url // empty' "$sf")"

  echo "Plan PR $slug#$num  ($url)"
  echo "  New: $new_n   Open: $open_n   Resolved: $res_n"
  echo

  _prepr_render_section() {
    local label="$1" key="$2"
    local n; n="$(echo "$report" | jq --arg k "$key" '.[$k] | length')"
    [ "$n" = "0" ] && return
    echo "── $label ($n) ──"
    echo "$report" | jq -r --arg k "$key" '
      .[$k][] |
      "• [\(.id)] \(.kind) — @\(.author) \(.created)\n"
      + (if .path then "  \(.path):\(.line // "?")\n" else "" end)
      + "  \(.url)\n"
      + (.body | split("\n") | map("  │ " + .) | join("\n"))
      + "\n"
    '
  }

  _prepr_render_section "TO ADDRESS (new since last fetch)" new
  _prepr_render_section "STILL OPEN (previously surfaced)"  open

  cat <<EOF
Next steps:
  • Update the plan yourself — the agent will not edit it for you.
  • Once a comment is addressed, mark it resolved:
      prepr review --ack <id>[,<id>...]
  • When the plan is finalized:
      prepr close
EOF
}

# ---------- close ----------

prepr_close() {
  for a in "$@"; do case "$a" in -h|--help)
    echo "prepr close [PR] [--keep-branch] [--yes]"; return 0 ;;
  esac; done

  prepr_check_deps
  prepr_ensure_repo

  local pr_arg="" keep=0 assume_yes=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --keep-branch) keep=1; shift ;;
      --yes|-y)      assume_yes=1; shift ;;
      -h|--help)     echo "prepr close [PR] [--keep-branch] [--yes]"; return 0 ;;
      -*)            prepr_die "unknown flag: $1" ;;
      *)             [ -z "$pr_arg" ] && pr_arg="$1" || prepr_die "unexpected arg: $1"; shift ;;
    esac
  done

  local num slug
  num="$(prepr_resolve_pr_arg "$pr_arg")"
  slug="$(prepr_repo_slug)"

  local sf branch url
  sf="$(prepr_state_file "$num")"
  if [ -f "$sf" ]; then
    branch="$(jq -r '.branch // empty' "$sf")"
    url="$(jq -r '.url // empty' "$sf")"
  fi
  if [ -z "${branch:-}" ]; then
    branch="$(gh pr view "$num" --json headRefName -q .headRefName)"
  fi
  [ -n "${url:-}" ] || url="$(gh pr view "$num" --json url -q .url)"

  if [ "$assume_yes" -ne 1 ]; then
    echo "About to CLOSE plan PR $slug#$num and DELETE remote branch '$branch'."
    echo "  $url"
    printf "Proceed? [y/N] "
    read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) echo "Aborted."; return 1 ;; esac
  fi

  gh pr close "$num" --comment "Plan finalized; closing via prepr." >/dev/null \
    || prepr_die "failed to close PR #$num"

  if [ "$keep" -ne 1 ] && [ -n "$branch" ]; then
    gh api -X DELETE "repos/$slug/git/refs/heads/$branch" >/dev/null 2>&1 \
      || echo "warning: could not delete remote branch '$branch' (already gone?)" >&2

    local repo_root; repo_root="$(prepr_repo_root 2>/dev/null || true)"
    if [ -n "$repo_root" ]; then
      git -C "$repo_root" worktree prune >/dev/null 2>&1 || true
      git -C "$repo_root" branch -D "$branch" >/dev/null 2>&1 || true
    fi
  fi

  local cur; cur="$(prepr_current_file)"
  [ -f "$cur" ] && [ "$(cat "$cur")" = "$num" ] && rm -f "$cur"
  rm -f "$sf"

  echo "Plan PR #$num closed and branch '$branch' removed."
}

# ---------- status ----------

prepr_status() {
  prepr_check_deps
  prepr_ensure_repo
  local cur num
  cur="$(prepr_current_file)"
  if [ ! -s "$cur" ]; then
    echo "No current plan PR for $(prepr_repo_slug)."
    return
  fi
  num="$(cat "$cur")"
  local sf; sf="$(prepr_state_file "$num")"
  echo "Current plan PR for $(prepr_repo_slug): #$num"
  [ -f "$sf" ] && jq '{url,branch,base,file,title,last_fetched_at,seen: (.seen|length), resolved: (.resolved|length)}' "$sf"
}
