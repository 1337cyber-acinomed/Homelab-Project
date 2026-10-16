#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"
[[ "$ws_path" == "$WORKSPACE_ROOT"/* ]] || reject "refusing to delete outside workspace root"
ws_id="$(basename "$ws_path")"
rm -rf -- "$ws_path"
rm -f -- "$WORKSPACE_ROOT/$ws_id.meta"
echo "discarded $ws_path"