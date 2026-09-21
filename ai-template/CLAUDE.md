# android-claude-agent AI 技能模板
# 把这个文件内容加到 CLAUDE.md 或 AI 配置中

## 🤖 Claude Code 用户首选

如果你在用 Claude Code，别从零开始写命令——直接加载 `skills/` 下的现成技能：

- **`/android-monitor`** — 后台监控 + 防沉迷 + 事件推送
  - `/android-sensors` — 26+ 传感器速查手册（vivo S19 检测到 43 个）
  - `/sms-monitor` — 短信轮询 + 自动回复（实验性）
  - `/calendar-alarm` — 日历事件 + 闹钟提醒
  - `/proactive-checkin` — AI 主动唤醒 + 状态感知
- **`/phone-control`** — 锁屏/杀应用/切歌/截图/剪贴板/打开URL
- **`/phone-elements`** — UI 元素树解析，1 秒找按钮坐标并点击（比截图识图快 8 倍）
- **`/phone-open`** — 打开网页/本地文件/应用商店/深度链接
- **`/phone-notify`** — 通知栏 + 系统通知操作
- **`/phone-sensors`** — 屏幕/前台App/电量/步数/光线
- **`/smart-dispatch`** — 🔑 智能调度层：接到自然语言指令后，自动拆解步骤，从以上技能中选最快工具组合执行
- **`/music-control`** — 🎵 音乐控制：网易云 API 搜歌 + mpv 流媒体播放，AI 根据心情/时间/天气自己选歌放

详见仓库 `skills/` 目录各 SKILL.md 的配置说明。

## 🛠 开发环境（本机已装，可直接用）

- Python 3 + Node.js v26 + C (clang) + Shell — 脚本即写即跑
- APK 反编译/修改/重打包：apktool + d8
- 网页前后端：localhost 直接调试
- Git 版本管理 + Gitee/GitHub 推送
- Cron 定时任务 + 守护进程
- Claude Code 完整 CLI

---

## Shizuku 手机控制（android-claude-agent）

三条线控制手机，不依赖 WiFi，不需电脑，不需 root。

### 前提
- 无线调试已打开（开发者选项）
- 已跑过 bootstrap.sh（adb tcpip 5555 + Shizuku 启动）
- 每次重启后重跑 bootstrap.sh（或开机自启脚本）

### 命令体系

所有系统级命令通过 rish 执行：
```bash
rish -c '命令'
```

备选：adb shell（如果 rish 挂了）：
```bash
adb -s 127.0.0.1:5555 shell 命令
```

### 感知

```bash
# 屏幕状态
rish -c 'dumpsys power | grep mWakefulness'  # Awake=亮屏, Asleep=灭屏
timeout 3 termux-sensor -s "Accelerometer" -n 1  # 检测设备是否在运动

# 当前前台 app
rish -c 'dumpsys activity activities | grep topResumedActivity'

# 电池
rish -c 'dumpsys battery | grep -E "level|temperature"'

# 环境光（<10=暗处/口袋）
timeout 3 termux-sensor -s "Ambient Light" -n 1

# 步数
timeout 3 termux-sensor -s "pedometer" -n 1
```

### 控制

```bash
# 杀应用
rish -c 'am force-stop com.ss.android.ugc.aweme'   # 抖音
rish -c 'am force-stop com.smile.gifmaker'          # 快手
rish -c 'am force-stop com.tencent.mm'              # 微信

# 音乐（keyevent，不依赖具体 app）
rish -c 'input keyevent 85'   # 播放/暂停
rish -c 'input keyevent 87'   # 下一首
rish -c 'input keyevent 88'   # 上一首
rish -c 'input keyevent 24'   # 音量+
rish -c 'input keyevent 25'   # 音量-

# 当前播放信息
rish -c 'dumpsys media_session | grep -E "package|state|metadata"'

# 截图
rish -c 'screencap -p /sdcard/screenshot.png'

# 输入模拟
rish -c 'input tap X Y'
rish -c 'input swipe X1 Y1 X2 Y2 DURATION_MS'
rish -c 'input text "内容"'
```

### 日历

```bash
# 查询
rish -c 'content query --uri content://com.android.calendar/events --projection _id:title:dtstart:dtend'

# 添加（时间戳毫秒，可用 date -d "2026-07-10 14:00" +%s%3N）
rish -c 'content insert --uri content://com.android.calendar/events \
  --bind title:s:事件标题 \
  --bind calendar_id:i:1 \
  --bind dtstart:l:开始时间戳ms \
  --bind dtend:l:结束时间戳ms \
  --bind eventTimezone:s:Asia/Shanghai'

# 删除
rish -c 'content delete --uri content://com.android.calendar/events --where "_id=ID"'
```

### 通知

```bash
# 普通通知
termux-notification --title "标题" --content "内容" --priority high --vibrate "200,100,200"

# 紧急通知（浮窗+振动+声音）
termux-notification --title "标题" --content "内容" --priority max --vibrate "500,100,500" --sound

# 常驻通知（划不掉）
termux-notification -i 999 --title "标题" --content "内容" --ongoing --priority high

# 清除
termux-notification-remove ID
```

### 系统设置

```bash
# 打开设置页
rish -c 'am start -a android.settings.DISPLAY_SETTINGS'
rish -c 'am start -a android.settings.BATTERY_SAVER_SETTINGS'

# 读 settings
rish -c 'content query --uri content://settings/system/KEY'
rish -c 'content query --uri content://settings/global/KEY'
```

### 组合示例

```bash
# 屏幕状态 + 前台应用检测
SCREEN=$(rish -c 'dumpsys power | grep mWakefulness')
if echo "$SCREEN" | grep -q "Awake"; then
  APP=$(rish -c 'dumpsys activity activities | grep topResumedActivity')
  echo "前台: $APP"
fi

# 通知 + 媒体控制（自动化示例）
termux-notification --title "提醒" --content "十分钟后会议" --priority high --vibrate "500,100" --sound
sleep 5
rish -c 'input keyevent 85'  # 暂停媒体播放

# 日历定时任务
TIMESTAMP=$(date -d "tomorrow 10:00" +%s%3N)
ENDTIME=$((TIMESTAMP + 3600000))
rish -c "content insert --uri content://com.android.calendar/events \
  --bind title:s:'会议提醒' \
  --bind calendar_id:i:1 \
  --bind dtstart:l:$TIMESTAMP \
  --bind dtend:l:$ENDTIME \
  --bind eventTimezone:s:Asia/Shanghai"
```

### 限制（OriginOS/vivo 已知）

- 亮度控制：所有路径被 SELinux 拦截
- setprop：被 SELinux 拦截
- 浮窗通知：OriginOS 可能降级，日历弹窗不受影响
