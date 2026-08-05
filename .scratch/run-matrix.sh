#!/usr/bin/env bash
# Runs one matrix cell. Usage: run-matrix.sh <task> <model> <effort>
set -u
BASE="C:/Users/rajdh/Projects/caesar/.claude/worktrees/ticket-64-1852/.scratch"
TASK="$1"; MODEL="$2"; EFFORT="$3"; SUFFIX="${4:-}"
CELL="$TASK-$MODEL-$EFFORT$SUFFIX"
DIR="$BASE/runs/$CELL"

rm -rf "$DIR"; mkdir -p "$DIR"
cp "$BASE/fixtures/$TASK/"* "$DIR/"
mv "$DIR/PROMPT.txt" "$DIR/.prompt.txt"

START=$(date +%s)
( cd "$DIR" && claude -p --output-format json \
    --model "$MODEL" --effort "$EFFORT" \
    --permission-mode bypassPermissions \
    --max-budget-usd 1.00 \
    < .prompt.txt > result.json 2> stderr.txt )
RC=$?
END=$(date +%s)
echo "$CELL rc=$RC wall=$((END-START))s"
