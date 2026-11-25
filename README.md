# 개요

[English](README.en.md)

전날(KST) 게시된 사이버 보안 뉴스를 수집·요약해 매일 아침 이메일로 보내는 Claude Code 에이전트입니다.
macOS에서는 launchd, Debian 리눅스에서는 cronjob을 사용해서 매일 07:30에 `claude -p "/daily-brief"`를 실행합니다.


## 메일 구성

제목: `[Claude 일일 보안 브리핑] YYYY-MM-DD (기사 N건)`

1. **오늘의 트렌드** — 한국어 3~5개 bullet. bullet마다 근거 기사 출처 번호 `[n]`
2. **카테고리별 기사** — 랜섬웨어 / 취약점·CVE / 데이터 유출 / APT·국가배후 / 악성코드·피싱 / 정책·규제 / 기타. 기사마다 원문 언어로 2~3문장 요약 + 출처 번호 `[n]`
3. **수집 실패 내역** — 실패한 사이트와 사유
4. **출처** — 번호순 `[n] 기사제목( URL )` 목록

발송본은 `reports/YYYY-MM-DD.md`에 보관되고, 다음 날 트렌드 비교에 쓰입니다.


## 에이전트 구조

`/daily-brief`는 직접 일하지 않는 **조정자**이며, 역할별 서브에이전트 3개를 호출합니다.

```
/daily-brief (조정자: 날짜 확정 · 중복 확인 · 작업 배분 · 메일 발송)
   │
   ├─▶ collector  (sonnet)  RSS + 본문 수집        → work/DATE/articles.json
   ├─▶ summarizer (sonnet)  요약 · 병합 · 트렌드     → reports/DATE.md, email.html, meta.json
   └─▶ qa         (haiku, 읽기 전용) 규칙 검사      → {pass, issues[{owner, …}]}
            │
            └─ 문제는 담당(owner) 에이전트에게만 그대로 전달 → 재검사 (최대 2회)
               그래도 남으면 해당 기사를 빼고 메모에 기록한 뒤 발송
```

- 에이전트끼리는 파일 경로로만 데이터를 주고받습니다. 조정자는 기사 본문을 읽지 않습니다.
- 메일 발송 권한은 조정자에게만 있습니다. 웹 내용을 읽는 에이전트는 메일을 보낼 수 없습니다.

## 요구 사항

