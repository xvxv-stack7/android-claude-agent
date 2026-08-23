---
name: research
description: 统一快速研究入口 + Query Planner。质量关键不是搜多少次，而是怎么构造 query——先提取字段，再生成多条不同目的的短 query，相关性闸门过滤，技术/专业问题优先 GitHub（repo-scoped）直接拿 issue 全文。| Unified research with Query Planning for coding agents. Never dump a raw question; plan purpose-built short queries, gate by relevance, and for technical questions go straight to GitHub issues.
---

# research（搜索 + Query Planner）

「Search 是找东西，Fetch 才是读东西。」质量差的根子常在 query 本身，不在搜索引擎。

本 skill 给 Claude Code 类 agent 提供一套可复用的快速研究流程：构造精 query → 并行快速搜 → 相关性过滤 → 拿全文 → 给 Research Brief。目标是把一次研究压到 10~25 秒，而不是几番折腾后 4 分钟。

## Query Planning Policy（给 agent 构造 query 的铁律）

**NEVER search the agent's full natural-language question verbatim**, unless it 是确切报错文本或引号短语。

搜索前先提取字段：PRODUCT（软件/项目名）、VERSION（已知版本）、ENVIRONMENT（OS/runtime/平台）、COMPONENT（受影响子系统）、SYMPTOM（可观察行为）、ERROR（确切报错）、TIME（是否要新）。

生成多条**不同目的**的短 query（通常 2–5 个术语），每条测不同假设：
- Q1 确切症状：`<product> <version> <symptom>`
- Q2 组件猜测：`<product> <component> <symptom>`
- Q3 环境兼容：`<product> <environment> <symptom>`
- Q4 issue 追踪（GitHub 优先时用限定符）：`repo:<official-repo> is:issue in:title <symptom>`
- Q5 确切报错：`"<exact error message>"`

**Do NOT put every known detail into every query.** 别把知道的都塞进一条。
技术词用开发者术语：`hang, freeze, deadlock, timeout, stdin, EOF, SIGTERM, SessionEnd, hook, regression, crash, ANR`。

## GitHub 优先（技术/专业问题直接搜 github）

**技术/编程/报错/兼容/API/hook/配置 这类问题：直接搜 GitHub 一个源，别浪费时间去 web 搜。**"搜其他是浪费时间"。

- 已知官方仓库（如 `claude-code` → `anthropics/claude-code`、`Termux` → `termux/termux-app`、`ngrok` → `ngrok/ngrok`）：**永远先 `repo:<official-repo>`**
- 用限定符拆短 query，别把每个已知词都 AND 一起（GitHub 搜索空格默认为 AND，词一多就 0 结果）：
  - `repo:anthropics/claude-code is:issue in:title hang`
  - `repo:anthropics/claude-code is:issue "Termux" hang`
  - `repo:anthropics/claude-code is:issue in:title (hang OR freeze)`
- 生成 **2~4 条不同目的**的短 query，每条测不同假设
- 官方 repo Top5 无果 → `org:<owner>` → 再全 GitHub 搜 → 最后才 `site:github.com` 补洞
- **正文一律走 GitHub API + token 抓全文**（拿到 URL/编号即可），不走网页抓取——网页对爬虫返回反爬提示

## 结果相关性闸门（搜到 ≠ 能答）

每条结果打分，低于阈值**直接扔掉**（防"撞到几个词就以为找到答案"）：

Product 0-2 / Version 0-2 / Symptom 0-3 / Environment 0-2 / Recency 0-1 = /10

- 结果 A：SessionEnd freeze issue（Product2 Version0 Symptom3 Env0 Recency1=6）→ 值得 fetch
- 结果 B：How to exit Termux（Product0 Version0 Symptom1 Env2=3）→ 直接扔

## 脚本用法（search 负责搜 + 评分过滤，不负责理解）

脚本在本 skill 的 `scripts/` 目录。用 `%VENV_PY%` 指你的 Python 解释器，用 `%CC_WEB_MCP_SRC%` 指 CC-Web-MCP 源码目录（见 README）：

```bash
$VENV_PY $SKILL_DIR/scripts/research.py "query"                          # 单条 auto 路由，6s 内出 Top5
$VENV_PY $SKILL_DIR/scripts/research.py --queries "q1|q2|q3"             # 多条并行，最终合并
$VENV_PY $SKILL_DIR/scripts/research.py "query" --mode=web|tech|github|foreign
$VENV_PY $SKILL_DIR/scripts/research.py "query" --fetch                  # 对 Top1-2 抓正文(约+8s)
$VENV_PY $SKILL_DIR/scripts/research.py "query" --timeout=6              # 每后端硬超时(默认6s)
```

> fast-track：并行发 github/web/foreign + 每后端硬超时 + early-stop（github 命中高置信即收）。
> GitHub API 走 token 拿全文；非 GitHub 站点抓取可能遇反爬，属预期。

## 由 agent 执行的完整流程

用户问题 → 提取字段(Product/Version/Env/Component/Symptom/Error) →
  ├─ 技术/专业问题 → GitHub 优先：识别官方 repo → 生成 2~4 条 repo-scoped 短 query → research.py 搜 → 相关性重排+去重 → 结果差→升级再搜/补 site:github → 拿 URL 走 API+token 抓全文 → Research Brief
  └─ 非技术 → 通用 web：Query Planner 生成 2~4 条短 query → research.py → 相关性闸门过滤 → 只 fetch Top 1–3 → Research Brief

## 安装与依赖

见 `README.md`。需要：Python 3.10+、`CC-Web-MCP` 搜索后端、可选 GitHub token（`GH_TOKEN`，用于技术问题拿 issue 全文）。

---
作者：xvxv-stack7（在 Termux / Android 上实测并开源，欢迎反馈）。
