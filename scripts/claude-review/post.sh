#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?}" "${PR:?}" "${DIR:?}" "${HEAD:?}" "${SCOPE:?}" "${TOTAL:?}"
result=${RESULT:-}
if [ -z "$result" ]; then
    [ "$TOTAL" = 0 ] || { echo 'No review result' >&2; exit 1; }
    result='{"findings": [], "more_warnings": 0, "resolved": [], "not_read": []}'
fi

cd "$DIR"
printf '%s' "$result" > result.json

jq -n --slurpfile result result.json --slurpfile threads threads.json --slurpfile hunks hunks.json \
    --rawfile files review-files.txt \
    --arg head "$HEAD" --arg scope "$SCOPE" --argjson total "$TOTAL" --arg done "$(cat done.txt)" '
  def pad: tostring | if length < 2 then "0" + . else . end;
  def icon: if .blocking then "❌" else "⚠️" end;
  def fence: if contains("```") then "````" else "```" end;
  def place($hunks):
    . as $finding
    | ($hunks[.path] // []) as $ranges
    | ($ranges | map(select(.[0] <= $finding.line and $finding.line <= .[1])) | .[0]) as $hunk
    | if $hunk then
        if .start_line == null or .start_line == .line then del(.start_line)
        elif .start_line < .line and .start_line >= $hunk[0] then .
        else del(.start_line, .suggestion) end
      elif ($ranges | length) > 0 then
        del(.start_line, .suggestion)
        | .line = ($ranges | map([.[0], ([.[1], $finding.line] | min)] | max) | min_by(. - $finding.line | fabs))
        | .body = "Placed on the nearest changed line of the file. " + .body
      else .unplaced = true end;
  $result[0] as $r
  | ($done | split(",") | map(select(. != "") | tonumber)) as $done
  | ($threads[0] | map(select(.earlier_finding and (.closed | not)))) as $open
  | ($open | map(select(.url as $url | $r.resolved | index($url) != null))) as $resolved
  | ($open | map(select(.url as $url | $r.resolved | index($url) == null))) as $still
  | ($files | split("\n")) as $files
  | ($r.not_read | map(select(split(": ")[0] as $path | $files | index($path) != null))) as $unread
  | ($r.findings | map(select(.path != "" and .line > 0) | place($hunks[0]))) as $findings
  | ($findings | map(select(.blocking))) as $blocking
  | ($findings | map(select(.blocking | not))) as $warnings
  | ($blocking + $warnings[0:5]) as $shown
  | ($r.more_warnings + ([($warnings | length) - 5, 0] | max)) as $more
  | (($blocking | length) > 0 or ($still | any(.comments[0].body | startswith("❌")))) as $fail
  | ([if $fail then "❌ Fix first" else "✅ Merge" end]
      + (if ($shown | length) > 0
         then [""] + ($shown | to_entries | map("\(.key + 1 | pad). \(.value | icon) \(.value.path):\(.value.line): \(.value.title)"
           + (if .value.unplaced then " \(.value.body)" else "" end)))
         else [] end)
      + (if $more > 0 then ["\($more) more ⚠️ not listed."] else [] end)
      + (if ($still | length) > 0
         then ["", "Still open:"] + ($still | map("- \(.comments[0].body | split("\n")[0] | .[0:140]) \(.url)"))
         else [] end)
      + (if ($resolved | length) > 0 then ["", "Resolved since last review: \($resolved | length)"] else [] end)
      + ["", (if $total == 0 then "Nothing to review: only generated files, lock files or fixture data changed."
              else "Read \($total - ($unread | length))/\($total) files"
                + (if $scope == "delta" then " changed since the last review" else "" end)
                + (if ($unread | length) > 0 then "; not read: \($unread | join("; "))" else "" end) end)]
      + ["", "<!-- claude-review sha=\($head) done=\($done + ($resolved | map(.id)) | unique | map(tostring) | join(",")) -->"]
      | join("\n")) as $body
  | {
      review: {
        commit_id: $head,
        event: "COMMENT",
        body: $body,
        comments: ($shown | map(select(.unplaced | not)
          | {path, line, side: "RIGHT",
           body: ("\(icon) \(.body)"
             + (if (.suggestion // "") != "" then "\n\n\(.suggestion | fence)suggestion\n\(.suggestion)\n\(.suggestion | fence)" else "" end))}
          + (if .start_line then {start_line, start_side: "RIGHT"} else {} end)))
      },
      fallback: {
        commit_id: $head,
        event: "COMMENT",
        body: ($body + (if ($shown | length) > 0
          then "\n\nThe findings could not be placed on their lines:\n"
            + ($shown | to_entries | map("\(.key + 1 | pad). \(.value | icon) \(.value.path):\(.value.line): \(.value.body)") | join("\n"))
          else "" end))
      }
    }' > payload.json
jq .review payload.json > review.json
jq .fallback payload.json > fallback.json

if [ -n "${DRY_RUN:-}" ]; then
    cat review.json
    exit 0
fi

gh api "repos/$GITHUB_REPOSITORY/pulls/$PR/reviews" --input review.json > /dev/null || {
    echo 'Inline comments rejected, posting the summary alone'
    gh api "repos/$GITHUB_REPOSITORY/pulls/$PR/reviews" --input fallback.json > /dev/null
}

while read -r id; do
    gh api graphql -f id="$id" -f query='
      mutation($id: ID!) {
        minimizeComment(input: {subjectId: $id, classifier: OUTDATED}) { clientMutationId }
      }' > /dev/null || echo "Could not hide $id"
done < hide.txt
