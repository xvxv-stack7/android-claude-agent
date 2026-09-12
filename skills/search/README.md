# Claude Code Research Skill（搜索增强模板）

一套给 Claude Code 类 agent 用的快速研究 skill：构造精 query → 并行快速搜 → 相关性过滤 → 拿全文 → 给 Research Brief。把一次研究压在 10~25 秒，而不是东搜西找 4 分钟。

## 它解决什么

搜得准，不如搜得对 + 快。质量差的根子常在 query 本身：把自然语言整句丢搜索引擎、把所有词 AND 一起、撞到几个词就以为找到答案。这套模板用：

- **Query Planner**：先提取字段，再生成 2~4 条不同目的的短 query，别把已知的每个词都塞进一条
- **相关性闸门**：搜到 ≠ 能答，低于阈值直接扔，防"撞词"
- **GitHub 优先**：技术/专业问题直接走 GitHub 官方 issue，`repo:` 限定 + token 拿全文（绕网页反爬）

## 依赖

- Python 3.10+
- **CC-Web-MCP**（搜索后端，负责 bing_cn / duckduckgo / GitHub 等 provider 的请求）
- 可选：**GitHub 个人访问令牌**（`GH_TOKEN`）——技术问题走 GitHub API 拿 issue 全文，绕开网页对爬虫的反爬

## 安装

1. 把这个 `search-skill/` 目录放到 Claude Code 的 skills 目录：
   ```
   ~/.claude/skills/research/     # 全局；或项目里 .claude/skills/research/
   ```
2. 设置环境变量（按你的环境写进 `~/.bashrc` 或启动脚本）：
   ```bash
   export CC_WEB_MCP_SRC=/path/to/CC-Web-MCP/src   # CC-Web-MCP 源码目录（web.py 所在）
   export GH_TOKEN=ghp_xxxx                        # 可选，GitHub 令牌
   ```
3. 后端脚本需要 `httpx`（github_search / fetch 用）：
   ```bash
   pip install httpx
   ```

## 用法

```bash
research "query"                                    # 单条 auto 路由，秒级出 Top5
research --queries "q1|q2|q3"                       # 多条并行合并
research "repo:xxx/yyy is:issue in:title hang" --mode=tech
research "query" --fetch                            # 对 Top1-2 抓正文
```

玩法与协议详见 `SKILL.md`（Query Planner 铁律 + GitHub 优先策略 + 完整流程）。

## 目录

- `SKILL.md`        skill 主文档（Query Planner 协议 + GitHub 优先策略 + 完整流程）
- `scripts/`        搜索脚本（search.py / research.py / github_search.py / fetch.py）
- `README.md`       本文件

## 实测作者

**xvxv-stack7** —— 在 Termux / 安卓上实测；从 4 分钟压到几秒拿 GitHub 官方 issue 全文。欢迎反馈提 issue。

授权以仓库根 `LICENSE` 为准。
