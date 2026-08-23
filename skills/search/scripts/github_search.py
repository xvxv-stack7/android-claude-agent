#!/usr/bin/env python3
"""github_search.py — 用 GitHub Search API 搜 issue/PR/repo，直接拿全文 body（绕网页反爬）。

用法:
  python github_search.py "<query>"          # 默认搜 issues/pr
  python github_search.py "<query>" --repo    # 搜仓库(按 star 排序)

配置:
  GH_TOKEN  GitHub 个人访问令牌（读公共仓库需 read 权限）。
  多词 query 的降级重试：GitHub 搜索空格默认为 AND，词一多就 0 结果 → 这里减词到能命中，
  且永远保留 repo:/org:/is: 限定符（保持 repo-scoped 搜索不被拆坏）。
"""
import os
import re
import sys

import httpx

API_ISSUES = "https://api.github.com/search/issues"
API_REPOS = "https://api.github.com/search/repositories"
PER_PAGE = 5

STOP = set("the a an of and or in on for to with is are was be it by at from as into that this how what why which".split())
DIGEST_RE = re.compile(r"\b(digest|weekly|daily|newsletter|周报|日报)\b", re.I)
QUAL_RE = re.compile(r"\b(?:repo|org|is|in|label|author|state|milestone|user|language|topic|type):[^\s]+", re.I)


def clean_md(s):
    s = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", s or "")        # 图片
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)           # 链接→显示文本
    s = re.sub(r"```.*?```", "", s, flags=re.S)              # 代码块
    s = re.sub(r"[`#*_>~\[\]]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def candidates_for(query):
    """先原句；空则按去停用词后的词数递减，但始终保留限定符（只减自由词）。"""
    quals = QUAL_RE.findall(query)
    qual_str = " ".join(quals)
    free = [t for t in re.findall(r"[A-Za-z0-9][A-Za-z0-9_-]{1,}", QUAL_RE.sub(" ", query)) if t.lower() not in STOP]
    cands = []
    for n in range(len(free), -1, -1):
        c = (qual_str + " " + " ".join(free[:n])).strip()
        if c and c not in cands:
            cands.append(c)
    return cands or [query]


def main() -> None:
    token = os.environ.get("GH_TOKEN", "").strip()
    if not token:
        print("[github_search] 需要环境变量 GH_TOKEN")
        return

    args = [a for a in sys.argv[1:]]
    repo_mode = "--repo" in args or "--mode=repo" in args
    args = [a for a in args if a not in ("--repo",) and not a.startswith("--mode")]
    query = " ".join(args) if args else sys.stdin.read().strip()
    if not query:
        print("用法: github_search.py \"query\" [--repo]")
        return

    headers = {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}

    def search_one(q):
        r = httpx.get(API_REPOS if repo_mode else API_ISSUES,
                      params={"q": q, "per_page": PER_PAGE,
                              "sort": "stars" if repo_mode else "relevance"},
                      headers=headers, timeout=15)
        r.raise_for_status()
        items = r.json().get("items", [])
        return [it for it in items if not (not repo_mode and DIGEST_RE.search(it.get("title") or ""))]

    items = []
    for c in candidates_for(query):
        try:
            items = search_one(c)
        except httpx.HTTPStatusError as e:
            print(f"[github_search] API 错误 {e.response.status_code}: {e.response.text[:200]}")
            return
        except Exception as e:  # noqa: BLE001
            print(f"[github_search] 失败: {type(e).__name__}: {str(e)[:200]}")
            return
        if items:
            break
    if not items:
        print("[github_search] 无结果（降级重试后仍空）")
        return

    for it in items:
        if repo_mode:
            title = it.get("full_name") or it.get("name") or ""
            url = it.get("html_url") or ""
            body = it.get("description") or ""
        else:
            title = it.get("title") or ""
            url = it.get("html_url") or ""
            body = it.get("body") or ""
        print(f"### {title}")
        print(url)
        print(clean_md(body or "")[:400])
        print()


if __name__ == "__main__":
    main()
