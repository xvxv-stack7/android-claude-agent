#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# android-claude-agent 集中配置
# ============================================

# --- ADB ---
ADB_PORT="5555"
ADB_HOST="127.0.0.1"
ADB_CMD="adb -s $ADB_HOST:$ADB_PORT"

# --- Shizuku ---
SHIZUKU_START="/storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh"

# --- 路径 ---
HOME_DIR="$HOME"
TERMUX_PREFIX="$PREFIX"

# --- 错误码 ---
# E101: adb 未安装
# E102: adb 未连接
# E103: adb shell 不可用
# E104: rish 未安装
# E105: rish 不可用
# E106: termux-api 未安装
# E107: termux-sensor 不可用
# E108: 通知权限未授权
# E109: 存储权限未授权
# E110: 网络不通
# E111: Wake Lock 不可用
