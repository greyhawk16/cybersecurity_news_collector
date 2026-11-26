#!/bin/zsh
# Run by launchd every day at 07:30. Builds and sends the previous day's security news briefing.
set -u

# Project path: two levels above this script's folder (scripts/macos/)
PROJECT_DIR="${0:A:h:h:h}"

# launchd's PATH is nearly empty, so add the usual locations where claude is installed
export PATH="$HOME/.local/bin:$HOME/.claude/local:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude)}"

cd "$PROJECT_DIR" || exit 1
mkdir -p logs
LOG="logs/$(date +%F).log"

if [[ -z "$CLAUDE_BIN" ]]; then
  echo "=== $(LC_ALL=C date "+%F %T %Z") ERROR: claude executable not found (set CLAUDE_BIN to override) ===" >> "$LOG"
  exit 1
fi

echo "=== $(LC_ALL=C date "+%F %T %Z") start (claude=$CLAUDE_BIN) ===" >> "$LOG"
"$CLAUDE_BIN" -p "/daily-brief" --permission-mode default --output-format text < /dev/null >> "$LOG" 2>&1
rc=$?
echo "=== $(LC_ALL=C date "+%F %T %Z") exit=$rc ===" >> "$LOG"
exit $rc
