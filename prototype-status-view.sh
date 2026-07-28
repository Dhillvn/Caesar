#!/usr/bin/env bash
# PROTOTYPE — throwaway. Answers Dhillvn/caesar#10: "what does Raj read to see where things stand?"
# Run: bash prototype-status-view.sh [map-issue-number ...]     (default: 1)
#
# ponytail: map numbers come in as args. Discovery-by-label is already settled in #9
# (`gh search issues --owner Dhillvn --label wayfinder:map --label caesar:driving`);
# a prototype should only exercise what is still open.
set -euo pipefail

OWNER=Dhillvn
NAME=caesar
MAPS=("${@:-1}")

pad() { printf '%-*s' "$2" "$1"; }

echo "CAESAR — $(date '+%Y-%m-%d %H:%M')"

for n in "${MAPS[@]}"; do
  echo
  gh api graphql \
    -f owner="$OWNER" -f name="$NAME" -F num="$n" \
    -f query='
      query($owner:String!,$name:String!,$num:Int!){
        repository(owner:$owner,name:$name){
          issue(number:$num){
            number title
            subIssues(first:100){nodes{
              number title state closedAt
              assignees(first:1){nodes{login}}
              labels(first:10){nodes{name}}
              blockedBy(first:20){nodes{number title state}}
            }}
          }
        }
      }' \
    --jq '
      def w(s;n): (s + "                              ")[0:n];
      def row(tag;t): "  " + w(tag;10) + w("#" + (t.number|tostring);5) + t.title;

      .data.repository.issue as $m
      | ($m.subIssues.nodes // []) as $all
      | ($all | map(select(.state=="CLOSED")) | sort_by(.closedAt)) as $done
      | ($all | map(select(.state=="OPEN"))
              | map(. + {blk: (.blockedBy.nodes | map(select(.state=="OPEN")))})) as $open
      | ($open | map(select(.assignees.nodes|length > 0)))                                        as $running
      | ($open | map(select((.assignees.nodes|length)==0 and (.blk|length)>0)))                   as $blocked
      | ($open | map(select((.assignees.nodes|length)==0 and (.blk|length)==0)))                  as $front
      | ($front | map(select(.labels.nodes|any(.name=="wayfinder:research"))))                    as $afk
      | ($front | map(select(.labels.nodes|any(.name=="wayfinder:research")|not)))                as $hitl
      | [ "MAP #\($m.number) \($m.title)",
          "  \($done|length) decided · \($open|length) open · \($hitl|length) waiting on you"
        ]
        + ($hitl    | map(row("YOU";.)))
        + ($running | map(row("RUNNING";.)))
        + ($afk     | map(row("AFK";.)))
        + ($blocked | map(row("BLOCKED";.) + "  ← " + (.blk | map("#"+(.number|tostring)) | join(" "))))
        + (if ($done|length) > 0
           then ["  last decided: #\($done[-1].number) \($done[-1].title)"]
           else [] end)
      | .[]
    '
done

echo
echo "NEEDS YOUR WORD"
prs=$(gh pr list --repo "$OWNER/$NAME" --state open \
        --json number,title,isDraft \
        --jq '.[] | "  PR #\(.number) \(.title)" + (if .isDraft then "  (draft)" else "" end)')
echo "${prs:-  (no open PRs)}"
