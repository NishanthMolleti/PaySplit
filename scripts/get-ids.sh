#!/usr/bin/env bash
# Fetch your Splitwise user ID, groups and friends, and print a ready-to-copy
# Targets dictionary for the "Split Payment" shortcut.
#
# Usage:
#   ./scripts/get-ids.sh                 # prompts for the key (hidden)
#   SPLITWISE_API_KEY=... ./scripts/get-ids.sh
set -euo pipefail

API="https://secure.splitwise.com/api/v3.0"

command -v jq >/dev/null || { echo "jq is required (brew install jq)"; exit 1; }

KEY="${SPLITWISE_API_KEY:-}"
if [[ -z "$KEY" ]]; then
  read -rsp "Paste Splitwise API key: " KEY; echo
fi

call() {
  local out
  out=$(curl -sf -H "Authorization: Bearer $KEY" "$API/$1") || {
    echo "Request to $1 failed — check your API key." >&2; exit 1; }
  echo "$out"
}

me=$(call get_current_user)
groups=$(call get_groups)
friends=$(call get_friends)

echo
echo "== You =="
echo "$me" | jq -r '.user | "\(.first_name) \(.last_name // "")  id=\(.id)"'

echo
echo "== Groups =="
echo "$groups" | jq -r '.groups[] | select(.id != 0) | "\(.name)  id=\(.id)"'

echo
echo "== Friends =="
echo "$friends" | jq -r '.friends[] | "\(.first_name) \(.last_name // "")  id=\(.id)"'

echo
echo "== Targets dictionary (paste into the shortcut) =="
jq -n --argjson g "$groups" --argjson f "$friends" '
  ( [ $g.groups[] | select(.id != 0) | { key: ("🏠 " + .name), value: { type: "group",  id: .id } } ]
  + [ $f.friends[] | { key: ("👤 " + .first_name), value: { type: "friend", id: .id } } ] )
  | from_entries'

echo
echo "YOUR_ID = $(echo "$me" | jq -r '.user.id')"
