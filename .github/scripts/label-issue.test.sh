#!/usr/bin/env bash
# Table tests for label-issue.sh's title classification.  No network.
#   bash .github/scripts/label-issue.test.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
fails=0

check() {
  local title=$1 want=$2 got
  got=$(bash "$here/label-issue.sh" --print "$title" | paste -sd' ')
  if [[ "$got" == "$want" ]]; then
    echo "ok    $title"
  else
    echo "FAIL  $title"; echo "      want: $want"; echo "      got:  $got"
    fails=$((fails + 1))
  fi
}

check 'fix(ssh): banner timeout'                 'bug area:ssh'
check 'feat: add agent-sessions'                 'enhancement'
check 'feat(docker)!: drop rootful mode'         'enhancement breaking area:docker'
check 'docs(agent-host): explain swap'           'documentation area:agent-host'
check 'perf: faster probe'                       'performance'
check 'ci: bump checkout'                        'maintenance'
check 'chore(release): v0.2.0'                   'maintenance area:release'
check 'fix(ssh, wifi): two scopes'               'bug area:ssh area:wifi'
check 'Fix(SSH): case-insensitive type'          'bug area:ssh'
check 'fix(Weird Scope!!): sanitised'            'bug area:weird-scope'
check 'fix: incident 2026-10-12 slow link'       'bug incident'
check 'Incident: dev unreachable'                'needs-triage incident'
check 'docs: incidents index'                    'documentation'
check 'remote ssh is broken'                     'needs-triage'
check 'wip: unknown type'                        'needs-triage'
check 'fix:no space after colon'                 'needs-triage'
check 'fix(): empty scope'                       'bug'
check 'fix(<scope>): template placeholder kept'  'bug'
# shellcheck disable=SC2016  # literal on purpose: the title must not expand
check 'fix(ssh): $(touch /tmp/pwned) `id`'       'bug area:ssh'

if (( fails )); then echo "$fails failed"; exit 1; fi
echo "all passed"
