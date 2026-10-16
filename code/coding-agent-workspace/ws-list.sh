#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; subpath="$(b64d "$2")"
[ -z "$subpath" ] && subpath="."
check_relpath "$subpath"
target="$ws_path/$subpath"
[ -d "$target" ] || reject "not a directory"
ls -la "$target"