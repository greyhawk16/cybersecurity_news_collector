#!/bin/zsh
# .env에서 RECIPIENT_EMAIL_ADDRESS 값만 출력한다 (따옴표·공백 제거).
cd "$(dirname "$0")/.." || exit 1
v=$(grep -E '^RECIPIENT_EMAIL_ADDRESS=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"' \r")
if [[ -z "$v" ]]; then
  echo "ERROR: RECIPIENT_EMAIL_ADDRESS not found in .env" >&2
  exit 1
fi
echo "$v"
