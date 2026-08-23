#!/usr/bin/env python3
"""research.py — 搜索结果合并 + 相关性闸门 + 可选 fetch。fast-track（并行 + 硬超时 + early-stop）。

用法:
  python research.py "query"                                      # 单条 auto 路由，6s 内出 Top5
  python research.py --queries "q1|q2|q3"                         # 多条并行
  python research.py "query" --mode=web|tech|github|foreign
  python research.py "query" --top=5 --min-score=20 --timeout=6 --fetch

配置(环境变量):
  SEARCH_PY / GITHUB_SEARCH_PY / FETCH_PY   覆盖各后端脚本路径（默认同目录）
  GH_TOKEN / 等由各后端自行读取
"""
import argparse
import asyncio
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _path(env, name):
    return os.environ.get(env, os.path.join(HERE, name))


SEARCH = _path("SEARCH_PY", "search.py")
GITHUB_SEARCH = _path("GITHUB_SEARCH_PY", "github_search.py")
FETCH = _path("FETCH_PY", "fetch.py")
PY = sys.executable
PROXY = os.environ.get("SEARCH_PROXY", "http://127.0.0.1:7890")

TECH_KW = re.compile(
    r"error|crash|hang|freeze|exception|bug|fix|version|compile|build|dependenc|incompat|compat"
    r"|issue|github|repo|hook|termux|linux|python|cryptograph|pydantic|mcp|proot|docker|api|sdk"
    r"|报错|崩溃|卡死|兼容|编译|失败|安装|超时|配置|命令|版本|异常", re.I)

STOP = set("the a an of and or in on for to with is are was be it by at from as into that this".split())
HIGH_CONF = 80


def tokenize(t):
    return [w for w in re.findall(r"[a-z0-9]{2,}", t.lower()) if w not in STOP]


def run_backend(flag, query, env_proxy=False, timeout=6):
    env = dict(os.environ)
    if env_proxy:
        for k in ("HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"):
            env.setdefault(k, PROXY)
    if flag == "--github":
        cmd = [PY, GITHUB_SEARCH, query]
    else:
        cmd = [PY, SEARCH, flag, query] if flag else [PY, SEARCH, query]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=timeout)
    except subprocess.TimeoutExpired:
        return []
    res = re.findall(r"### (.+?)\n(.+?)\n(.*?)(?=\n###|\n\n|\Z)", r.stdout, re.S)
    items = []
    for title, url, snippet in res:
        items.append({"title": title.strip(), "url": url.strip(), "snippet": snippet.strip()[:220]})
    return items


def domain_bonus(url):
    u = url.lower()
    if "github.com" in u:
        return 40
    if any(d in u for d in ("docs.", "/docs/", "official", "python.org", "nodejs.org", "mozilla.org")):
        return 30
    return 10


def score_item(item, queries):
    text = (item["title"] + " " + item["url"] + " " + item["snippet"]).lower()
    best = 0.0
    for q in queries:
        terms = tokenize(q)
        if not terms:
            continue
        hit = sum(1 for t in terms if t in text)
        best = max(best, hit / len(terms))
    return int(best * 100 + domain_bonus(item["url"]))


def dedupe(items):
    seen, out = set(), []
    for it in items:
        if not it["url"] or it["url"] in seen:
            continue
        seen.add(it["url"])
        out.append(it)
    return out


def choose_keys(args, q):
    mode = "tech" if (args.mode == "auto" and TECH_KW.search(q)) else args.mode
    if mode == "tech":
        # 技术/专业问题：只搜 GitHub（官方 repo-scoped + token 全文）；web 是浪费时间
        return mode, ["github"]
    if mode == "github":
        return mode, ["github"]
    if mode == "foreign":
        return mode, ["foreign"]
    if mode == "web":
        return mode, ["web", "foreign"] if re.search(r"[A-Za-z]{4,}", q) else ["web"]
    return mode, ["web"]


async def _launch(t, timeout):
    q, backend = t
    proxy = backend == "foreign"
    flag = {"github": "--github", "foreign": "--foreign", "web": ""}[backend]
    try:
        items = await asyncio.to_thread(run_backend, flag, q, proxy, timeout)
        return backend, items
    except Exception:  # noqa: BLE001
        return backend, []


async def _collect(tasks, queries, timeout):
    pending = {}
    for t in tasks:
        pending[asyncio.ensure_future(_launch(t, timeout))] = t
    all_items = []
    stop = False
    while pending and not stop:
        done_set, pending = await asyncio.wait(list(pending), return_when=asyncio.FIRST_COMPLETED)
        for fut in done_set:
            backend, items = fut.result()
            all_items.extend(items)
            if backend == "github" and any(score_item(i, queries) >= HIGH_CONF for i in items):
                stop = True
                for f in pending:
                    f.cancel()
                pending = set()
                break
    return all_items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query", nargs="*", default=[])
    ap.add_argument("--queries", default="")
    ap.add_argument("--mode", default="auto")
    ap.add_argument("--top", type=int, default=5)
    ap.add_argument("--min-score", type=int, default=20)
    ap.add_argument("--timeout", type=float, default=6.0)
    ap.add_argument("--fetch", action="store_true", help="对 Top1-2 抓正文（额外 8s/个）")
    args = ap.parse_args()

    queries = args.queries.split("|") if args.queries else [" ".join(args.query)]
    queries = [q.strip() for q in queries if q.strip()]
    if not queries:
        print("usage: research.py \"query\" [--queries \"q1|q2\"] [--mode=...] [--top=5] [--fetch]")
        return

    mode, keys = choose_keys(args, queries[0])
    tasks = [(q, k) for q in queries for k in keys]
    items = asyncio.run(_collect(tasks, queries, args.timeout))

    items = dedupe(items)
    for it in items:
        it["score"] = score_item(it, queries)
    items = [it for it in items if it["score"] >= args.min_score]
    items.sort(key=lambda x: x["score"], reverse=True)
    items = items[: args.top]

    print(f"QUERY: {' | '.join(queries)}   [mode={mode}  timeout={args.timeout}s]")
    if not items:
        print("无可信结果（全被相关性闸门过滤，或网络失败/超时）。可降低 --min-score。")
        return
    for i, it in enumerate(items, 1):
        rel = "HIGH" if it["score"] >= 60 else ("MEDIUM" if it["score"] >= 30 else "LOW")
        print(f"{i}. [{rel}] score={it['score']} · {it['title']}")
        print(f"   url: {it['url']}")
        if it["snippet"]:
            print(f"   {it['snippet']}")
        print()

    if args.fetch and items:
        print("===== FETCH Top {} 正文 =====".format(min(2, len(items))))
        for it in items[:2]:
            print(f"\n### {it['title']}")
            print(it["url"])
            try:
                r = subprocess.run([PY, FETCH, it["url"]], capture_output=True, text=True, timeout=8)
                out = r.stdout.strip()
                print(out[:1500] if out else "(无正文，可能反爬或空)")
            except subprocess.TimeoutExpired:
                print(f"[fetch 超时] {it['url']}")


if __name__ == "__main__":
    main()
