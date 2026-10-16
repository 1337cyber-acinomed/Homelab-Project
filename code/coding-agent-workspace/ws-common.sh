# sourced by every ws-*.sh script, and by the three real SSH entry points
# (ws-dispatch.sh, start-workspace.sh, propose.sh)
WORKSPACE_ROOT="/root/workspaces"

reject() { echo "REJECTED: $1"; exit 2; }

check_relpath() {
  local p="$1"
  [ -n "$p" ] || reject "empty path"
  [[ "$p" != /* ]] || reject "absolute paths are not allowed"
  [[ "$p" != *..* ]] || reject "path traversal is not allowed"
  [[ "$p" != .git/* && "$p" != ".git" ]] || reject "the .git directory is off-limits"
}

b64d() { printf '%s' "$1" | base64 -d; }
b64e() { base64 -w0; }

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

# Populates the global array TOKENS from $SSH_ORIGINAL_COMMAND: strips
# n8n's known "cd <dir> ; " prefix, tokenizes with read -ra (any run of
# whitespace between tokens, never touching what's inside one), then
# trims each token on both ends only. Used only by the three scripts a
# real SSH connection invokes directly — never by the five internal
# ws-*.sh scripts, which the dispatcher always calls with plain argv.
parse_ssh_tokens() {
  local raw="${SSH_ORIGINAL_COMMAND:-}"
  local stripped="${raw#*;}"
  read -ra TOKENS <<< "$stripped"
  local i
  for i in "${!TOKENS[@]}"; do
    TOKENS[i]="$(trim "${TOKENS[i]}")"
  done
}

LOG_FILE="/root/logs/coding-agent-dispatcher.log"

# Runs a command; on failure, logs full output+context to LOG_FILE (for
# the user's own troubleshooting) and exits 1 with one generic message —
# never lets raw internals (hosts, key paths, git errors) reach the
# agent. On success, streams output normally and returns 0.
run_or_log() {
  local label="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then
    printf '%s' "$out"
    return 0
  else
    local code=$?
    printf '%s [%s] step=%s exit=%s output=%s\n' \
      "$(date -Is)" "$$" "$label" "$code" "$out" >> "$LOG_FILE"
    echo "ERROR: the ${label} step failed unexpectedly"
    exit 1
  fi
}