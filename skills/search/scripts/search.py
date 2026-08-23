#!/usr/bin/env python3
"""search.py — 调 CC-Web-MCP 搜索后端做一次搜索（bing_cn / duckduckgo 兜底）。

用法:
  python search.py [--foreign|--github] <query>

配置:
  CC_WEB_MCP_SRC  指向 CC-Web-MCP 源码目录（web.py 所在）。
  GitHub 官方 issue 推荐走 github_search.py（GitHub API + token，可拿全文）。
"""
import asyncio
import os
import sys

CC_SRC = os.environ.get("CC_WEB_MCP_SRC", "")
if CC_SRC:
    sys.path.insert(0, CC_SRC)
try:
    from cc_web_mcp import web  # noqa: E402
except ImportError:
    print("缺少 cc_web_mcp：请设置环境变量 CC_WEB_MCP_SRC 指向 CC-Web-MCP 源码目录")
    sys.exit(1)


async def main() -> None:
    args = sys.argv[1:]
    foreign = "--foreign" in args
    github = "--github" in args
    if foreign:
        args = [a for a in args if a != "--foreign"]
    if github:
        args = [a for a in args if a != "--github"]
    query = " ".join(args) if args else sys.stdin.read().strip()
    if not query:
        print("用法: search.py [--foreign|--github] <query>")
        return

    if github:
        # site 限定 GitHub；官方 issue 全文请用 github_search.py（GitHub API+token）
        query += " site:github.com"

    config = web.load_config()
    if foreign:
        config = web._config_with_search_providers(config, ("duckduckgo",))
    elif github:
        config = web._config_with_search_providers(config, ("bing_cn",))
    else:
        config = web._config_with_search_providers(config, ("bing_cn", "duckduckgo"))

    r = await web.search_web(query, max_results=5, config=config)
    if r.get("ok"):
        for x in r.get("results", []):
            print(f"### {x.get('title')}")
            print(x.get("url"))
            if x.get("snippet"):
                print(x.get("snippet")[:300])
                print()
    else:
        print("搜索失败:", r.get("error", "未知错误"))


if __name__ == "__main__":
    asyncio.run(main())
