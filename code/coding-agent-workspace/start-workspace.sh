#!/bin/bash
set -eu
source /root/bin/ws-common.sh

parse_ssh_tokens
repo="${TOKENS[0]:-}"
mode="${TOKENS[1]:-}"

case "$repo" in
  Polaris-Pipeline-Testing|Project_Polaris|homelab-infrastructure) ;;
  *) reject "unknown repo" ;;
esac

ws_id="task-$(date +%Y%m%d-%H%M%S)-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
ws_path="$WORKSPACE_ROOT/$ws_id"

run_or_log "clone" env \
  GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git clone --quiet "ssh://git@192.168.10.20:2222/lab-admin/${repo}.git" "$ws_path" > /dev/null

case "$mode" in
  new)
    { echo "repo=$repo"; echo "mode=new"; } > "$WORKSPACE_ROOT/$ws_id.meta"
    ;;
  revise)
    branch="${TOKENS[2]:-}"; pr_number="${TOKENS[3]:-}"
    [[ "$branch" =~ ^coding-agent-[0-9]{8}-[0-9]{6}$ ]] || reject "not a coding-agent branch"
    [[ "$pr_number" =~ ^[0-9]+$ ]] || reject "invalid PR number"
    # A real, nameable case, not a generic crash: the branch may genuinely
    # be gone (PR closed, branch deleted) — check explicitly and reject
    # plainly rather than let checkout fail into the generic path.
    git -C "$ws_path" show-ref --verify --quiet "refs/remotes/origin/$branch" \
      || reject "that branch no longer exists on the remote"
    git -C "$ws_path" checkout --quiet "$branch"
    { echo "repo=$repo"; echo "mode=revise"; echo "branch=$branch"; echo "pr_number=$pr_number"; } \
      > "$WORKSPACE_ROOT/$ws_id.meta"
    ;;
  *) reject "unknown mode" ;;
esac

echo "$ws_id"