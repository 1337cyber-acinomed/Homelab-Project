#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; relpath="$(b64d "$2")"; content_b64="$3"
check_relpath "$relpath"
target="$ws_path/$relpath"
mkdir -p "$(dirname "$target")"
b64d "$content_b64" > "$target"
echo "wrote $relpath ($(wc -c < "$target") bytes)"