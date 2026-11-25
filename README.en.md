# Overview

[한국어](README.md)

A Claude Code agent that collects the previous day's (KST) cybersecurity news, summarizes it, and emails you a briefing every morning.
It runs `claude -p "/daily-brief"` at 07:30 every day, using launchd on macOS and a cron job on Debian Linux.


## Email layout

Subject: `[Claude 일일 보안 브리핑] YYYY-MM-DD (기사 N건)`

1. **Today's trends** — 3–5 bullets in Korean. Each bullet carries the source numbers `[n]` of the articles it is based on
2. **Articles by category** — Ransomware / Vulnerabilities·CVE / Data breach / APT·state-sponsored / Malware·phishing / Policy·regulation / Other. Each article gets a 2–3 sentence summary in its original language plus its source number `[n]`
3. **Collection failures** — sites that failed and why
4. **Sources** — numbered list in the form `[n] Article title( URL )`

Each sent briefing is archived to `reports/YYYY-MM-DD.md` and used for trend comparison the next day.


## Agent architecture

`/daily-brief` is a **coordinator** that does no work itself. It calls four role-specific subagents (translator only when `TRANSLATE_ALL_TO_ENG=True`).

```
/daily-brief (coordinator: date, duplicate check, dispatch, sending email)
   │
   ├─▶ collector  (sonnet)  RSS + article bodies           → work/DATE/articles.json
   ├─▶ summarizer (sonnet)  summaries, merging, trends     → reports/DATE.md, email.html, meta.json
   └─▶ qa         (haiku, read-only) rule checks           → {pass, issues[{owner, …}]}
            │
            └─ each issue is forwarded as-is only to its owner agent → re-check (max 2 rounds)
               anything still failing: the article is dropped, noted in the memo, and the email is sent
   │
   └─▶ translator (sonnet)  English email (optional)       → email.en.html, meta.en.json
            └─ qa checks the translation (structure, links, no Korean left) → fixes go only to translator (max 2 rounds)
               still failing: the Korean email is sent instead
```

- Agents exchange data only through file paths. The coordinator never reads article bodies.
- Only the coordinator can send email. Agents that read web content cannot.

## Requirements

#### Tech stack
![Static Badge](https://img.shields.io/badge/AI-black?style=for-the-badge)![Claude](https://img.shields.io/badge/claude-%23D97757.svg?style=for-the-badge&logo=claude&logoColor=white)![Claude Code](https://img.shields.io/badge/Claude%20Code-%23D97757.svg?style=for-the-badge&logo=claudecode&logoColor=white)

![Static Badge](https://img.shields.io/badge/OS-black?style=for-the-badge)![Debian](https://img.shields.io/badge/Debian-%23D70A53.svg?style=for-the-badge&logo=debian&logoColor=white)![macOS](https://img.shields.io/badge/mac%20os-%23000000.svg?style=for-the-badge&logo=macos&logoColor=F0F0F0&logoSize=auto)

![Static Badge](https://img.shields.io/badge/Languages-black?style=for-the-badge)![Bash Script](https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)![Python](https://img.shields.io/badge/python-%233670A0.svg?style=for-the-badge&logo=python&logoColor=ffdd54)

#### Also required
- [Claude Code](https://docs.claude.com/en/docs/claude-code), installed and logged in
- The **Gmail connector** connected on claude.ai (uses `mcp__claude_ai_Gmail__send_message`)


## Installation

#### Common

```bash
git clone https://github.com/greyhawk16/cybersecurity_news_collector.git
cd cybersecurity_news_collector

# Set the recipient email
cp .env.example .env
# Open .env and set RECIPIENT_EMAIL_ADDRESS to your address
# Set TRANSLATE_ALL_TO_ENG=True to receive the whole email in English (default False; the report archive stays in Korean)

# Trust the folder (once) — run claude, accept the trust prompt, then exit
claude
```

#### First run

##### MacOS

```bash
scripts/macos/run_daily.sh
```

##### Debian Linux

```bash
sudo apt update && sudo apt install fonts-nanum -y
scripts/debian/run_daily.sh
cat logs/$(TZ=Asia/Seoul date +%F).log
```


> (macOS) macOS protection policies block launchd jobs if the folder is inside `~/Documents`, `~/Desktop`, or `~/Downloads`. Clone it somewhere else.
>
> (Debian) Run `claude` directly on the Linux machine that will run the job, log in with your claude.ai account, and trust the folder. The Gmail connector must be connected to that claude.ai account for emails to be sent.

See [AUTOMATION.en.md](AUTOMATION.en.md) for turning the schedule on and off, and for troubleshooting.


## Adding a news source

```yaml
  - name: Site name
    url: https://example.com/
    language: en            # summary language (original language is kept)
    feed: https://example.com/rss
    feed_timezone: "+09:00" # only if pubDate has no time zone
    fetch_article: true     # whether article pages can be fetched with WebFetch; false = RSS description only
    notes: >
      site-specific notes such as exclusion rules
```

Add an entry for the site you want to `config/sources.yaml`, following the format above.

## Directory layout

| Path | Contents |
|---|---|
| `CLAUDE.md` | Rules shared by all agents |
| `.claude/commands/daily-brief.md` | Coordinator procedure |
| `.claude/agents/` | Subagent definitions (`collector.md`, `summarizer.md`, `qa.md`, `translator.md`) |
| `.claude/settings.json` | Tool permissions for the headless run (allow and deny lists) |
| `config/sources.yaml` | News sources |
| `scripts/macos/run_daily.sh` | macOS: entry point that launchd runs |
| `scripts/debian/run_daily.sh` | Debian-based: entry point that cron runs |
| `scripts/fetch_feeds.py` | (all OSes) Outputs only the target date's (KST) articles from each RSS feed as JSON |
| `scripts/macos/get_recipient.sh`, `scripts/debian/get_recipient.sh` | Print only the recipient address from `.env` |
| `scripts/macos/get_translate_flag.sh`, `scripts/debian/get_translate_flag.sh` | Print `TRANSLATE_ALL_TO_ENG` from `.env` as `True`/`False` |
| `templates/email.html` | Email HTML template |
| `launchd/` | launchd plist template |
| `reports/`, `logs/`, `work/` | Run output (git-ignored) |

## Notes

- Each daily run uses your Claude usage.
- The Hacker News blocks article pages with Cloudflare, so its articles are summarized from the RSS description only.
- Agents cannot read `.env` directly (denied in `settings.json`). The recipient address and the translation flag come only from the output of `scripts/<os>/get_recipient.sh` and `get_translate_flag.sh`.
- Of the Gmail tools, only `send_message` is allowed. Deleting, forwarding and similar tools are denied.
- Web pages and RSS content are treated as data only. Every agent is explicitly told not to follow instructions found in them.
- If the report for a date already starts with `status: sent`, it is not sent again.

## License

[MIT](LICENSE)
