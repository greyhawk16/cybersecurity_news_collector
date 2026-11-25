---
description: 전날 보안 뉴스를 수집·요약해 이메일로 발송
---

너는 **조정자**다. CLAUDE.md의 규칙을 지키며 아래 단계를 순서대로 수행하라. 사용자에게 질문하지 마라.
수집·요약·검사는 직접 하지 말고 서브에이전트(collector, summarizer, qa)에게 맡긴다. 너는 작업 배분, QA 결과 중계, 메일 발송만 한다.
기사 본문이나 articles.json 내용을 직접 읽지 않는다. 서브에이전트에게는 TARGET 날짜, 파일 경로, 그 에이전트 담당 issues만 전달한다.

1~3단계는 반드시 단독으로 순서대로 실행하고, 2단계 결과를 확인하기 전에는 3단계 이후의 어떤 도구도 호출하지 마라(병렬 실행 금지).
Bash 명령은 아래에 적힌 문자열 그대로 실행하라(앞에 `bash`, `cd`, 절대경로 등을 붙이지 말 것 — 권한 규칙과 정확히 일치해야 한다).

**최종 출력 규칙**: 너의 최종 출력(stdout)은 그대로 `logs/YYYY-MM-DD.log`에 기록된다. 글자 깨짐을 막기 위해 **영어 ASCII 문자만** 쓰고, 한글·이모지·마크다운·설명 문장 없이 2단계 또는 10단계에 정해진 형식의 **한 줄만** 출력한다. (메일·리포트 본문의 언어 규칙은 그대로다.)

1. **OS·날짜 확정**: 먼저 `uname -s`를 실행한다. 결과가 `Darwin`이면 OS_DIR=`macos`, `Linux`이면 OS_DIR=`debian`이다.
   그다음 어제 날짜(TARGET)를 구한다 — macos: `TZ=Asia/Seoul date -v-1d +%F`, debian: `TZ=Asia/Seoul date -d yesterday +%F`.
2. **중복 확인**: `reports/TARGET.md`가 있고 첫 줄이 `status: sent`이면 `SKIP target=YYYY-MM-DD reason=already_sent` 한 줄만 출력하고 종료한다. 이 경우 3단계 이후는 실행하지 않는다.
3. **수신 주소**: macos면 `scripts/macos/get_recipient.sh`, debian이면 `scripts/debian/get_recipient.sh`를 실행해 출력값을 RECIPIENT로 쓴다. `.env`를 직접 열지 않는다. 실패하면 4~7단계는 그대로 진행하되 8단계에서 발송하지 않고 `status: send_failed`로 기록한다.
4. **수집**: Agent 도구로 `collector`를 호출한다. 프롬프트: "TARGET=YYYY-MM-DD. 수집해 work/TARGET/articles.json에 저장하라."
5. **요약**: `summarizer`를 호출한다. 프롬프트: "TARGET=YYYY-MM-DD. work/TARGET/articles.json으로 리포트·메일 HTML·메타를 만들어라."
6. **QA**: `qa`를 호출한다. 프롬프트: "TARGET=YYYY-MM-DD. 결과물을 검사하라." 반환된 JSON을 그대로 `work/TARGET/qa-round{R}.json`에 Write로 저장한다(R=1부터).
7. **문제 중계** (`pass: false`일 때, 최대 2회 왕복):
   - issues 중 owner가 collector/summarizer가 아니거나 필드가 빠진 항목은 버리고 기록해 둔다(나중에 메모로).
   - item·problem을 보고 owner가 명백히 틀렸으면(예: 날짜 문제가 summarizer로 지정됨) 바로잡는다. 그 외에는 QA 판단을 따른다.
   - issues를 owner별로 나눠 **해당 에이전트에게만** 재요청한다. issue 내용은 바꿔 쓰지 말고 JSON 그대로 붙인다:
     "TARGET=YYYY-MM-DD. 아래 QA issues만 고쳐라: <해당 owner의 issues JSON>"
   - collector를 다시 호출했다면 summarizer도 이어서 호출해 바뀐 articles.json을 반영하게 한다("articles.json이 갱신됐다. 리포트·메일·메타를 다시 맞춰라").
   - 그다음 qa를 다시 호출하고(R+1) 결과를 저장한다. owner가 없는 에이전트는 호출하지 않는다.
   - 2회 왕복 후에도 `pass: false`이면 summarizer에게 마지막으로 한 번: "TARGET=YYYY-MM-DD. 아래 issues에 걸린 기사는 제외하고, 기사 외 문제는 메모에 기록하라: <남은 issues JSON>". 이후 QA 없이 8단계로 간다.
   - 버린 issue가 있으면 이 마지막 요청(또는 별도 요청)에 함께 넘겨 메모에 기록하게 한다.
8. **메일 발송**: `work/TARGET/meta.json`과 `work/TARGET/email.html`을 Read한다. `mcp__claude_ai_Gmail__send_message`로 RECIPIENT에게 보낸다(제목=meta.subject, 본문=email.html 전체, HTML 형식).
9. **완료 표시**: 발송 성공 시 `reports/TARGET.md` 첫 줄을 `status: sent`로 Edit한다. 실패 시 `status: send_failed`로 바꾸고 리포트 메모에 오류 내용을 남긴다.
10. 마지막에 아래 형식의 한 줄만 출력한다(영어 ASCII만):
    `RESULT target=YYYY-MM-DD articles=N sent=yes|no failed_sites=none|<domain>,<domain> qa_rounds=R qa_pass=true|false`
    - `failed_sites`: 수집 실패 사이트를 `config/sources.yaml`의 `url` 도메인(예: `boannews.com`)으로 쉼표 구분. 없으면 `none`. (사이트명은 한글일 수 있으므로 쓰지 않는다.)
    - 발송 실패 시 `sent=no` 뒤에 ` error=<짧은 영어 사유, 공백은 _로>`를 덧붙인다(예: `error=recipient_not_found`).
    - 7단계에서 QA 없이 8단계로 갔다면 `qa_pass=false`로 쓴다.
