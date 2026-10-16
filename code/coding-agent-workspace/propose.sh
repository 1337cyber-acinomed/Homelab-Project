#!/bin/bash
set -eu
source /root/bin/ws-common.sh

# Hard prerequisites, checked once, explicitly — never left to fail silently
# mid-expansion inside another command's argument list.
require() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '%s [%s] step=prereq missing=%s\n' "$(date -Is)" "$$" "$1" >> "$LOG_FILE"
    echo "ERROR: the coding agent's environment is not fully set up"
    exit 1
  }
}
require jq
require curl
[ -r /root/.polaris_coding_agent_api_token ] || {
  printf '%s [%s] step=prereq missing=api-token-file\n' "$(date -Is)" "$$" >> "$LOG_FILE"
  echo "ERROR: the coding agent's environment is not fully set up"
  exit 1
}
api_token="$(cat /root/.polaris_coding_agent_api_token)"

parse_ssh_tokens
ws_id="${TOKENS[0]:-}"
commit_msg_b64="${TOKENS[1]:-}"

ws_path="$WORKSPACE_ROOT/$ws_id"
meta_path="$WORKSPACE_ROOT/$ws_id.meta"
[ -d "$ws_path" ]   || reject "workspace not found"
[ -f "$meta_path" ] || reject "workspace metadata missing"

repo="$(grep '^repo=' "$meta_path" | cut -d= -f2-)"
mode="$(grep '^mode=' "$meta_path" | cut -d= -f2-)"
commit_msg="$(b64d "$commit_msg_b64")"

# A real, nameable case: nothing has actually changed since the last
# propose (or since clone). Reject plainly rather than let an empty
# commit fall through into a generic crash.
git -C "$ws_path" add -A
if git -C "$ws_path" diff --cached --quiet; then
  reject "no changes to propose"
fi

check_output="$("/root/bin/ws-run-checks.sh" "$ws_path")"
if printf '%s' "$check_output" | grep -qE 'exit=[1-9]'; then
  status_line="checks still failing"
else
  status_line="checks passing"
fi

cd "$ws_path"
if [ "$mode" = "new" ]; then
  branch="coding-agent-$(date +%Y%m%d-%H%M%S)"
  git checkout --quiet -b "$branch"
fi

run_or_log "commit" git -c user.email="polaris-coding-agent@polaris.homelab" \
  -c user.name="Polaris Coding Agent" commit --quiet -m "$commit_msg" > /dev/null

run_or_log "push" env GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git push --quiet origin "$branch" > /dev/null

if [ "$mode" = "new" ]; then
  pr_title="[$status_line] $commit_msg"
  pr_body="$(printf '## Check output\n\n```\n%s\n```\n' "$check_output")"
  if payload="$(jq -n --arg t "$pr_title" --arg b "$pr_body" --arg h "$branch" \
                '{title:$t, body:$b, head:$h, base:"main"}' 2>&1)"; then
    :
  else
    code=$?
    printf '%s [%s] step=build-payload exit=%s output=%s\n' "$(date -Is)" "$$" "$code" "$payload" >> "$LOG_FILE"
    echo "ERROR: the open-pr step failed unexpectedly"
    exit 1
  fi
  run_or_log "open-pr" curl -sf -X POST \
    "http://192.168.10.20:3001/api/v1/repos/lab-admin/${repo}/pulls" \
    -H "Authorization: token $api_token" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null
  echo "proposed: $status_line, PR opened on $repo"
else
  branch="$(grep '^branch=' "$meta_path" | cut -d= -f2-)"
  pr_number="$(grep '^pr_number=' "$meta_path" | cut -d= -f2-)"
  comment_body="$(printf '## Revision pushed: %s\n\n```\n%s\n```\n' "$status_line" "$check_output")"
  if payload="$(jq -n --arg b "$comment_body" '{body:$b}' 2>&1)"; then
    :
  else
    code=$?
    printf '%s [%s] step=build-payload exit=%s output=%s\n' "$(date -Is)" "$$" "$code" "$payload" >> "$LOG_FILE"
    echo "ERROR: the post-comment step failed unexpectedly"
    exit 1
  fi
  run_or_log "post-comment" curl -sf -X POST \
    "http://192.168.10.20:3001/api/v1/repos/lab-admin/${repo}/issues/${pr_number}/comments" \
    -H "Authorization: token $api_token" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null
  echo "proposed: $status_line, comment posted on PR #$pr_number"
fi