#### 기술 스택
![Static Badge](https://img.shields.io/badge/AI-black?style=for-the-badge)![Claude](https://img.shields.io/badge/claude-%23D97757.svg?style=for-the-badge&logo=claude&logoColor=white)![Claude Code](https://img.shields.io/badge/Claude%20Code-%23D97757.svg?style=for-the-badge&logo=claudecode&logoColor=white)

![Static Badge](https://img.shields.io/badge/OS-black?style=for-the-badge)![Debian](https://img.shields.io/badge/Debian-%23D70A53.svg?style=for-the-badge&logo=debian&logoColor=white)![macOS](https://img.shields.io/badge/mac%20os-%23000000.svg?style=for-the-badge&logo=macos&logoColor=F0F0F0&logoSize=auto)

![Static Badge](https://img.shields.io/badge/Languages-black?style=for-the-badge)![Bash Script](https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)![Python](https://img.shields.io/badge/python-%233670A0.svg?style=for-the-badge&logo=python&logoColor=ffdd54)

#### 별도 필요
- [Claude Code](https://docs.claude.com/en/docs/claude-code) 설치 및 로그인
- claude.ai에서 **Gmail 커넥터** 연결 (`mcp__claude_ai_Gmail__send_message` 사용)


## 설치

#### 공통

```bash
git clone https://github.com/greyhawk16/cybersecurity_news_collector.git
cd cybersecurity_news_collector

# 수신 이메일 설정
cp .env.example .env
# .env를 열어 RECIPIENT_EMAIL_ADDRESS를 내 주소로 수정

# 폴더 신뢰 승인 (최초 1회) — claude를 실행해 신뢰를 승인한 뒤 종료
claude

# 수동으로 한 번 실행해 메일이 오는지 확인 (macOS)
scripts/macos/run_daily.sh

#    Debian 계열 리눅스라면
sudo apt update && sudo apt install fonts-nanum -y
scripts/debian/run_daily.sh
cat logs/$(TZ=Asia/Seoul date +%F).log

# 4. 매일 자동 실행 등록 → AUTOMATION.md 참고
```

#### MacOS

```bash
scripts/macos/run_daily.sh
```

#### Debian Linux

```bash
sudo apt update && sudo apt install fonts-nanum -y
scripts/debian/run_daily.sh
cat logs/$(TZ=Asia/Seoul date +%F).log

# 4. 매일 자동 실행 등록 → AUTOMATION.md 참고
```

> (macOS) 폴더를 `~/Documents`, `~/Desktop`, `~/Downloads` 안에 두면 macOS 보호 정책 때문에 launchd 실행이 막힙니다. 그 밖의 위치에 clone하세요.
>
> (Debian) 실행할 리눅스 장비에서 직접 `claude`를 실행해 claude.ai 계정으로 로그인하고 폴더 신뢰를 승인해야 합니다. Gmail 커넥터가 claude.ai 계정에 연결되어 있어야 메일이 발송됩니다.

자동 실행 켜기·끄기, 문제 해결은 [AUTOMATION.md](AUTOMATION.md)를 보세요.


## 수집 사이트 추가

`config/sources.yaml`에 항목만 추가하면 됩니다.

```yaml
  - name: 사이트명
    url: https://example.com/
    language: en            # 요약 언어 (원문 언어 유지)
    feed: https://example.com/rss
    feed_timezone: "+09:00" # pubDate에 시간대가 없을 때만
    fetch_article: true     # 본문 WebFetch 가능 여부. false면 RSS description만 사용
    notes: >
      제외 기준 등 사이트별 메모
```

## 디렉터리

| 경로 | 내용 |
|---|---|
| `CLAUDE.md` | 에이전트 공통 규칙 |
| `.claude/commands/daily-brief.md` | 조정자 절차 |
| `.claude/agents/` | 서브에이전트 정의 (`collector.md`, `summarizer.md`, `qa.md`) |
| `.claude/settings.json` | headless 실행용 도구 권한 (허용·거부 목록) |
| `config/sources.yaml` | 수집 대상 사이트 |
| `scripts/macos/run_daily.sh` | macOS: launchd가 실행하는 진입점 |
| `scripts/debian/run_daily.sh` | Debian 계열: cron이 실행하는 진입점 |
| `scripts/fetch_feeds.py` | (OS 공통) RSS에서 대상 날짜(KST) 기사만 JSON으로 출력 |
| `scripts/macos/get_recipient.sh`, `scripts/debian/get_recipient.sh` | `.env`에서 수신 주소만 출력 |
| `templates/email.html` | 메일 HTML 템플릿 |
| `launchd/` | launchd plist 템플릿 |
| `reports/`, `logs/`, `work/` | 실행 결과물 (git에서 제외) |

## 참고

- 매일 실행할 때마다 Claude 사용량이 발생합니다.
- The Hacker News는 기사 본문이 Cloudflare로 차단되어 RSS description만으로 요약합니다.
- 에이전트는 `.env`를 직접 읽지 못합니다(`settings.json` deny). 수신 주소는 `scripts/<os>/get_recipient.sh` 출력으로만 받습니다.
- Gmail 도구는 `send_message`만 허용하고, 삭제·전달 등은 거부합니다.
- 웹 페이지와 RSS 내용은 데이터로만 다루며, 그 안의 지시문은 따르지 않도록 모든 에이전트에 명시되어 있습니다.
- 같은 날짜 리포트의 첫 줄이 `status: sent`이면 다시 보내지 않습니다.

## 라이선스

[MIT](LICENSE)

