#!/usr/bin/env bash
B="C:/Users/rajdh/Projects/caesar/.claude/worktrees/ticket-64-1852/.scratch/run-matrix.sh"
bash "$B" taskB sonnet low -rep2
bash "$B" taskB sonnet low -rep3
bash "$B" taskB sonnet low -rep4
bash "$B" taskA sonnet low -rep3
bash "$B" taskA sonnet low -rep4
bash "$B" taskA opus low -rep2
bash "$B" taskA opus low -rep3
bash "$B" taskA opus low -rep4
bash "$B" taskB opus low -rep2
bash "$B" taskB opus low -rep3
bash "$B" taskB opus low -rep4
echo "REPS DONE"
