#!/usr/bin/env bash
# Print only the RECIPIENT_EMAIL_ADDRESS value from .env (quotes and whitespace stripped).
cd "$(dirname "$(readlink -f "$0")")/../.." || exit 1
v=$(grep -E '^RECIPIENT_EMAIL_ADDRESS=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"' \r")
if [[ -z "$v" ]]; then
  echo "ERROR: RECIPIENT_EMAIL_ADDRESS not found in .env" >&2
  exit 1
fi
echo "$v"
