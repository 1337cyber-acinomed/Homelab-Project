#!/bin/bash
set -eu
set -o pipefail

BIN_DIR="/root/bin"
WORKSPACE_ROOT="/root/workspaces"
LOG_FILE="/root/logs/coding-agent-dispatcher.log"

fail() { echo "ERROR: $1"; exit 1; }

raw="${SSH_ORIGINAL_COMMAND:-}"
stripped="${raw#*;}"
read -ra tokens <<< "$stripped"
[ "${#tokens[@]}" -ge 2 ] || fail "malformed request"

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

op="$(trim "${tokens[0]}")"
ws_id="$(trim "${tokens[1]}")"

case "$op" in
  list|read|write|run-checks|discard) ;;
  *) fail "unknown operation" ;;
esac

[[ "$ws_id" =~ ^task-[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$ ]] || fail "invalid workspace id"

ws_path="$WORKSPACE_ROOT/$ws_id"
[ -d "$ws_path" ] || fail "workspace not found"

script="$BIN_DIR/ws-${op}.sh"
if out="$("$script" "$ws_path" "${tokens[@]:2}" 2>&1)"; then
  printf '%s' "$out"
else
  code=$?
  if [ "$code" -eq 2 ]; then
    printf '%s' "$out"
  else
    printf '%s [%s] op=%s ws=%s exit=%s output=%s\n' \
      "$(date -Is)" "$$" "$op" "$ws_id" "$code" "$out" >> "$LOG_FILE"
    fail "the ${op} step failed unexpectedly"
  fi
fi