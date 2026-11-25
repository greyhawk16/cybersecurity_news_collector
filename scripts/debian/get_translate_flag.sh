#!/usr/bin/env bash
# Print "True" if TRANSLATE_ALL_TO_ENG in .env is true (case-insensitive), otherwise "False".
# Missing .env or missing key also prints "False". Always exits 0.
cd "$(dirname "$(readlink -f "$0")")/../.." || { echo "False"; exit 0; }
v=$(grep -E '^TRANSLATE_ALL_TO_ENG=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"' \r" | tr '[:upper:]' '[:lower:]')
if [[ "$v" == "true" ]]; then
  echo "True"
else
  echo "False"
fi
exit 0
