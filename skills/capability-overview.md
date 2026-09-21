# termux-shizuku 技能目录

8 个独立技能 + 4 个子技能，覆盖感知、控制、通信、自动化、开发五层。

---

## android-monitor
后台监控守护进程。gaze.sh 60s 轮询 + detect.py 单次事件检测（合并替代 12+ 次 python3 调用），双通道 Shell（Shizuku rish → ADB fallback），事件驱动 Monitor 推送 + 通知栏弹窗。

**事件类型（11 种）**
| 事件 | 触发条件 | 去重策略 |
|------|---------|---------|
| woke_up | 灭屏→亮屏，间隔 > 5min | 同事件 10min |
| started_walking | 步数 +200 | 同事件 10min |
| stopped | 步数停滞 > 45min | 同事件 10min |
| binge_app | 同一娱乐 App > 30min | 每 App 每天 1 次 |
| left_chat | 从微信/Termux 切到任意 App | 同事件 10min |
| gaming_end | 离开游戏 App | 同事件 10min |
| low_battery | 电量从 >15% 掉到 ≤15% | 同事件 10min |
| midnight_phone | 23:00-06:00 亮屏 | 每晚 1 次 |
| random_glance | 3%/loop 随机抽查 | 30min 间隔 |
| music_moment | 蓝牙 A2DP 在线 + 非媒体 App + 白天 + 2%/loop | 40min 间隔 |
| long_silence | 2.5h 无动静（屏幕灭 + 无步数变化）| 同事件 10min |

**子技能**
- **android-sensors** — 26+ 传感器速查手册（43 个在 vivo S19 上检测到）
- **sms-monitor** — 短信轮询 + 自动回复（实验性）
- **calendar-alarm** — 日历事件 + 闹钟提醒（content provider 双向操作）
- **proactive-checkin** — 轮询唤醒 AI，AI 自行决定是否出声

**防沉迷** — app_limit.sh 累计时长追踪：80% Toast 预警 → 100% am force-stop

---

## phone-control
设备操控。全双通道 rish + adb。

| 能力 | 命令 | 耗时 |
|------|------|------|
| 锁屏 / 唤醒 | input keyevent 26 / 224 | 0.3s |
| 音量调节 | input keyevent 24 / 25 | 0.3s |
| 闪光灯 | cmd flashlight on/off | 0.3s |
| 重启 | reboot | 5s |
| 强杀应用 | am force-stop <pkg> | 0.5s |
| 截图 | screencap -p /path | 1s |
| 录屏 | screenrecord /path --time-limit N | — |
| 剪贴板读写 | cmd clipboard get-text / set-text | 0.5s |
| 打开 URL | am start -d "https://..." | 2s |
| 媒体键 | input keyevent 85/87/88 | 0.3s |
| 打开相机 | am start STILL_IMAGE_CAMERA | 1s |

---

## phone-elements
UI 元素树解析。`uiautomator dump` → 解析 XML → 返回坐标。

| 能力 | 命令 | 耗时 |
|------|------|------|
| 按文本找元素 | python3 elements.py --text "确认" | 1s |
| 按 ID 找元素 | python3 elements.py --id "submit" | 1s |
| 找 + 点击一步完成 | python3 elements.py --text "确认" --tap | 1s |
| 仅 dump 原始 XML | python3 elements.py --dump-only | 0.5s |

**兼容性**：AOSP/MIUI 自动适配（topResumedActivity / mResumedActivity / mFocusedActivity）。不支持微信（自研渲染引擎，无障碍数据为空）。

---

## phone-open
打开链接/文件/应用。调用 Android intent 系统。

| 能力 | 命令 |
|------|------|
| 打开网页 | am start -d "https://example.com" |
| 打开本地文件 | am start -d "file:///sdcard/doc.pdf" -t "application/pdf" |
| 打开应用商店 | am start -d "market://details?id=<pkg>" |
| 打开应用 | monkey -p <pkg> 1 |

---

## phone-notify
通知栏与日历。

| 能力 | 命令 |
|------|------|
| 系统通知 | termux-notification --title "X" --content "Y" --priority max |
| 日历查询 | content query --uri content://com.android.calendar/events |
| 日历添加 | content insert --uri content://com.android.calendar/events --bind ... |

---

## phone-sensors
环境感知。一行命令读取硬件状态。

| 数据 | 命令 | 耗时 |
|------|------|------|
| 屏幕状态 | dumpsys power \| grep mWakefulness | 0.5s |
| 前台 App | dumpsys activity activities \| grep topResumedActivity | 0.5s |
| 电池 | dumpsys battery \| grep level | 0.5s |
| 步数 | termux-sensor -s pedometer -n 1 | 3s |
| 光线 | termux-sensor -s "Ambient Light" -n 1 | 3s |
| 加速度 | termux-sensor -s Accelerometer -n 1 | 3s |

---

## smart-dispatch
智能调度层。自然语言指令 → 拆解步骤 → 从以上技能中自动选最快路径。

**工具优先级**：content provider (0.5s) > am start (1s) > mimic (0.5s) > uiautomator (1s) > keyevent (0.3s) > clipboard (0.5s) > vision (8s)

见 `skills/smart-dispatch/SKILL.md` 完整决策树与组合模板。

---

## music-control
> ⚠️ **旧版**。音乐那套已重写并独立成仓库 → **[android-claude-music](https://gitee.com/xvxv663/android-claude-music)**（虚拟副屏 + 酷狗：不占主屏、能读歌词、主动陪听）。下面是旧方案存档。

AI 驱动音乐播放。网易云 API（NeteaseCloudMusicApiEnhanced v4.37.0, MIT）搜歌 + mpv 流媒体播放。

| 步骤 | 命令 | 耗时 |
|------|------|------|
| 搜歌 | curl localhost:3000/search?keywords=... | 1s |
| 获取播放 URL | curl localhost:3000/song/url/v1?id=... | 1s |
| 播放 | nohup mpv --no-video "$URL" & | 即时 |

AI 选曲依据：时间 / 天气 / 步数 / 最近对话中的歌手。不打断视频/音乐 App。深夜不触发。Powered by [NeteaseCloudMusicApiEnhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced).

---

## 基础设施

| 组件 | 说明 |
|------|------|
| 双通道 Shell | Shizuku rish 优先 → ADB 127.0.0.1:5555 后备，免 WiFi，重启自恢复 |
| OEM 兼容矩阵 | 6 厂商 13 命令逐条标注（vivo / 小米 / 华为 / OPPO / 三星 / Pixel） |
| 开发环境 | Python 3 + Node.js v26 + C (clang) + Shell。apktool + d8，Git + Cron |
| 许可证 | MIT — 每行可读、可改、可审计 |
