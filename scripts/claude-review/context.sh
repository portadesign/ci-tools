#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?}" "${PR:?}" "${DIR:?}"
action=${ACTION:-}
profile=${PROFILE:-}
raw=${RAW:-https://raw.githubusercontent.com/portadesign/ci-tools/main}
skipped='def skipped: test("(^|/)(composer\\.lock|symfony\\.lock|package-lock\\.json|yarn\\.lock|pnpm-lock\\.yaml)$|^var/classes/|^public/(build|bundles)/|\\.min\\.(js|css)$|\\.map$|(^|/)[Ff]ixtures?/.*\\.(json|xml|csv|html?|txt|sql|ya?ml|pdf)$");'

mkdir -p "$DIR"
cd "$DIR"

gh api "repos/$GITHUB_REPOSITORY/pulls/$PR" > pr.json
head=$(jq -r .head.sha pr.json)
jq -r '"# \(.title)\n\n\(.body // "")"' pr.json > pr.md
gh api "repos/$GITHUB_REPOSITORY/pulls/$PR/files" --paginate | jq -s add > files.json

gh api graphql -f owner="${GITHUB_REPOSITORY%/*}" -f repo="${GITHUB_REPOSITORY#*/}" -F pr="$PR" -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            isOutdated
            path
            line
            originalLine
            comments(first: 30) { nodes { databaseId author { login } body url } }
          }
        }
        reviews(last: 100) { nodes { id isMinimized author { login } body } }
        comments(last: 50) { nodes { id isMinimized author { login } body } }
      }
    }
  }' > gql.json

marker=$(jq -r '[.data.repository.pullRequest.reviews.nodes[]
  | select(.author.login == "github-actions")
  | .body | capture("<!-- claude-review sha=(?<sha>[0-9a-f]{40}) done=(?<done>[0-9,]*) -->")]
  | last // {sha: "", done: ""} | "\(.sha) \(.done)"' gql.json)
base=${marker% *}
echo "${marker#* }" > done.txt

jq --arg done "$(cat done.txt)" '
  ($done | split(",") | map(select(. != "") | tonumber)) as $done
  | [.data.repository.pullRequest.reviewThreads.nodes[] | .comments.nodes[0] as $first | {
      id: $first.databaseId,
      url: $first.url,
      path,
      line: (.line // .originalLine),
      outdated: .isOutdated,
      earlier_finding: ($first.author.login == "github-actions" and (($first.body // "") | test("^(❌|⚠️)"))),
      closed: (.isResolved or ($first.databaseId as $id | $done | index($id) != null)),
      comments: [.comments.nodes[] | {author: .author.login, body}]
    }]' gql.json > threads.json

jq -r '.data.repository.pullRequest | (.reviews.nodes[], .comments.nodes[])
  | select(.author.login == "github-actions" and (.isMinimized | not))
  | select(.body | test("^(✅ Merge|❌ Fix first|\\*\\*Claude )"))
  | .id' gql.json > hide.txt

scope=full
if [ "$action" = synchronize ] && [ -n "$base" ]; then
    if [ "$base" = "$head" ]; then
        echo '{"files": []}' > compare.json
        scope=delta
    elif gh api "repos/$GITHUB_REPOSITORY/compare/$base...$head" > compare.json 2> /dev/null &&
        [ "$(jq -r .status compare.json)" = ahead ] &&
        [ "$(jq '.files | length' compare.json)" -lt 300 ]; then
        scope=delta
    fi
fi

if [ "$scope" = delta ]; then
    jq --slurpfile pr files.json '($pr[0] | map(.filename)) as $names
      | [.files[] | select(.filename as $name | $names | index($name) != null)]' compare.json > source.json
else
    cp files.json source.json
fi

jq -r --slurpfile source source.json "$skipped"'
  ($source[0] | map(.filename)) as $names
  | .[] | [.status, "+\(.additions)", "-\(.deletions)", .filename,
      (if (.filename | skipped) then "generated or fixture data, not for review"
       elif (.filename as $name | $names | index($name) == null) then "unchanged since the last review"
       else "" end)]
  | @tsv' files.json > files.txt

jq -r "$skipped"'
  .[] | select(.filename | skipped | not)
  | "diff --git a/\(.previous_filename // .filename) b/\(.filename)\n"
    + (.patch // (if .status == "renamed" then "(renamed, content unchanged)" else "(no patch: binary or too large)" end))' source.json > pr.diff
jq -r "$skipped"'.[] | select(.filename | skipped | not) | .filename' source.json > review-files.txt
total=$(grep -c . review-files.txt || true)
parts=$(awk -v max=40000 '
  {
      line = $0
      if (/^diff --git /) {
          hunk = 0
          if (part == 0 || size > max) { part++; size = 0; file = sprintf("diff-%02d.txt", part) }
      } else if (/^@@ /) {
          hunk = 1
          match($0, /\+[0-9]+/)
          number = substr($0, RSTART + 1, RLENGTH - 1) + 0
      } else if (hunk) {
          sign = substr($0, 1, 1)
          if (sign == "-" || sign == "\\") line = sprintf("%5s %s", "", $0)
          else line = sprintf("%5d %s", number++, $0)
      }
      print line > file
      size += length(line) + 1
  }
  END { printf "%02d", part }' pr.diff)

jq 'map({key: .filename, value: [(.patch // "") | split("\n")[] | select(startswith("@@ "))
      | capture("^@@ -[0-9]+(,[0-9]+)? \\+(?<start>[0-9]+)(,(?<count>[0-9]+))? @@")
      | (.start | tonumber) as $start | ((.count // "1") | tonumber) as $count
      | select($count > 0) | [$start, $start + $count - 1]]}) | from_entries' files.json > hunks.json

: > rules.md
if [ -n "$profile" ]; then
    case "$profile" in *[!a-z0-9-]*) echo "Invalid profile: $profile" >&2; exit 1 ;; esac
    case "$profile" in pimcore) names='symfony pimcore' ;; *) names=$profile ;; esac
    for name in $names; do
        curl -fsSL "$raw/profiles/$name.md" >> rules.md
    done
fi

rm -f pr.json files.json gql.json source.json compare.json pr.diff

echo "scope=$scope base=${base:-none} head=$head files for review=$total in $parts parts"
{
    echo "dir=$DIR"
    echo "head=$head"
    echo "scope=$scope"
    echo "total=$total"
    echo "parts=$parts"
    echo 'rules<<CI_TOOLS_RULES'
    cat rules.md
    echo 'CI_TOOLS_RULES'
} >> "${GITHUB_OUTPUT:-/dev/null}"
