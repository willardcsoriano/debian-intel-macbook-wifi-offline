#!/usr/bin/env bash
# label-issue.sh -- classify a GitHub issue from its Conventional Commits title.
#
#   fix(ssh): ...         -> bug, area:ssh
#   feat(docker)!: ...    -> enhancement, area:docker, breaking
#   docs: ...             -> documentation
#   anything "incident"   -> incident (whole word, any case)
#   no recognisable type  -> needs-triage
#
# Deterministic: the same title always yields the same labels, no LLM, no
# network beyond the GitHub API.  Run by .github/workflows/issue-labeler.yml;
# also runnable by hand:
#
#   label-issue.sh --print "fix(ssh): banner timeout"     # print labels, touch nothing
#   ISSUE_NUMBER=12 ISSUE_TITLE="..." label-issue.sh      # apply (needs gh auth)
#
# ISSUE_ACTION=opened adds one explanatory comment when the title is unclassifiable.
#
# On a retitle, pass the old title in ISSUE_OLD_TITLE: labels the old title
# produced and the new one doesn't are removed.  Labels added by hand are
# never removed, because they were never produced from a title.
#
# The title arrives through the environment, never interpolated into the
# workflow's shell, so a crafted issue title can't inject commands.
set -euo pipefail

# Type -> label.  Defaults GitHub creates (bug, enhancement, documentation)
# are reused so hand-labelled and bot-labelled issues share one vocabulary.
type_label() {
  case "$1" in
    fix) echo bug ;;
    feat) echo enhancement ;;
    docs) echo documentation ;;
    perf) echo performance ;;
    refactor | style | test | build | ci | chore | revert) echo maintenance ;;
  esac
}

# Prints one label per line for a title.
labels_for_title() {
  local title=$1 re='^([a-zA-Z]+)(\(([^)]*)\))?(!)?:[[:space:]]' type scope s
  if [[ "$title" =~ $re ]]; then
    type=${BASH_REMATCH[1],,}
    scope=${BASH_REMATCH[3]}
    local tl
    tl=$(type_label "$type")
    if [[ -n "$tl" ]]; then
      echo "$tl"
      [[ -n "${BASH_REMATCH[4]}" ]] && echo breaking
      # Scopes may be comma-separated: fix(ssh,wifi): ...
      IFS=',' read -ra scopes <<<"$scope"
      for s in "${scopes[@]}"; do
        [[ "$s" == *'<'* ]] && continue   # template placeholder left as-is
        s=${s,,}
        s=$(tr -c 'a-z0-9-' '-' <<<"$s" | sed 's/-\{2,\}/-/g; s/^-//; s/-$//')
        [[ -n "$s" ]] && echo "area:${s:0:40}"
      done
    else
      echo needs-triage
    fi
  else
    echo needs-triage
  fi
  shopt -s nocasematch
  [[ "$title" =~ (^|[^a-z])incident([^a-z]|$) ]] && echo incident
  shopt -u nocasematch
  return 0
}

# Colour and description for labels this script may create.
label_meta() {
  case "$1" in
    bug) echo "d73a4a|Something isn't working" ;;
    enhancement) echo "a2eeef|New feature or request" ;;
    documentation) echo "0075ca|Improvements or additions to documentation" ;;
    performance) echo "fbca04|Faster or lighter" ;;
    maintenance) echo "cfd3d7|Refactor, tests, build, CI, chores" ;;
    breaking) echo "b60205|Breaking change (! in the title)" ;;
    incident) echo "e99695|Production or workstation incident" ;;
    needs-triage) echo "ededed|Title isn't Conventional Commits; classify by hand" ;;
    area:*) echo "c5def5|Scope from the issue title" ;;
  esac
}

if [[ "${1:-}" == "--print" ]]; then
  labels_for_title "${2:?usage: label-issue.sh --print TITLE}"
  exit 0
fi

: "${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
: "${ISSUE_TITLE:?ISSUE_TITLE is required}"

mapfile -t want < <(labels_for_title "$ISSUE_TITLE")
mapfile -t existing < <(gh label list --limit 500 --json name --jq '.[].name')

for l in "${want[@]}"; do
  if ! printf '%s\n' "${existing[@]}" | grep -qxF -- "$l"; then
    IFS='|' read -r color desc <<<"$(label_meta "$l")"
    # A concurrent run may have created it a moment ago; that's fine.
    gh label create "$l" --color "$color" --description "$desc" >/dev/null 2>&1 || true
  fi
done

remove=()
if [[ -n "${ISSUE_OLD_TITLE:-}" ]]; then
  mapfile -t old < <(labels_for_title "$ISSUE_OLD_TITLE")
  for l in "${old[@]}"; do
    printf '%s\n' "${want[@]}" | grep -qxF -- "$l" || remove+=("$l")
  done
fi

args=()
(( ${#want[@]} )) && args+=(--add-label "$(IFS=,; echo "${want[*]}")")
(( ${#remove[@]} )) && args+=(--remove-label "$(IFS=,; echo "${remove[*]}")")
gh issue edit "$ISSUE_NUMBER" "${args[@]}" >/dev/null
echo "issue #$ISSUE_NUMBER: +[${want[*]}] -[${remove[*]:-}]"

# One explanatory comment, on open only, when the title couldn't be
# classified.  Never on edits, so fixing a title doesn't add noise.
if [[ "${ISSUE_ACTION:-}" == opened ]] && printf '%s\n' "${want[@]}" | grep -qxF needs-triage; then
  gh issue comment "$ISSUE_NUMBER" --body "Labelled \`needs-triage\`: the title isn't in Conventional Commits form, so it couldn't be classified automatically. Retitle it as \`<type>(<scope>): <summary>\` (type: fix, feat, docs, perf, refactor, test, build, ci, chore, revert) and the labels update themselves." >/dev/null
fi
