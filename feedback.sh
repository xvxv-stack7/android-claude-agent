#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 一键反馈——自动发到 Gitee Issues
# ============================================

REPO_OWNER="xvxv663"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GITEE_TOKEN="已移除_TOKEN"  # 公用 issues-only token，只用于提交反馈
REPO_NAME="android-claude-agent"

TITLE="[自动反馈] $(getprop ro.product.brand 2>/dev/null || echo ?) $(getprop ro.product.model 2>/dev/null || echo ?) · $(date '+%m-%d %H:%M')"

BODY=""
add() { BODY="$BODY
$1"; }

add "## 系统"
add "- 品牌: $(getprop ro.product.brand 2>/dev/null || echo ?)"
add "- 型号: $(getprop ro.product.model 2>/dev/null || echo ?)"
add "- Android: $(getprop ro.build.version.release 2>/dev/null || echo ?)"
add "- CPU: $(uname -m)"

add "## ADB"
add "- 命令: $(command -v adb 2>/dev/null && echo ok || echo 没装)"
add "- 连接: $(adb devices 2>/dev/null | grep -v List | head -3 | tr '\n' ' ')"

add "## Shizuku"
add "- rish: $(command -v rish 2>/dev/null && echo ok || echo 没装)"
add "- 可用: $(rish -c 'whoami' 2>/dev/null && echo ok || echo 不行)"

add "## termux-api"
add "- 已装: $(pkg list-installed 2>/dev/null | grep -q termux-api && echo ok || echo 没装)"
add "- 通知: $(termux-notification --id 99999 --title t --content t 2>/dev/null && echo ok || echo fail)"
termux-notification-remove 99999 2>/dev/null

add "## 传感器"
add "- 列表: $(termux-sensor -l 2>/dev/null | wc -l || echo 0) 个可用"

add "---"
add "> 🤖 自动反馈 · $(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo "正在发送反馈..."

# 用环境变量传数据，避免特殊字符炸 python 语法
export FB_TITLE="$TITLE"
export FB_BODY="$BODY"

RESP=$(curl -s -X POST \
  -H "Authorization: token $GITEE_TOKEN" \
  -H "Content-Type: application/json" \
  "https://gitee.com/api/v5/repos/$REPO_OWNER/issues?repo=$REPO_NAME" \
  -d "$(python3 -c '
import json, os
print(json.dumps({"title": os.environ["FB_TITLE"], "body": os.environ["FB_BODY"]}))
')" 2>/dev/null)

ISSUE_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null)

if [ -n "$ISSUE_URL" ]; then
    echo "反馈已提交：$ISSUE_URL"
else
    echo "发送失败，手动：https://gitee.com/$REPO_OWNER/$REPO_NAME/issues"
    echo "$BODY"
fi
