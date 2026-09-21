#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 自动反馈——脚本出错时自动提交 Gitee Issue
# 用法：在主脚本里 source 这个文件，trap 自动生效
#
# v2: 本地缓存补发 + 退出码解释 + 关键字匹配 + doctor 诊断
# 适配 android-claude-agent 的 adb/Shizuku/sensor 错误场景
# ============================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
FAILED_DIR="$HOME/.cc-connect/failed_feedback"

# 自动检测平台：Gitee / GitHub，使用对应的 token 和接口
AUTO_FB_REPO_NAME=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || echo "android-claude-agent")
_detect_platform() {
    local remote=$(git remote get-url origin 2>/dev/null || git remote get-url gitee 2>/dev/null || echo "")
    local owner token api_base issues_url
    if echo "$remote" | grep -q "gitee"; then
        owner="xvxv663"
        token="${AUTO_FB_GITEE_TOKEN:-未设置}"
        issues_url="https://gitee.com/api/v5/repos/${owner}/issues?repo=${AUTO_FB_REPO_NAME}"
        web_url="https://gitee.com/${owner}/${AUTO_FB_REPO_NAME}/issues"
    elif echo "$remote" | grep -q "github"; then
        owner="xvxv-stack7"
        token="${AUTO_FB_GITHUB_TOKEN:-未设置}"
        issues_url="https://api.github.com/repos/${owner}/${AUTO_FB_REPO_NAME}/issues"
        web_url="https://github.com/${owner}/${AUTO_FB_REPO_NAME}/issues"
    else
        echo "unknown||||"
        return
    fi
    echo "${owner}|${token}|${issues_url}|${web_url}"
}
PLATFORM_INFO=$(_detect_platform)
AUTO_FB_OWNER=$(echo "$PLATFORM_INFO" | cut -d'|' -f1)
AUTO_FB_TOKEN=$(echo "$PLATFORM_INFO" | cut -d'|' -f2)
AUTO_FB_ISSUES_URL=$(echo "$PLATFORM_INFO" | cut -d'|' -f3)
AUTO_FB_WEB_URL=$(echo "$PLATFORM_INFO" | cut -d'|' -f4)


