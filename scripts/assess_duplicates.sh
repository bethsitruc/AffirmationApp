#!/usr/bin/env bash
set -euo pipefail

# Simple diagnostics to find possible causes of "Multiple commands produce ... Info.plist"
# - duplicate filenames across the repo
# - Info.plist referenced multiple times inside .xcodeproj/project.pbxproj
# - repeated occurrences of a filename inside the pbxproj file
# This enhanced version prints context lines around Info.plist occurrences to help find which
# target blocks reference the same plist path.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

echo "Project root: $ROOT_DIR"
echo

# 1) Duplicate basenames in repo (excluding common noise)
echo "1) Duplicate filenames (same basename in multiple paths):"
find . -type f \
  -not -path "./.git/*" \
  -not -path "./Pods/*" \
  -not -path "./Carthage/*" \
  -print | sed 's|^\./||' | awk -F/ '{print $NF "\t" $0}' | sort | \
  awk -F'\t' ' {count[$1]++; paths[$1]=paths[$1]"\n"$2} END{for (n in count) if (count[n]>1) { print "== " n " ==" paths[n] "\n" }}'
echo

# 2) Info.plist references inside xcodeproj files
echo "2) Info.plist occurrences inside .xcodeproj/project.pbxproj files (with surrounding context):"
shopt -s nullglob
for proj in $(find . -name "*.xcodeproj"); do
  pbx="$proj/project.pbxproj"
  if [ -f "$pbx" ]; then
    echo "---- $proj ----"
    # Show raw matches with line numbers first
    grep -n "Info.plist" "$pbx" || echo "  (no Info.plist strings found)"
    echo

    # For each matched line print surrounding context to help identify which block/target contains it.
    # Use a while-read loop with process substitution (works on macOS bash).
    echo "Context for Info.plist occurrences:"
    matches_found=0
    while IFS= read -r m; do
      matches_found=1
      ln=${m%%:*}
      echo "== around line $ln =="
      start=$(( ln > 5 ? ln - 5 : 1 ))
      end=$(( ln + 5 ))
      sed -n "${start},${end}p" "$pbx"
      echo "----------------------------------------"
    done < <(grep -n "Info.plist" "$pbx" || true)

    if [ "$matches_found" -eq 0 ]; then
      echo "  (no Info.plist strings found)"
    fi

    echo
  fi
done
echo

# 2b) INFOPLIST_FILE build setting occurrences (explicit Build Settings)
echo "2b) INFOPLIST_FILE build setting occurrences (with line numbers & context):"
for proj in $(find . -name "*.xcodeproj"); do
  pbx="$proj/project.pbxproj"
  if [ -f "$pbx" ]; then
    echo "---- $proj ----"
    # show lines with INFOPLIST_FILE and print 5 lines of surrounding context per match
    ib_matches_found=0
    while IFS= read -r m; do
      ib_matches_found=1
      ln=${m%%:*}
      echo "== around line $ln =="
      start=$(( ln > 5 ? ln - 5 : 1 ))
      end=$(( ln + 5 ))
      sed -n "${start},${end}p" "$pbx"
      echo "----------------------------------------"
    done < <(grep -n "INFOPLIST_FILE" "$pbx" || true)

    if [ "$ib_matches_found" -eq 0 ]; then
      echo "  (no INFOPLIST_FILE entries found)"
    fi

    echo
  fi
done
echo

# 3) Count occurrences of file paths in project.pbxproj (helpful to spot duplicated PBXFileReference)
echo "3) Files mentioned multiple times inside project.pbxproj (basename -> count):"
for pbx in $(find . -name "project.pbxproj"); do
  echo "---- $pbx ----"
  # extract path = "..." lines and count basenames
  grep -o 'path = [^;]*;' "$pbx" | sed 's/path = //' | sed 's/;//' | sed 's/"//g' | awk -F/ '{print $NF}' | sort | uniq -c | sort -nr | awk '$1>1 {print $0}'
  echo
done
echo

# 4) New: detect Info.plist inside PBXResourcesBuildPhase sections
echo "4) Check PBXResourcesBuildPhase sections for any Info.plist entries (these cause copy-into-bundle duplication):"
for pbx in $(find . -name "project.pbxproj"); do
  echo "---- $pbx ----"
  # print the PBXResourcesBuildPhase section(s)
  awk '/\/\* Begin PBXResourcesBuildPhase section \*\//, /\/\* End PBXResourcesBuildPhase section \*\//' "$pbx" > /tmp/_pbx_resources_section.$$ || true
  if grep -q "Info.plist" /tmp/_pbx_resources_section.$$; then
    echo "Found Info.plist referenced inside PBXResourcesBuildPhase:"
    # show lines with Info.plist and surrounding context inside that section
    grep -n "Info.plist" -n /tmp/_pbx_resources_section.$$ || true
    echo "Full PBXResourcesBuildPhase section (for inspection):"
    sed -n '1,400p' /tmp/_pbx_resources_section.$$
    echo "----------------------------------------"
    echo "Hint: open Xcode -> Target -> Build Phases -> Copy Bundle Resources -> remove Info.plist entry."
  else
    echo "No Info.plist entries inside PBXResourcesBuildPhase."
  fi
  rm -f /tmp/_pbx_resources_section.$$ || true
  echo
done
echo

# 5) Helpful hints
cat <<'EOF'
Hints:
- If you see Info.plist referenced multiple times in a single project.pbxproj, open Xcode:
  - Select target -> Build Settings -> "Info.plist File" and ensure each target points to its own plist.
  - Select target -> Build Phases -> "Copy Bundle Resources" and remove Info.plist if present.
- If you see duplicate basenames (same filename in multiple folders), choose the correct one in Xcode's Project navigator and remove the other file reference(s) (right-click -> Delete -> Remove Reference).
- If the pbxproj shows duplicate PBXFileReference / PBXBuildFile entries for the same path, prefer removing the extra reference(s) via the Xcode GUI rather than editing the pbxproj manually unless comfortable.

After fixing references, do:
  - Product -> Clean Build Folder
  - rm -rf ~/Library/Developer/Xcode/DerivedData/*
  - Rebuild

EOF

exit 0
