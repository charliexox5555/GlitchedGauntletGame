#!/bin/sh
# run.sh <script.py> [K=V ...]: prepend Python assignments (values are Python literals) and send to Blender.
S="$1"; shift
T="${SCRATCH_DIR:-/c/Users/charl/AppData/Local/Temp/claude/6f8bed3fe7c45255/6fc92333-7f52-4d25-b886-dff8b47c2843/scratchpad}/_run_$$.py"
: > "$T"
for kv in "$@"; do printf '%s\n' "$kv" >> "$T"; done
cat "$S" >> "$T"
"$(dirname "$0")/s.sh" "$T"; r=$?; rm -f "$T"; exit $r
