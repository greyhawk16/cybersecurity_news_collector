# Claude Daily Security Briefing

[한국어](README.md)

A Claude Code agent that collects the previous day's (KST) cybersecurity news, summarizes it, and emails you a briefing every morning.
macOS launchd runs `claude -p "/daily-brief"` at 07:30 daily, fully headless with no human in the loop.

> The agent instructions (`CLAUDE.md`, `.claude/`) and the email are written in Korean. Article summaries keep each article's original language.

## Email layout

Subject: `[Claude 일일 보안 브리핑] YYYY-MM-DD (기사 N건)`

1. **Today's trends**: 3–5 bullets in Korean, each ending with links to the source articles
2. **Articles by category**: Ransomware / Vulnerabilities·CVE / Data breach / APT·state-sponsored / Malware·phishing / Policy·regulation / Other. Each article gets a 2–3 sentence summary in its original language plus the original link
3. **Collection failures**: which sites failed and why

Each sent briefing is archived to `reports/YYYY-MM-DD.md` and used for trend comparison the next day.

## Agent architecture

`/daily-brief` is a **coordinator** that does no collection or writing itself. It calls three role-specific subagents.

```
/daily-brief (coordinator: date, duplicate check, dispatch, sending email)
   │
   ├─▶ collector  (sonnet)  RSS + article bodies           → work/DATE/articles.json
   ├─▶ summarizer (sonnet)  summaries, merging, trends     → reports/DATE.md, email.html, meta.json
   └─▶ qa         (haiku, read-only) rule checks           → {pass, issues[{owner, …}]}
            │
            └─ each issue is forwarded verbatim only to its owner agent → re-check (max 2 rounds)
               anything still failing: the article is dropped, noted in the memo, and the email is sent
```

- Agents exchange data only through file paths. The coordinator never reads article bodies.
- Only the coordinator can send email. Agents that read web content cannot.

## Requirements

- macOS (uses `date -v` and launchd)
- [Claude Code](https://docs.claude.com/en/docs/claude-code), installed and logged in
- The **Gmail connector** connected on claude.ai (uses `mcp__claude_ai_Gmail__send_message`)
- Python 3 (standard library only)

## Setup

```bash
git clone <this repository URL>
cd <cloned folder>

# 1. Set the recipient
cp .env.example .env
# edit .env and set RECIPIENT_EMAIL_ADDRESS to your address

# 2. Trust the folder (once): run claude, accept the trust prompt, then exit
claude

# 3. Run once manually and check that the email arrives
scripts/run_daily.sh
cat logs/$(TZ=Asia/Seoul date +%F).log

# 4. Schedule the daily run: see AUTOMATION.md
```

> macOS blocks launchd jobs inside `~/Documents`, `~/Desktop`, and `~/Downloads`. Clone somewhere else.

[AUTOMATION.md](AUTOMATION.md) (Korean) covers turning the schedule on and off, and troubleshooting. Run every command in it from the cloned folder: the plist gets your folder path from `$PWD` automatically.

## Adding a news source

Add an entry to `config/sources.yaml`:

```yaml
  - name: Site name
    url: https://example.com/
    language: en            # summary language (original language is kept)
    feed: https://example.com/rss
    feed_timezone: "+09:00" # only if pubDate has no time zone
    fetch_article: true     # whether article pages can be fetched; false = RSS description only
    notes: >
      site-specific notes such as exclusion rules
```

## Layout

| Path | Contents |
|---|---|
| `CLAUDE.md` | Rules shared by all agents |
| `.claude/commands/daily-brief.md` | Coordinator procedure |
| `.claude/agents/` | Subagent definitions (`collector.md`, `summarizer.md`, `qa.md`) |
| `.claude/settings.json` | Tool permissions for the headless run (allow and deny lists) |
| `config/sources.yaml` | News sources |
| `scripts/run_daily.sh` | Entry point that launchd runs |
| `scripts/fetch_feeds.py` | Outputs only the target date's (KST) articles from each RSS feed as JSON |
| `scripts/get_recipient.sh` | Prints only the recipient address from `.env` |
| `templates/email.html` | Email HTML template |
| `launchd/` | launchd plist template |
| `reports/`, `logs/`, `work/` | Run output (git-ignored) |

## Security design

- Agents cannot read `.env` directly (denied in `settings.json`). The recipient comes only from `scripts/get_recipient.sh`.
- Of the Gmail tools, only `send_message` is allowed. Deleting, forwarding and similar tools are denied.
- Web pages and RSS content are treated as data only. Every agent is told not to follow instructions found in them.
- If the report for a date already starts with `status: sent`, nothing is sent again.

## Notes

- Each daily run uses your Claude usage.
- The Hacker News blocks article pages with Cloudflare, so its articles are summarized from the RSS description only.

## License

[MIT](LICENSE)
