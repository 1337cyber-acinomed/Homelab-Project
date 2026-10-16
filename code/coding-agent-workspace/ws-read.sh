#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; relpath="$(b64d "$2")"
check_relpath "$relpath"
target="$ws_path/$relpath"
[ -f "$target" ] || reject "file does not exist (use list for directories)"
b64e < "$target"
