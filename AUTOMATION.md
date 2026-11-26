# 자동 실행 켜기 / 끄기

[English](AUTOMATION.en.md)

매일 07:30에 macOS launchd가 `scripts/macos/run_daily.sh`를 실행해 전날 보안 브리핑을 메일로 보냅니다.
Debian 계열 리눅스는 아래 [Debian 계열 리눅스 (cron)](#debian-계열-리눅스-cron) 절을 보세요.

- 작업 이름(Label): `com.user.securitybrief`
- 원본 설정 파일: `launchd/com.user.securitybrief.plist` (경로 자리에 `__PROJECT_DIR__`가 들어 있는 템플릿)
- 등록 위치: `~/Library/LaunchAgents/com.user.securitybrief.plist`

> **아래 명령은 모두 clone한 폴더(저장소 루트)에서 실행합니다.**
> 먼저 `cd <clone한 폴더>`로 이동하세요. 등록할 때 현재 폴더 경로(`$PWD`)가 plist에 자동으로 들어가므로 경로를 직접 고칠 필요가 없습니다.

# Debian 계열 리눅스 (cron)

`scripts/debian/run_daily.sh`를 cron으로 매일 실행합니다. 아래 명령도 clone한 폴더에서 실행합니다.

먼저 그 장비에서 `claude`를 실행해 claude.ai 계정으로 로그인하고 폴더 신뢰를 승인하세요(최초 1회). 메일은 그 계정에 연결된 Gmail 커넥터로 발송됩니다.

```bash
# 시스템 시간대 확인 — 실행 시각(30 7)과 "전날" 기준 모두 이 시간대를 따름
timedatectl | grep "Time zone"

# 켜기: 현재 crontab에 한 줄 추가 (경로는 $PWD로 자동 입력)
( crontab -l 2>/dev/null | grep -v securitybrief; echo "30 7 * * * $PWD/scripts/debian/run_daily.sh # securitybrief" ) | crontab -

# 상태 확인
crontab -l | grep securitybrief

# 지금 바로 한 번 실행
scripts/debian/run_daily.sh

# 끄기 (해당 줄만 제거)
crontab -l | grep -v securitybrief | crontab -
```

- 장비가 꺼져 있거나 잠자기 중이면 그 시각의 실행은 건너뜁니다.
- 실행 로그는 macOS와 같은 `logs/YYYY-MM-DD.log`에 남습니다.
- 폴더를 옮기면 "끄기" 후 옮긴 폴더에서 "켜기"를 다시 실행하세요.


# MacOS

#### 1) 상태 확인

```bash
# 등록 여부 — 한 줄이 나오면 켜져 있음, 아무것도 없으면 꺼져 있음
launchctl list | grep securitybrief

# 상세 정보 (실행 횟수 runs, 마지막 종료 코드 last exit code 등)
launchctl print gui/$(id -u)/com.user.securitybrief

# 07:25 자동 기상 예약 확인
pmset -g sched
```

#### 2) 작업 활성화

```bash
# clone한 폴더에서 실행
mkdir -p ~/Library/LaunchAgents
test -f launchd/com.user.securitybrief.plist \
  && sed "s|__PROJECT_DIR__|$PWD|g" launchd/com.user.securitybrief.plist > ~/Library/LaunchAgents/com.user.securitybrief.plist \
  && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.securitybrief.plist \
  || echo "FAILED: run this from the cloned folder (repository root)"

# (권장) Mac이 잠자기 중이어도 07:25에 깨우기 — 관리자 비밀번호 필요
sudo pmset repeat wake MTWRFSU 07:25:00
```

등록된 경로는 `grep -A1 ProgramArguments ~/Library/LaunchAgents/com.user.securitybrief.plist`로 확인할 수 있습니다.

#### 3) 지금 바로 한 번 실행

```bash
launchctl kickstart gui/$(id -u)/com.user.securitybrief
```

전날 리포트(`reports/YYYY-MM-DD.md`)의 첫 줄이 이미 `status: sent`이면 다시 보내지 않고 종료합니다.

#### 4) 잠시 끄기 / 다시 켜기

`bootout`만 하면 plist 파일이 `~/Library/LaunchAgents/`에 남아 있어서 **재부팅이나 재로그인 때 다시 켜집니다.** 계속 꺼 두려면 파일도 옮겨 두세요.

```bash
# clone한 폴더에서 실행

# 끄기
launchctl bootout gui/$(id -u)/com.user.securitybrief
mv ~/Library/LaunchAgents/com.user.securitybrief.plist launchd/disabled.plist

# 다시 켜기
mv launchd/disabled.plist ~/Library/LaunchAgents/com.user.securitybrief.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.securitybrief.plist
```

`launchd/disabled.plist`에는 내 폴더 경로가 들어 있으므로 `.gitignore`로 커밋에서 제외됩니다.

#### 5) 완전히 해제

```bash
launchctl bootout gui/$(id -u)/com.user.securitybrief
rm ~/Library/LaunchAgents/com.user.securitybrief.plist

# 07:25 자동 기상 예약 해제
# 주의: 직접 설정한 다른 반복 전원 예약도 함께 지워짐
sudo pmset repeat cancel
```

프로젝트의 원본 plist(`launchd/`)는 남아 있으므로 "켜기" 절차로 언제든 다시 등록할 수 있습니다.

#### 6) 실행 시각·설정을 바꿨을 때


```bash
# clone한 폴더에서 실행
launchctl bootout gui/$(id -u)/com.user.securitybrief
test -f launchd/com.user.securitybrief.plist \
  && sed "s|__PROJECT_DIR__|$PWD|g" launchd/com.user.securitybrief.plist > ~/Library/LaunchAgents/com.user.securitybrief.plist \
  && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.securitybrief.plist \
  || echo "FAILED: run this from the cloned folder (repository root)"
```

`launchd/com.user.securitybrief.plist`를 수정한 뒤(예: `Hour`, `Minute`) 다시 등록해야 반영됩니다. `__PROJECT_DIR__`는 그대로 두세요.


# 문제 별 해결방법

| 증상 | 확인할 곳 / 해결 |
|---|---|
| 메일이 안 옴 | `logs/YYYY-MM-DD.log` (실행 당일 날짜), `logs/launchd.err` |
| 로그에 `Not logged in` | 터미널에서 `claude` 실행 후 다시 로그인 |
| 로그에 `has not been trusted` / 권한 거부 | clone한 폴더에서 `claude` 실행 후 폴더 신뢰 승인 |
| `launchctl print`에 `job state = spawn failed`, `last exit code = 78` (launchd.err도 비어 있음), 또는 `launchd.err`에 `can't open input file` (종료 코드 127) | 프로젝트가 `~/Documents`·`~/Desktop`·`~/Downloads` 같은 macOS 보호 폴더 안에 있으면 백그라운드 실행이 막힘 → 보호 폴더 밖으로 옮긴 뒤, 옮긴 폴더에서 "실행 시각·설정을 바꿨을 때" 절차로 재등록 |
| 아침에 실행되지 않음 | Mac이 꺼져 있거나, 노트북 덮개가 닫혀 있으면 실행되지 않을 수 있음 → 그 시간엔 전원 연결·덮개 열림 권장 |

# 참고 사항

- 프로젝트 폴더를 옮기면, 옮긴 폴더에서 "실행 시각·설정을 바꿨을 때" 절차를 다시 실행하세요. 새 경로가 자동으로 plist에 들어갑니다. `scripts/macos/run_daily.sh`·`scripts/debian/run_daily.sh`는 자기 위치를 기준으로 동작하므로 수정할 필요가 없습니다.
- 폴더 경로에 `|` 또는 `&` 문자가 있으면 `sed` 치환이 깨지므로 그런 이름은 피하세요.
