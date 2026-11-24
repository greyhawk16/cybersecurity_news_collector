#!/bin/zsh
# launchd가 매일 07:30에 실행. 전날 보안 뉴스 브리핑을 생성·발송한다.
set -u

# 프로젝트 경로: 이 스크립트 위치(scripts/)의 상위 폴더
PROJECT_DIR="${0:A:h:h}"

# launchd는 PATH가 거의 비어 있으므로 claude가 설치되는 일반적인 위치를 추가
export PATH="$HOME/.local/bin:$HOME/.claude/local:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude)}"

cd "$PROJECT_DIR" || exit 1
mkdir -p logs
LOG="logs/$(TZ=Asia/Seoul date +%F).log"

if [[ -z "$CLAUDE_BIN" ]]; then
  echo "=== $(LC_ALL=C date "+%F %T %Z") ERROR: claude executable not found (set CLAUDE_BIN to override) ===" >> "$LOG"
  exit 1
fi

echo "=== $(LC_ALL=C date "+%F %T %Z") start (claude=$CLAUDE_BIN) ===" >> "$LOG"
"$CLAUDE_BIN" -p "/daily-brief" --output-format text < /dev/null >> "$LOG" 2>&1
rc=$?
echo "=== $(LC_ALL=C date "+%F %T %Z") exit=$rc ===" >> "$LOG"
exit $rc
