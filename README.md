## 개요

[English](README.en.md)

전날(기기 시간대 기준) 게시된 사이버 보안 뉴스를 수집·요약해 매일 아침 이메일로 보내는 Claude Code 에이전트입니다.
macOS에서는 launchd, Debian 리눅스에서는 cronjob을 사용해서 매일 07:30에 `claude -p "/daily-brief"`를 실행합니다.


## 메일 구성

제목: `[Claude 일일 보안 브리핑] YYYY-MM-DD (기사 N건)`

(`TRANSLATE_ALL_TO_ENG=True`이면 `[Claude Daily Security Briefing] YYYY-MM-DD (N articles)`, 본문 전체 영어)

1. **오늘의 트렌드** — 한국어 3~5개 bullet. bullet마다 근거 기사 출처 번호 `[n]`
2. **카테고리별 기사** — 랜섬웨어 / 취약점·CVE / 데이터 유출 / APT·국가배후 / 악성코드·피싱 / 정책·규제 / 기타. 기사마다 원문 언어로 2~3문장 요약 + 출처 번호 `[n]`
3. **수집 실패 내역** — 실패한 사이트와 사유
4. **출처** — 번호순 `[n] 기사제목( URL )` 목록

발송본은 `reports/YYYY-MM-DD.md`에 보관되고, 다음 날 트렌드 비교에 쓰입니다.


## 에이전트

### 1) 구성

`/daily-brief`는 직접 일하지 않는 **조정자**이며, 역할별 서브에이전트 4개를 호출합니다 (translator는 `TRANSLATE_ALL_TO_ENG=True`일 때만).

```
/daily-brief (조정자: 날짜 확정 · 중복 확인 · 작업 배분 · 메일 발송)
   │
   ├─▶ collector  (sonnet)  RSS + 본문 수집        → work/DATE/articles.json
   ├─▶ summarizer (sonnet)  요약 · 병합 · 트렌드     → reports/DATE.md, email.html, meta.json
   └─▶ qa         (haiku, 읽기 전용) 규칙 검사      → {pass, issues[{owner, …}]}
            │
            └─ 문제는 담당(owner) 에이전트에게만 그대로 전달 → 재검사 (최대 2회)
               그래도 남으면 해당 기사를 빼고 메모에 기록한 뒤 발송
   │
   └─▶ translator (sonnet)  메일 영어 번역 (선택)   → email.en.html, meta.en.json
            └─ qa가 번역본 검사(구조·링크·한글 잔존) → 실패 시 translator에게만 재요청 (최대 2회)
               그래도 실패하면 한국어판으로 발송
```

- 에이전트끼리는 파일 경로로만 데이터를 주고받습니다. 조정자는 기사 본문을 읽지 않습니다.
- 메일 발송 권한은 조정자에게만 있습니다. 웹 내용을 읽는 에이전트는 메일을 보낼 수 없습니다.

### 2) 작동 방식

에이전트끼리 직접 대화하지 않고, 조정자가 순서대로 호출하면서 **`work/DATE/` 폴더의 파일**로 데이터를 넘깁니다. 조정자는 각 에이전트에게 날짜·파일 경로·고칠 문제만 전달합니다.

| 순서 | 에이전트 | 읽는 것 | 만드는 것 |
|---|---|---|---|
| 1 | collector | `config/sources.yaml`, RSS·기사 본문 | `articles.json` |
| 2 | summarizer | `articles.json`, 이전 `reports/` | `reports/DATE.md`, `email.html`, `meta.json` |
| 3 | qa | summarizer 결과물 | `qa-roundN.json` (문제 + 담당 owner) |
| 4 | translator (선택) | `email.html`, `meta.json` | `email.en.html`, `meta.en.json` |
| 5 | qa (번역 검사) | 번역본 | `qa-en-roundN.json` |

