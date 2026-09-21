#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 环境诊断 v2
# 退出码: 0=健康 1=警告 2=致命
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

PASS=0; WARN=0; FAIL=0
pass() { echo -e "  [✓] $1"; PASS=$((PASS + 1)); }
warn() { echo -e "  [!] $1  ($2)"; WARN=$((WARN + 1)); }
fail() { echo -e "  [✗] $1  ($2)"; FAIL=$((FAIL + 1)); }
info() { echo -e "       $1"; }

echo ""
echo "=========================================="
echo "  android-claude-agent 环境诊断"
echo "=========================================="

# --- 系统 ---
echo ""
echo "--- 系统 ---"
BRAND=$(getprop ro.product.brand 2>/dev/null || echo ?)
echo "  品牌: $BRAND"
echo "  型号: $(getprop ro.product.model 2>/dev/null || echo ?)"
echo "  Android: $(getprop ro.build.version.release 2>/dev/null || echo ?)"
echo "  CPU: $(uname -m)"

# --- ADB ---
echo ""
echo "--- ADB ---"

command -v adb &>/dev/null && pass "adb" || fail "adb 未安装" "E101"

if adb devices 2>/dev/null | grep -q "127.0.0.1:5555.*device"; then
    pass "5555 已连接"
elif adb devices 2>/dev/null | grep -qv "List" | grep -q "device"; then
    warn "adb 已连接但非 5555" "E102"
else
    fail "adb 未连接" "E102"
fi

adb -s 127.0.0.1:5555 shell whoami &>/dev/null 2>&1 && pass "adb shell" || fail "adb shell 不可用" "E103"

# --- Shizuku ---
echo ""
echo "--- Shizuku ---"

command -v rish &>/dev/null && pass "rish" || fail "rish 未安装" "E104"
rish -c 'whoami' &>/dev/null 2>&1 && pass "rish 可用" || warn "rish 未启动，可通过 adb 使用" "E105"

# --- Termux 插件 ---
echo ""
echo "--- Termux 插件 ---"

pkg list-installed 2>/dev/null | grep -q "termux-api" && pass "termux-api" || fail "termux-api 未安装" "E106"
timeout 2 termux-sensor -l 2>/dev/null | grep -q "Accelerometer" && pass "sensor" || warn "sensor 不可用" "E107"
[ -d ~/.termux/boot ] && pass "Boot 目录" || warn "Boot 未配置" ""

# --- 权限 ---
echo ""
echo "--- 权限 ---"

termux-notification --id 99999 --title "." --content "." 2>/dev/null && {
    pass "通知"
    termux-notification-remove 99999 2>/dev/null
} || fail "通知权限" "E108"

[ -d /sdcard ] && touch /sdcard/.doctor-test 2>/dev/null && {
    pass "存储"
    rm -f /sdcard/.doctor-test
} || warn "存储权限" "E109"

# --- 网络 ---
echo ""
echo "--- 网络 ---"

curl -sI --connect-timeout 5 https://registry.npmmirror.com >/dev/null 2>&1 && pass "网络" || fail "网络不通" "E110"
curl -sI --connect-timeout 5 https://api.deepseek.com 2>/dev/null | grep -qE "200|401|404" && pass "DNS" || fail "DNS 不通" "E110"

# --- 后台 ---
echo ""
echo "--- 后台 ---"

termux-wake-lock 2>/dev/null && { pass "Wake Lock"; termux-wake-unlock 2>/dev/null; } || fail "Wake Lock" "E111"

# --- 品牌 ---
echo ""
echo "--- 品牌提醒 ---"
case "$(echo "$BRAND" | tr '[:upper:]' '[:lower:]')" in
    xiaomi|redmi)   info "小米: USB调试 + USB调试（安全设置）" ;;
    vivo)           info "vivo: 高耗电允许 + 自启动" ;;
    oppo|oneplus|realme) info "OPPO: localhost 非 127.0.0.1" ;;
    huawei|honor)   info "华为/荣耀: tcpip 可能被禁" ;;
    samsung|google|pixel) pass "兼容良好" ;;
esac

# --- 结果 ---
echo ""
echo "=========================================="
echo "  通过: $PASS   警告: $WARN   错误: $FAIL"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "  需修复:"
    [ "$FAIL" -gt 0 ] && echo "    [✗] $FAIL 个致命错误"
    [ "$WARN" -gt 0 ] && echo "    [!] $WARN 个警告"
    exit 2
elif [ "$WARN" -gt 0 ]; then
    echo ""
    echo "  建议修复 [!] 项"
    exit 1
else
    echo ""
    echo "  状态: 健康 ✓"
    exit 0
fi
