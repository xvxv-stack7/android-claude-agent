#!/usr/bin/env python3
"""fetch.py — 抓单个 URL 正文。GitHub issue/PR 走 GitHub API + token（绕网页反爬），其他走 CC-Web-MCP fetch_page。

用法:
  python fetch.py <url>
配置:
  GH_TOKEN       GitHub 个人访问令牌（抓 GitHub issue 全文用）
  CC_WEB_MCP_SRC 指向 CC-Web-MCP 源码目录
"""
import asyncio
import os
import re
import sys

import httpx

_GITHUB_RE = re.compile(r"https?://github\.com/([^/]+)/([^/]+)/(issues|pull)/(\d+)")

TIMEOUT = 8.0
MAX_CHARS = 3000


async def _gh_issue(owner, repo, num, token):
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}
    r = await asyncio.wait_for(
        httpx.get(f"https://api.github.com/repos/{owner}/{repo}/issues/{num}", headers=headers, timeout=15),
        timeout=TIMEOUT,
    )
    r.raise_for_status()
    d = r.json()
    return d.get("title", ""), d.get("body") or ""


async def _fetch_via_mcp(url):
    sys.path.insert(0, os.environ.get("CC_WEB_MCP_SRC", ""))
    from cc_web_mcp import web  # noqa: E402
    config = web.load_config()
    r = await asyncio.wait_for(web.fetch_page(url=url, config=config), timeout=TIMEOUT)
    if not r.get("ok"):
        return None
    return (r.get("final_url") or url), (r.get("markdown") or "")


async def main() -> None:
    url = sys.argv[1] if len(sys.argv) > 1 else ""
    if not url:
        print("用法: fetch.py <url>")
        return

    token = os.environ.get("GH_TOKEN", "").strip()
    m = _GITHUB_RE.match(url)
    try:
        if m and token:
            title, body = await _gh_issue(m.group(1), m.group(2), m.group(4), token)
            md = body or ""
            print(f"URL: {url}")
            print(f"[{len(md)} 字符] · {title}")
            print("---")
            print(md[:MAX_CHARS])
            return
        out = await _fetch_via_mcp(url)
        if not out:
            print(f"[fetch 未成功] {url}")
            return
        final_url, md = out
        print(f"URL: {final_url or url}")
        print(f"[{len(md)} 字符]")
        print("---")
        print(md[:MAX_CHARS])
    except asyncio.TimeoutError:
        print(f"[fetch 超时 {TIMEOUT}s] {url}")
    except Exception as e:  # noqa: BLE001
        print(f"[fetch 失败] {url} :: {type(e).__name__}: {str(e)[:200]}")


if __name__ == "__main__":
    asyncio.run(main())
