#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

echo "Project root: $ROOT_DIR"
echo

for proj in $(find . -name "*.xcodeproj"); do
  pbx="$proj/project.pbxproj"
  [ -f "$pbx" ] || continue
  echo "---- $proj ----"
  # list INFOPLIST_FILE matches with line numbers
  if ! grep -n "INFOPLIST_FILE" "$pbx" >/dev/null 2>&1; then
    echo "  (no INFOPLIST_FILE entries found)"
    echo
    continue
  fi

  while IFS= read -r match; do
    ln=${match%%:*}
    rest=${match#*:}
    echo "Match at line $ln: $rest"
    # print surrounding context for inspection
    start=$(( ln > 80 ? ln - 80 : 1 ))
    end=$(( ln + 10 ))
    echo "---- context (lines ${start}-${end}) ----"
    sed -n "${start},${end}p" "$pbx"
    echo "---- nearest commented identifier above the match (likely target/config name) ----"
    # attempt to find the nearest '/* <Name> */' line above the match within 200 lines
    up_start=$(( ln > 200 ? ln - 200 : 1 ))
    nearest=$(sed -n "${up_start},$((ln-1))p" "$pbx" | tac | grep -m1 -E '/\* [^*]+ \*/' || true)
    if [ -n "$nearest" ]; then
      echo "$nearest"
    else
      echo "(no nearby commented identifier found)"
    fi
    echo "========================================"
  done < <(grep -n "INFOPLIST_FILE" "$pbx" || true)

  echo
done

exit 0
