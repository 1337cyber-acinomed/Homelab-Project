#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; shift
git -C "$ws_path" add -A
changed="$(git -C "$ws_path" diff --name-only --cached HEAD)"
for a in "$@"; do
  extra="$(b64d "$a")"; check_relpath "$extra"
  changed="$changed
$extra"
done
changed="$(printf '%s\n' "$changed" | sort -u | sed '/^$/d')"

if [ -z "$changed" ]; then
  echo "no changes since clone"
  exit 0
fi

while IFS= read -r f; do
  echo "FILE: $f"
  case "$f" in
    *.sh)
      echo "--- bash -n ---"
      set +e; bash -n "$ws_path/$f" 2>&1; bn_ec=$?; set -e
      echo "exit=$bn_ec"
      echo "--- shellcheck ---"
      set +e; shellcheck "$ws_path/$f" 2>&1; sc_ec=$?; set -e
      echo "exit=$sc_ec"
      ;;
    *.py)
      echo "--- flake8 ---"
      set +e; python3 -m flake8 "$ws_path/$f" 2>&1; fl_ec=$?; set -e
      echo "exit=$fl_ec"
      ;;
    *.json)
      echo "--- jq empty (syntax check) ---"
      set +e; jq empty "$ws_path/$f" 2>&1; jq_ec=$?; set -e
      echo "exit=$jq_ec"
      ;;
    *.cpp|*.cc|*.cxx|*.hpp|*.h|*.hh)
      echo "--- cppcheck ---"
      set +e
      cppcheck --enable=warning,style,performance,portability \
        --suppress=missingIncludeSystem --error-exitcode=1 "$ws_path/$f" 2>&1
      cc_ec=$?
      set -e
      echo "exit=$cc_ec"
      ;;
    *.html|*.htm)
      echo "--- tidy ---"
      set +e; tidy -errors -quiet "$ws_path/$f" 2>&1; td_ec=$?; set -e
      echo "exit=$td_ec"
      ;;
    *)
      echo "no checker configured for this file type yet"
      ;;
  esac
  echo "==="
done <<< "$changed"
exit 0