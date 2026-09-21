#!/data/data/com.termux/files/usr/bin/bash
# android-claude-agent / 一键启动脚本
# 免 WiFi 免电脑，USB 调试做锚，adb tcpip 5555 做桥
# 2026-07-09 在 vivo S19 (OriginOS/Android 16) 实测通过

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 自动反馈：出错时自动提交 Gitee Issue
source "$SCRIPT_DIR/auto-feedback.sh" 2>/dev/null || {
    source <(curl -sL "https://gitee.com/xvxv663/android-claude-agent/raw/master/auto-feedback.sh") 2>/dev/null || true
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

# 先诊断
if [ -f "$SCRIPT_DIR/doctor.sh" ]; then
    set +e  # 临时关闭 errexit，doctor.sh 返回1（有警告）不应中断
    trap '' ERR  # ERR trap 不受 set +e 影响，必须单独禁掉
    bash "$SCRIPT_DIR/doctor.sh"
    DOCTOR_EXIT=$?
    trap 'auto_feedback $LINENO "$BASH_COMMAND"' ERR  # 恢复自动反馈
    set -e
    if [ "$DOCTOR_EXIT" -eq 2 ]; then
        echo "[!] 环境有致命问题，请先修复再继续"
        echo "    重跑 bash doctor.sh 查看详情"
        exit 1
    fi
    # 退出码 0=完美 1=有警告但可继续——都往下走
fi

echo ""
echo "=========================================="
echo "  android-claude-agent / 一键启动"
echo "  USB 调试 + adb TCP 5555 方案"
echo "=========================================="
echo ""

# --- 检查依赖 ---
if ! command -v adb &>/dev/null; then
    warn "adb 未安装，正在安装 android-tools..."
    pkg install -y android-tools
    log "android-tools 安装完成"
fi

# --- 检查 USB 调试 ---
echo ""
echo "=== 第一步：确认 USB 调试 ==="
echo "请确认：设置 → 开发者选项 → USB 调试 → 已打开"
echo "如果还没开，现在去开。开了按回车继续..."
read -r

# --- 等 adbd 就绪 ---
echo ""
echo "=== 第二步：探测 adbd ==="
for i in $(seq 1 15); do
    if adb shell whoami &>/dev/null 2>&1; then
        log "adbd 已就绪 (尝试 $i 次)"
        break
    fi
    if [ "$i" -eq 15 ]; then
        warn "adbd 探测超时。请确认 USB 调试已打开，然后重试。"
        warn "如果无线调试开着，也可以手动连："
        warn "  adb connect 127.0.0.1:<无线调试端口>"
        warn "然后重新跑本脚本。"
        exit 1
    fi
    sleep 2
done

# --- 检查当前连接状态 ---
CURRENT_MODE=$(adb devices 2>/dev/null | grep -v "List" | head -1 | awk '{print $2}')
DEVICE_SERIAL=$(adb devices 2>/dev/null | grep -v "List" | grep -v "^$" | head -1 | awk '{print $1}')

log "当前连接: $DEVICE_SERIAL ($CURRENT_MODE)"

# 如果已经连了 5555，跳过 tcpip
if echo "$DEVICE_SERIAL" | grep -q "5555"; then
    log "已经连在 5555 端口，跳过 tcpip"
else
    # --- 开 TCP 5555 ---
    echo ""
    echo "=== 第三步：切 adbd 到 TCP 模式 ==="
    if adb tcpip 5555 2>&1 | grep -q "restarting"; then
        log "adbd 已切到 TCP 5555 模式"
        sleep 2
    else
        err "tcpip 失败，请检查 USB 调试状态"
        exit 1
    fi

    # --- 连 127.0.0.1:5555 ---
    echo ""
    echo "=== 第四步：连接 127.0.0.1:5555 ==="
    adb connect 127.0.0.1:5555 2>&1
    sleep 1

    if adb -s 127.0.0.1:5555 shell whoami &>/dev/null 2>&1; then
        log "127.0.0.1:5555 连接成功"
    else
        err "5555 连接失败"
        exit 1
    fi
fi

# --- 启动 Shizuku ---
echo ""
echo "=== 第五步：启动 Shizuku ==="
SHIZUKU_START="/storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh"

if [ -f "$SHIZUKU_START" ]; then
    adb -s 127.0.0.1:5555 shell sh "$SHIZUKU_START" 2>&1
    sleep 5
else
    warn "Shizuku start.sh 未找到，请确认 Shizuku 已安装"
    warn "下载: https://shizuku.rikka.app/"
    warn "跳过 Shizuku 启动..."
fi

# --- 验证 ---
echo ""
echo "=== 验证 ==="
if adb -s 127.0.0.1:5555 shell whoami &>/dev/null 2>&1; then
    log "adb 5555 ✓"
else
    err "adb 5555 ✗"
fi

if command -v rish &>/dev/null && rish -c 'whoami' &>/dev/null 2>&1; then
    log "rish (Shizuku) ✓"
elif [ -f "$SHIZUKU_START" ]; then
    warn "rish 未就绪，Shizuku 可能需要手动启动"
    warn "打开 Shizuku app → 通过 ADB 启动"
else
    warn "Shizuku 未安装，跳过 rish 检查"
fi

echo ""
echo "=========================================="
echo "  启动完成！"
echo ""
echo "  现在可以关 WiFi、关热点了。"
echo "  USB 调试是锚，TCP 5555 是桥。"
echo "  手机重启后重新跑本脚本即可。"
echo ""
echo "  开机自启？看 boot/startup.sh"
echo "=========================================="
