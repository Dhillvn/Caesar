#!/usr/bin/env bash
# PROTOTYPE — throwaway. Answers Dhillvn/caesar#10: "what does Raj read to see where things stand?"
#
# Run:  bash prototype-status-view.sh [map-number ...]     (default: 1)
#
# ponytail: map numbers come in as args. Discovery-by-label is already settled in #9
# (`gh search issues --owner Dhillvn --label wayfinder:map --label caesar:driving`);
# a prototype should only exercise what is still open.
set -euo pipefail

OWNER=Dhillvn
NAME=caesar
CAP=4   # max spawned agents across all maps, per #9

MAPS=("${@:-1}")

# Every open ticket carries six facts: number, title, wayfinder type,
# who acts (You = HITL / Caesar = AFK), state (Blocked -> Queued -> Ongoing),
# and blockers when blocked.
fetch() {
  gh api graphql -f owner="$OWNER" -f name="$NAME" -F num="$1" -f query='
    query($owner:String!,$name:String!,$num:Int!){
      repository(owner:$owner,name:$name){
        issue(number:$num){
          number title
          subIssues(first:100){nodes{
            number title state closedAt
            assignees(first:1){nodes{login}}
            labels(first:10){nodes{name}}
            blockedBy(first:20){nodes{number state}}
          }}
        }
      }
    }' --jq '
      # Wayfinder: research is AFK, prototype/grilling are HITL, task defaults to AFK
      # ("the agent drives it alone where it can") until Caesar stamps `caesar:hitl`.
      def is_afk: (.labels.nodes | map(.name)) as $l
        | ($l | any(. == "wayfinder:research"))
          or (($l | any(. == "wayfinder:task")) and ($l | any(. == "caesar:hitl") | not));
      def kind: (.labels.nodes | map(.name) | map(select(startswith("wayfinder:")))
                 | first // "wayfinder:?") | sub("wayfinder:"; "");

      .data.repository.issue as $m
      | ($m.subIssues.nodes // []) as $all
      | {
          number: $m.number,
          title:  $m.title,
          done:   ($all | map(select(.state=="CLOSED")) | sort_by(.closedAt) | map({number,title})),
          open:   ($all | map(select(.state=="OPEN"))
                   | map((.blockedBy.nodes | map(select(.state=="OPEN")) | map(.number)) as $blk
                     | {
                         number, title,
                         type:  kind,
                         who:   (if is_afk then "Caesar" else "You" end),
                         state: (if ($blk|length) > 0 then "Blocked"
                                 elif (.assignees.nodes|length) > 0 then "Ongoing"
                                 else "Queued" end),
                         blk:   $blk
                       })
                   # what needs you, then what is moving, then what is next, then what is stuck
                   | sort_by( if   .state=="Queued"  and .who=="You"    then 0
                              elif .state=="Ongoing" and .who=="You"    then 1
                              elif .state=="Ongoing" and .who=="Caesar" then 2
                              elif .state=="Queued"  and .who=="Caesar" then 3
                              else 4 end ))
        }'
}

table() {
  jq -r '
    def cell(s; n): (s|tostring) as $t
      | (if ($t|length) > n then ($t[0:n-1] + "…") else $t end)
      | . + ("                                                            "[0:(n - ([$t|length, n]|min))]);
    # greedy word wrap; a single word longer than the cell still gets truncated by cell()
    def wrap($n): [splits(" +")] | reduce .[] as $w ([];
        if (.|length) == 0 then [$w]
        elif ((.[-1] + " " + $w) | length) <= $n then (.[0:-1] + [.[-1] + " " + $w])
        else . + [$w] end);
    def bar(l; m; r): l + ("─" * 6) + m + ("─" * 8) + m + ("─" * 52) + m + ("─" * 15) + m + ("─" * 11) + r;
    def row(num; who; ticket; state; type): "│ " + cell(num;4) + " │ " + cell(who;6) + " │ " + cell(ticket;50)
                      + " │ " + cell(state;13) + " │ " + cell(type;9) + " │";

    [ "MAP #\(.number)  \(.title)",
      "\(.done|length) decided · \(.open|length) open" + (if (.done|length) > 0 then " · last was #\(.done[-1].number) \(.done[-1].title)" else "" end),
      "",
      bar("┌";"┬";"┐"),
      row("#"; "Who"; "Ticket"; "State"; "Type"),
      bar("├";"┼";"┤") ]
    + (if (.open|length) == 0
       then [ row(""; ""; "nothing open — map is done"; ""; "") ]
       else (.open | map(
              (.title | wrap(50)) as $lines
              | [ row("#\(.number)"; .who; $lines[0];
                      .state + (if (.blk|length) > 0
                                then " " + (.blk | map("#"+(.|tostring)) | join(","))
                                else "" end);
                      .type) ]
                + ($lines[1:] | map(row(""; ""; "  " + .; ""; "")))
            ) | add)
       end)
    + [ bar("└";"┴";"┘") ]
    | .[]'
}

echo "CAESAR — $(date '+%Y-%m-%d %H:%M')"

slots=0
for n in "${MAPS[@]}"; do
  echo
  data=$(fetch "$n")
  echo "$data" | table
  slots=$(( slots + $(echo "$data" | jq '[.open[] | select(.who=="Caesar" and .state=="Ongoing")] | length') ))
done

echo
echo "Agent slots: $slots of $CAP in use"
prs=$(gh pr list --repo "$OWNER/$NAME" --state open --json number,title,isDraft \
        --jq '.[] | "  PR #\(.number)  \(.title)" + (if .isDraft then "  (draft)" else "" end)')
echo "Waiting on your word:"
echo "${prs:-  nothing — no open PRs}"