# ============================================
# 补发上次失败的反馈
# ============================================
retry_failed() {
    [ -d "$FAILED_DIR" ] || return 0
    local sent=0
    for f in "$FAILED_DIR"/*.json; do
        [ -f "$f" ] || continue
        local RESP
        RESP=$(curl -s -X POST \
          -H "Authorization: token ${AUTO_FB_TOKEN}" \
          -H "Content-Type: application/json; charset=utf-8" \
          "${AUTO_FB_ISSUES_URL}" \
          -d "@$f" 2>/dev/null)
        local ISSUE_URL
        ISSUE_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null)
        if [ -n "$ISSUE_URL" ]; then
            echo "[补发] 之前的反馈已提交: $ISSUE_URL"
            rm -f "$f"
            sent=$((sent + 1))
        else
            break
        fi
    done
    [ "$sent" -gt 0 ] && rmdir "$FAILED_DIR" 2>/dev/null
    return 0
}

# ============================================
# 关键字匹配——android-claude-agent 特有错误
# ============================================
match_output() {
    local cmd="$1"
    local extra="${2:-}"
    local haystack="${cmd}${extra}"
    local matched=0

    echo ""
    echo "## 关键字匹配"
    echo ""

    # ADB 相关
    if echo "$haystack" | grep -qiE "adb.*not found|no devices|unauthorized|offline"; then
        echo "- **ADB 未连接**：设备离线或未授权"
        echo "  - \`adb devices\` 看设备状态"
        echo "  - 授权：手机上点「允许 USB 调试」"
        echo "  - 重连：\`adb connect 127.0.0.1:5555\`"
        matched=1
    fi

    if echo "$haystack" | grep -qiE "device.*offline|device not found|more than one device"; then
        echo "- **ADB 设备状态异常**"
        echo "  - \`adb kill-server && adb start-server\` 重启 adb"
        echo "  - 重跑 bootstrap.sh"
        matched=1
    fi

    # Shizuku 相关
    if echo "$haystack" | grep -qiE "rish.*not found|Shizuku.*not running|Server is not running"; then
        echo "- **Shizuku 未启动**"
        echo "  - 打开 Shizuku App → 通过 ADB 启动"
        echo "  - 或重新运行 bootstrap.sh"
        matched=1
    fi

    # dumpsys 相关
    if echo "$haystack" | grep -qiE "dumpsys.*not found|dumpsys.*Permission|dumpsys.*denied"; then
        echo "- **dumpsys 权限不足或命令不存在**"
        echo "  - ADB shell 权限应该够。如果不够，试试通过 rish -c 执行"
        matched=1
    fi

    # termux-api 相关
    if echo "$haystack" | grep -qiE "termux-notification.*not found|termux-sms-list.*not found|termux-api"; then
        echo "- **termux-api 未安装**"
        echo "  - \`pkg install termux-api -y\`"
        echo "  - 还需要装 F-Droid 上的 Termux:API 应用"
        matched=1
    fi

    # 传感器
    if echo "$haystack" | grep -qiE "termux-sensor.*error|cannot open sensor"; then
        echo "- **传感器访问失败**"
        echo "  - 部分传感器需要前台权限或特定 Android 版本"
        echo "  - 用 \`termux-sensor -l\` 列出可用的传感器"
        matched=1
    fi

    # 文件/权限
    if echo "$haystack" | grep -qiE "Permission denied|EACCES|Read-only"; then
        echo "- **权限不够或文件系统只读**"
        echo "  - 检查路径是否在 Termux 内部"
        echo "  - \`chmod +x 文件\` 加执行权限"
        matched=1
    fi

    if echo "$haystack" | grep -qiE "No such file|not found|ENOENT"; then
        echo "- **文件或命令不存在**"
        echo "  - 确认脚本文件已部署到正确路径"
        echo "  - 检查依赖是否已安装：\`bash doctor.sh\`"
        matched=1
    fi

    # 网络
    if echo "$haystack" | grep -qiE "Could not resolve|timed out|ECONNREFUSED|ETIMEDOUT|ENOTFOUND"; then
        echo "- **网络连接问题**"
        echo "  - \`curl -I https://gitee.com\` 测试连通性"
        echo "  - 检查代理：\`echo \$http_proxy\`"
        matched=1
    fi

    # 空间
    if echo "$haystack" | grep -qiE "No space left|disk quota|ENOSPC"; then
        echo "- **磁盘空间不足**"
        echo "  - \`df -h ~\` 看剩余空间"
        matched=1
    fi

    if [ "$matched" -eq 0 ]; then
        echo "（未匹配到已知关键字）"
    fi
}

# ============================================
# 退出码分析——android-claude-agent 场景
# ============================================
explain_error() {
    local code="$1"
    local cmd="$2"
    local extra="${3:-}"

    echo ""
    echo "## 退出码分析"
    echo ""

    case "$code" in
        0)
            echo "**退出码 0**：命令正常结束，但 trap 被触发（子 shell 或管道中的错误）。看上面具体报错。"
            ;;
        1)
            if echo "$cmd" | grep -q "doctor.sh"; then
                echo "**预检警告**：doctor.sh 发现缺少组件，这是安装前的正常状态。继续运行安装脚本即可。"
            elif echo "$cmd" | grep -q "adb"; then
                echo "**ADB 命令失败**：设备未连接或命令执行出错。"
                echo "- \`adb devices\` 确认设备在线"
                echo "- 如果显示 offline，重连：\`adb connect 127.0.0.1:5555\`"
            else
                echo "**命令执行失败（退出码 1）**：网络不通、依赖缺失、或权限不足。"
                echo "- 运行 \`bash doctor.sh\` 检查环境"
            fi
            ;;
        126)
            echo "**命令不可执行（退出码 126）**：脚本权限不对或二进制架构不匹配。"
            echo "- \`chmod +x 脚本文件\` 加执行权限"
            echo "- \`uname -m\` 确认是 aarch64/armv8l"
            ;;
        127)
            echo "**命令未找到（退出码 127）**：依赖未安装。"
            echo "- ADB: \`pkg install android-tools -y\`"
            echo "- 其他：\`bash doctor.sh\` 诊断缺失项"
            ;;
        130)
            echo "**被 Ctrl+C 中断（退出码 130）**：不是错误，手动取消。"
            ;;
        137)
            echo "**被系统 kill（SIGKILL，退出码 137）**：内存不足或系统回收后台进程。"
            echo "- 给 Termux 无限制后台权限"
            echo "- 关掉其他占内存的 app"
            ;;
        143)
            echo "**被 SIGTERM 终止（退出码 143）**：系统回收后台进程。"
            echo "- 锁屏后给 Termux 保持后台运行的权限"
            ;;
        *)
            echo "**退出码 ${code}**：命令异常退出。手动运行上面命令看具体报错。"
            ;;
    esac

    match_output "$cmd" "$extra"
}

# ============================================
# 主函数
# ============================================
auto_feedback() {
    local exit_code=$?
    local line_no="$1"
    local command="$2"

    trap '' ERR

    echo ""
    echo "=============================================="
    echo "  😿 脚本出错了，正在自动收集信息..."
    echo "=============================================="

    local TITLE="[自动反馈] $(getprop ro.product.brand 2>/dev/null || echo ?) $(getprop ro.product.model 2>/dev/null || echo ?) · $(date '+%m-%d %H:%M') · 错误码${exit_code}"

    # 跑 doctor 诊断
    local DIAG_OUTPUT=""
    if [ -x "$SCRIPT_DIR/doctor.sh" ]; then
        echo "  -> 正在跑环境诊断..."
        DIAG_OUTPUT=$(bash "$SCRIPT_DIR/doctor.sh" 2>&1 || true)
    fi

    local EXPLANATION
    EXPLANATION=$(explain_error "$exit_code" "$command" "${DIAG_OUTPUT}")

    local BODY
    BODY=$(cat <<BODYEOF
## 错误
- 退出码: ${exit_code}
- 行号: ${line_no}
- 命令: \`${command}\`

## 系统
- 品牌: $(getprop ro.product.brand 2>/dev/null || echo ?)
- 型号: $(getprop ro.product.model 2>/dev/null || echo ?)
- Android: $(getprop ro.build.version.release 2>/dev/null || echo ?)
- CPU: $(uname -m)

## 环境
- ADB: $(command -v adb 2>/dev/null && echo ok || echo 没装)
- rish: $(command -v rish 2>/dev/null && echo ok || echo 没装)
- 时间: $(date '+%Y-%m-%d %H:%M:%S')
${EXPLANATION}

## 环境诊断
\`\`\`
${DIAG_OUTPUT:-（doctor.sh 不可用）}
\`\`\`

---
> 🤖 自动反馈 · $(date '+%Y-%m-%d %H:%M:%S')
BODYEOF
)

    export AUTO_FB_TITLE="$TITLE"
    export AUTO_FB_BODY="$BODY"

    local JSON
    JSON=$(python3 -c '
import json, os
print(json.dumps({
    "title": os.environ["AUTO_FB_TITLE"],
    "body": os.environ["AUTO_FB_BODY"]
}))
' 2>/dev/null)

    if [ -z "$JSON" ]; then
        echo "[!] JSON 构造失败"
        _save_local "$TITLE" "$BODY"
        exit $exit_code
    fi

    local RESP
    RESP=$(curl -s -X POST \
      -H "Authorization: token ${AUTO_FB_TOKEN}" \
      -H "Content-Type: application/json; charset=utf-8" \
      "${AUTO_FB_ISSUES_URL}" \
      -d "$JSON" 2>/dev/null)

    local ISSUE_URL
    ISSUE_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null)

    echo ""
    if [ -n "$ISSUE_URL" ]; then
        echo "=============================================="
        echo "  反馈已自动提交！"
        echo "  ${ISSUE_URL}"
        echo "=============================================="
    else
        echo "[!] 自动提交失败（网络不通或平台不可达）"
        echo "手动反馈: ${AUTO_FB_WEB_URL}"
        _save_local "$TITLE" "$BODY"
    fi

    exit $exit_code
}

# ============================================
# 本地缓存
# ============================================
_save_local() {
    local title="$1"
    local body="$2"
    mkdir -p "$FAILED_DIR"
    local FILE="$FAILED_DIR/feedback_$(date +%s).json"
    export _SV_TITLE="$title"
    export _SV_BODY="$body"
    python3 -c '
import json, os
print(json.dumps({
    "title": os.environ["_SV_TITLE"],
    "body": os.environ["_SV_BODY"]
}))
' > "$FILE" 2>/dev/null
    if [ -s "$FILE" ]; then
        echo "  反馈已保存到本地: $FILE"
        echo "  下次脚本运行时会自动补发。"
    fi
}

# 启动时补发
retry_failed

# 注册 trap
trap 'auto_feedback $LINENO "$BASH_COMMAND"' ERR
