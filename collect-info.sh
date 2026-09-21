#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 诊断报告（已过滤敏感信息）
# bash collect-info.sh | 全选复制 → 发 issue
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

echo "========== 系统 =========="
echo "Brand=$(getprop ro.product.brand 2>/dev/null || echo ?)"
echo "Model=$(getprop ro.product.model 2>/dev/null || echo ?)"
echo "Android=$(getprop ro.build.version.release 2>/dev/null || echo ?)"
echo "SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo ?)"
echo "CPU=$(uname -m)"

echo ""
echo "========== Termux =========="
echo "Version=$TERMUX_VERSION"

echo ""
echo "========== ADB =========="
echo "Command=$(command -v adb 2>/dev/null && echo ok || echo missing)"
adb devices 2>/dev/null | grep -v "List" | while read line; do
    echo "Device=$line"
done
echo "Shell=$(adb shell whoami 2>/dev/null && echo ok || echo fail)"

echo ""
echo "========== Shizuku =========="
echo "Rish=$(command -v rish 2>/dev/null && echo ok || echo missing)"
echo "Shell=$(rish -c 'whoami' 2>/dev/null && echo ok || echo fail)"
echo "APK=$( [ -f "/storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh" ] && echo installed || echo not_found)"

echo ""
echo "========== Termux 插件 =========="
echo "API=$(pkg list-installed 2>/dev/null | grep -q "termux-api" && echo installed || echo missing)"
echo "Sensor=$(timeout 2 termux-sensor -l 2>/dev/null >/dev/null && echo ok || echo fail)"
echo "Boot=$( [ -d ~/.termux/boot ] && echo configured || echo no)"

echo ""
echo "========== 权限 =========="
echo "Notification=$(termux-notification --id 99999 --title "." --content "." 2>/dev/null && echo ok || echo fail)"
termux-notification-remove 99999 2>/dev/null
echo "Storage=$( [ -d /sdcard ] && echo ok || echo fail)"

echo ""
echo "========== 网络 =========="
echo "Network=$(ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && echo ok || echo fail)"
echo "DNS=$(ping -c 1 -W 3 registry.npmmirror.com >/dev/null 2>&1 && echo ok || echo fail)"

echo ""
echo "========== 后台 =========="
echo "WakeLock=$(termux-wake-lock 2>/dev/null && echo ok || echo fail)"
termux-wake-unlock 2>/dev/null

echo ""
echo "========== 技能 =========="
echo "Skills=$( [ -f ~/skills.sh ] && wc -l < ~/skills.sh || echo 0)"
echo "ADBSkills=$( [ -f ~/adb-skills.sh ] && wc -l < ~/adb-skills.sh || echo 0)"

echo ""
echo "========== 仓库 =========="
echo "Commit=$(cd "$SCRIPT_DIR" && git log --oneline -1 2>/dev/null || echo not_git)"

echo ""
echo "--- 以上全选复制 → 发 issue ---"
echo "https://gitee.com/xvxv663/android-claude-agent/issues"
