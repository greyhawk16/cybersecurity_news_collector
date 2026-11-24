#!/usr/bin/env python3
"""config/sources.yaml의 각 사이트 RSS에서 TARGET 날짜(KST) 기사만 골라 JSON으로 출력한다.

사용법: python3 scripts/fetch_feeds.py [YYYY-MM-DD]   (생략 시 KST 기준 어제)
출력:   {"target": ..., "sources": [{"name", "ok", "error", "items": [{title, url, published_kst, description}]}]}
표준 라이브러리만 사용한다.
"""
import html
import json
import re
import ssl
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

KST = timezone(timedelta(hours=9))
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
ROOT = Path(__file__).resolve().parent.parent
# python.org 배포판은 시스템 인증서를 쓰지 않으므로 macOS 기본 CA 번들을 명시
_CA = "/etc/ssl/cert.pem"
SSL_CTX = ssl.create_default_context(cafile=_CA) if Path(_CA).exists() else ssl.create_default_context()


def load_sources():
    """sources.yaml에서 name / feed / feed_timezone만 간단히 파싱 (PyYAML 의존성 없이)."""
    sources, cur = [], None
    for line in (ROOT / "config" / "sources.yaml").read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*-\s*name:\s*(.+)", line)
        if m:
            cur = {"name": m.group(1).strip()}
            sources.append(cur)
            continue
        m = re.match(r"\s+(feed|feed_timezone):\s*(\S+)", line)
        if m and cur is not None:
            cur[m.group(1)] = m.group(2).strip().strip("\"'")
    return sources


def parse_date(text, default_tz):
    text = text.strip()
    try:
        dt = parsedate_to_datetime(text)  # RFC 822 (예: Sun, 22 Nov 2026 10:36:55 +0530)
    except (TypeError, ValueError):
        dt = None
    if dt is None:
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%d %H:%M"):
            try:
                dt = datetime.strptime(text, fmt)
                break
            except ValueError:
                pass
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=default_tz)
    return dt.astimezone(KST)


def clean(text):
    text = re.sub(r"<[^>]+>", " ", html.unescape(text or ""))
    return re.sub(r"\s+", " ", text).strip()[:1500]


def fetch(src, target):
    if "feed" not in src:
        return {"name": src["name"], "ok": False, "error": "feed 미설정", "items": []}
    tz = KST
    if src.get("feed_timezone", "").startswith(("+", "-")):
        sign = 1 if src["feed_timezone"][0] == "+" else -1
        h, m = src["feed_timezone"][1:].split(":")
        tz = timezone(sign * timedelta(hours=int(h), minutes=int(m)))
    try:
        req = urllib.request.Request(src["feed"], headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=30, context=SSL_CTX) as r:
            root = ET.fromstring(r.read())
    except Exception as e:  # noqa: BLE001 — 사이트별 실패는 기록하고 계속 진행
        return {"name": src["name"], "ok": False, "error": f"{type(e).__name__}: {e}", "items": []}
    items = []
    for it in root.iter("item"):
        dt = parse_date(it.findtext("pubDate") or "", tz)
        if dt is None or dt.strftime("%Y-%m-%d") != target:
            continue
        items.append({
            "title": clean(it.findtext("title")),
            "url": (it.findtext("link") or "").strip(),
            "published_kst": dt.strftime("%Y-%m-%d %H:%M"),
            "description": clean(it.findtext("description")),
        })
    return {"name": src["name"], "ok": True, "error": None, "items": items}


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else (datetime.now(KST) - timedelta(days=1)).strftime("%Y-%m-%d")
    out = {"target": target, "sources": [fetch(s, target) for s in load_sources()]}
    print(json.dumps(out, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