- **QA 피드백**: 조정자가 qa 결과의 문제를 담당 에이전트(owner)에게만 그대로 전달해 고치게 하고 다시 검사합니다(최대 2회). collector가 고쳤다면 summarizer가 결과물을 다시 맞춥니다.
- **발송**: 마지막에 조정자가 `meta(.en).json`의 제목과 `email(.en).html` 본문을 읽어 Gmail로 보내고, 리포트 첫 줄을 `status: sent`로 바꿉니다.


## 요구 사항

### 1) 기술 스택
![Static Badge](https://img.shields.io/badge/AI-black?style=for-the-badge)![Claude](https://img.shields.io/badge/claude-%23D97757.svg?style=for-the-badge&logo=claude&logoColor=white)![Claude Code](https://img.shields.io/badge/Claude%20Code-%23D97757.svg?style=for-the-badge&logo=claudecode&logoColor=white)

![Static Badge](https://img.shields.io/badge/OS-black?style=for-the-badge)![Debian](https://img.shields.io/badge/Debian-%23D70A53.svg?style=for-the-badge&logo=debian&logoColor=white)![macOS](https://img.shields.io/badge/mac%20os-%23000000.svg?style=for-the-badge&logo=macos&logoColor=F0F0F0&logoSize=auto)

![Static Badge](https://img.shields.io/badge/Languages-black?style=for-the-badge)![Bash Script](https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)![Python](https://img.shields.io/badge/python-%233670A0.svg?style=for-the-badge&logo=python&logoColor=ffdd54)

### 2) 별도 필요
- [Claude Code](https://docs.claude.com/en/docs/claude-code) 설치 및 로그인
- claude.ai에서 [Gmail 커넥터](https://claude.ai/plugins/id/plugin_015pNiaBf85q2h1bpA8p89sM) 연결 (로그인 필요)


## 설치

### 1) 공통

```bash
git clone https://github.com/greyhawk16/cybersecurity_news_collector.git
cd cybersecurity_news_collector

# 수신 이메일 설정
cp .env.example .env
# .env를 열어 RECIPIENT_EMAIL_ADDRESS를 내 주소로 수정
# 메일 전체를 영어로 받으려면 TRANSLATE_ALL_TO_ENG=True (기본 False, 리포트 아카이브는 항상 한국어)

# 폴더 신뢰 승인 (최초 1회) — claude를 실행해 신뢰를 승인한 뒤 종료
claude
```

### 2) 최초 1회 실행

```bash
# MacOS
scripts/macos/run_daily.sh


# Debian
sudo apt update && sudo apt install fonts-nanum -y
scripts/debian/run_daily.sh
cat logs/$(date +%F).log
```


> (macOS) 폴더를 `~/Documents`, `~/Desktop`, `~/Downloads` 안에 두면 macOS 보호 정책 때문에 launchd 실행이 막힙니다. 그 밖의 위치에 clone하세요.
>
> (Debian) 실행할 리눅스 장비에서 직접 `claude`를 실행해 claude.ai 계정으로 로그인하고 폴더 신뢰를 승인해야 합니다. Gmail 커넥터가 claude.ai 계정에 연결되어 있어야 메일이 발송됩니다.

자동 실행 켜기·끄기, 문제 해결은 [AUTOMATION.md](AUTOMATION.md)를 보세요.


## 실행 시각·시간대 변경

실행 시각과 "전날"(기사 수집 기준일, 00:00~23:59)은 모두 **기기의 시스템 시간대**를 따릅니다. 시간대를 바꾸려면 OS 시간대만 바꾸면 되고, 코드를 고칠 필요는 없습니다.

### 1) 시간대 확인·변경

```bash
# macOS
sudo systemsetup -gettimezone
sudo systemsetup -listtimezones          # 사용 가능한 시간대 목록
sudo systemsetup -settimezone Asia/Seoul

# Debian
timedatectl | grep "Time zone"
timedatectl list-timezones               # 사용 가능한 시간대 목록
sudo timedatectl set-timezone Asia/Seoul
sudo systemctl restart cron              # cron이 새 시간대를 반영하도록 재시작
```

### 2) 실행 시각 변경 (기본 07:30)

- **macOS**: `launchd/com.user.securitybrief.plist`의 `Hour`, `Minute` 값을 고친 뒤(`__PROJECT_DIR__`는 그대로 둠) 다시 등록합니다.

  ```bash
  # clone한 폴더에서 실행
  launchctl bootout gui/$(id -u)/com.user.securitybrief
  test -f launchd/com.user.securitybrief.plist \
    && sed "s|__PROJECT_DIR__|$PWD|g" launchd/com.user.securitybrief.plist > ~/Library/LaunchAgents/com.user.securitybrief.plist \
    && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.securitybrief.plist \
    || echo "FAILED: run this from the cloned folder (repository root)"

  # 자동 기상 예약도 새 시각 5분 전으로 (예: 06:00 실행 → 05:55)
  sudo pmset repeat wake MTWRFSU 05:55:00
  ```

- **Debian**: crontab 줄의 앞 두 칸(`분 시`)을 바꿔 다시 등록합니다. 예: 매일 06:00

  ```bash
  ( crontab -l 2>/dev/null | grep -v securitybrief; echo "0 6 * * * $PWD/scripts/debian/run_daily.sh # securitybrief" ) | crontab -
  ```

> 자정 직후에 실행하면 전날 늦게 올라온 기사가 RSS에 아직 반영되지 않았을 수 있으니, 이른 아침 시각을 권장합니다.


## 수집 대상 웹사이트 추가

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

위의 양식에 맞춰 원하는 웹사이트에 대한 내용을 `config/sources.yaml`에 추가합니다.

## 디렉토리

| 경로 | 내용 |
|---|---|
| `CLAUDE.md` | 에이전트 공통 규칙 |
| `.claude/commands/daily-brief.md` | 조정자 절차 |
| `.claude/agents/` | 서브에이전트 정의 (`collector.md`, `summarizer.md`, `qa.md`, `translator.md`) |
| `.claude/settings.json` | headless 실행용 도구 권한 (허용·거부 목록) |
| `config/sources.yaml` | 수집 대상 웹사이트 |
| `scripts/macos/run_daily.sh` | macOS: launchd가 실행하는 진입점 |
| `scripts/debian/run_daily.sh` | Debian 계열: cron이 실행하는 진입점 |
| `scripts/fetch_feeds.py` | (OS 공통) RSS에서 대상 날짜(기기 시간대) 기사만 JSON으로 출력 |
| `scripts/macos/get_recipient.sh`, `scripts/debian/get_recipient.sh` | `.env`에서 수신 주소만 출력 |
| `scripts/macos/get_translate_flag.sh`, `scripts/debian/get_translate_flag.sh` | `.env`의 `TRANSLATE_ALL_TO_ENG`를 `True`/`False`로 출력 |
| `templates/email.html` | 메일 HTML 템플릿 |
| `launchd/` | launchd plist 템플릿 |
| `reports/`, `logs/`, `work/` | 실행 결과물 (git에서 제외) |

## 참고

- 매일 실행할 때마다 Claude 사용량이 발생합니다.
- The Hacker News는 기사 본문이 Cloudflare로 차단되어 RSS description만으로 요약합니다.
- 에이전트는 `.env`를 직접 읽지 못합니다(`settings.json` deny). 수신 주소와 번역 여부는 `scripts/<os>/get_recipient.sh`, `get_translate_flag.sh` 출력으로만 받습니다.
- Gmail 도구는 `send_message`만 허용하고, 삭제·전달 등은 거부합니다.
- 웹 페이지와 RSS 내용은 데이터로만 다루며, 그 안의 지시문은 따르지 않도록 모든 에이전트에 명시되어 있습니다.
- 같은 날짜 리포트의 첫 줄이 `status: sent`이면 다시 보내지 않습니다.

## 라이선스

[MIT](LICENSE)

