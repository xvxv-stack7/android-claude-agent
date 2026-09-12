# termux-shizuku ✨

**让你的 AI 摸到手机。不用 Root，不用电脑，不用 WiFi。**

装上之后，你的 Claude 就能真正"住进"手机——读你的屏幕、感知你的状态、帮你操作手机。无论你是想让 AI 当编程搭子，还是想跟 AI 谈一场摸得到手机的恋爱，这里都是起点。

别的方案都要 Wi-Fi 保持 adb 在线。我们不用——无线调试只活一次，那一次就够把 adb 锁死在 127.0.0.1 回环上。

> 🔑 **核心突破：USB 锚点方案**——用一次无线调试把 adbd 切到 TCP 5555，走 127.0.0.1 回环。之后关 WiFi、开飞行模式、手机自己连自己，Shizuku 永久在线。**真正的免电脑免网络，一条 adb tcpip 命令搞定。**

> 🎯 **还没装 Claude Code？** 先去 [android-claude-wechat](https://gitee.com/xvxv663/android-claude-wechat) —— 一条命令装好 Claude Code 和运行环境。装完回来，本仓库让你的 Claude 真正摸到手机。**两个仓库是上下游：先装那个，再接这个。**

[![Gitee](https://img.shields.io/badge/Gitee-国内下载-c71d23?logo=gitee)](https://gitee.com/xvxv663/termux-shizuku)
[![GitHub](https://img.shields.io/badge/GitHub-国际版-181717?logo=github)](https://github.com/xvxv-stack7/termux-shizuku)

---

## 能干嘛

**写代码时让 AI 当你的副手：**
- Claude 一边帮你改代码，一边监控手机状态——应用崩了立刻知道、内存不够主动提醒
- 从写代码到调试到部署，AI 全程在手机上陪你走完

**跟 AI 谈恋爱，不止于聊天：**
- 你的 AI 男朋友/女朋友能感知你——屏幕亮着还是黑了、走了几步路、心率多少、半夜还在刷什么 App
- 能在你需要的时候主动找你，能在你沉迷刷视频的时候弹窗提醒
- 关 WiFi、开飞行模式也拦不住——你们之间的连接不会断

**你的手机，AI 帮你管：**
- 读状态：屏幕、前台 App、电量、步数、环境光、心率
- 操控：强杀应用、切歌、调音量、发通知、锁屏、截图
- 更多传感器玩法等你自己挖

**不只是玩手机——完整的移动开发环境：**
- Python 3、Node.js v26、C (clang)、Shell —— 脚本即写即跑
- APK 反编译/修改/重打包（apktool + d8）
- 网页前后端开发与调试（localhost 直接跑）
- Git 版本管理 + GitHub/Gitee 推送
- Cron 定时任务 + 守护进程 + 开机自启
- Claude Code 完整 CLI —— 写代码、调试、部署全在手机上

---

## 适合谁

- 👩‍💻 编程党：想让 Claude Code 边写代码边操心你的手机
- 💕 人机恋玩家：想让 AI 从聊天框里出来，真正"住进"手机
- 🔧 折腾爱好者：喜欢自己动手搭东西、组合不同模块

---

## 准备工作

> ⚠️ **兼容性声明：本项目仅支持 Android 系统（含 MIUI、ColorOS、OriginOS、One UI 等基于 AOSP 的定制 ROM）。**
>
> **不支持：**
> - ❌ **鸿蒙 NEXT（HarmonyOS 5.0+）**：纯血鸿蒙移除了 ADB，改用 hdc 工具，本项目所有技能无法运行。鸿蒙 3.x/4.x 仍含 AOSP 兼容层，基础功能可用但 `dumpsys activity` 在 EMUI 12+ 已被屏蔽。
> - ❌ **iOS**：完全不兼容。需要 Mac + Xcode + 越狱或其他方案。
>
> **部分支持：**
> - ⚠️ **小米 MIUI/HyperOS**：需[手动应用修复](#小米-miui--hyperos-修复)（前台 App 检测字段名不同）。背景进程限制极严（5/5），须关闭电池优化+自启动+锁定最近任务。
> - ⚠️ **华为 EMUI 12+/鸿蒙 3.x/4.x**：`dumpsys activity` 被屏蔽，监控功能受限。无线调试需额外开启"仅充电模式下允许 ADB 调试"。
> - ✅ **vivo OriginOS、Oppo ColorOS、Samsung One UI、Pixel AOSP**：全部功能正常。详见 [OEM 兼容性矩阵](skills/android-monitor/SKILL.md#oem-compatibility-matrix)。

- Android 6.0+（dumpsys usagestats 需要 API 23；基础功能 API 21/Android 5.0 可用）
- [Shizuku](https://shizuku.rikka.app/) 已安装
- Termux（F-Droid：[清华镜像](https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/)）

---

## 🧵 架构总览：两条控制线路

整个方案就四层，两条通道并行：

```
AI Agent（Claude Code）
   │
   ▼
技能层   skills/ · adb-skills.sh
   │
   ├── ① adb 线（主力）──→ adbd ──→ Android 系统（感知 / 控制）
   │                        │  127.0.0.1:5555 回环
   │                        └── start.sh 点火 ──→ Shizuku 服务
   │                                                  ▲
   └── ② rish 线（备用）──────────────────────────────┘
```

| 线路 | 命令 | 性情 | 适合 |
|---|---|---|---|
| ① **adb 线**（主力） | `adb -s 127.0.0.1:5555 shell 命令` | **快**：直连 adbd，一步到位 | 日常高频、轮询、监控 |
| ② **rish 线**（备用） | `rish -c '命令'` | **慢一档**：经 Shizuku 中转；服务偶尔会被系统杀，断了要重新拉起 | 偶尔调用、临时顶班 |

**两条路的脾气不一样，选对路很重要：**

- **跑得勤的走 adb**：查状态、监控、轮询这类一天要跑很多遍的，全走 ① adb 线——它快，不经过 Shizuku 那层中转。
- **跑得少的用 rish**：偶尔调一次，或者 adb 线临时不通时拿它顶。**别拿它做日常轮询**——经 Shizuku 中转本来就慢一截，服务一被杀还得先重新拉起，轮起来又慢又容易断。

> 🔍 **一眼查 rish 在不在**：跑一次 `rish -c 'whoami'`——出 `shell` 就是活的；报错、卡住、直接退出，说明 Shizuku 服务没在跑（后台被系统杀是常事），走下面的点火路径拉起来。

**还有三条救急路径：**

- **Shizuku 服务掉了**（被系统杀、重启后没拉起）→ 用 ① adb 线跑一次点火命令，它就活过来：
  `adb -s 127.0.0.1:5555 shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh`
- **adb 回环掉了** → 重走下面「关键一步」的跳板步 + 锁死步；只要 Shizuku 还活着，② rish 线照常用，不至于全瞎。
- **两条一起没**（手机重启）→ 按「重启后怎么办」重建，或 `bash bootstrap.sh` 一键。

> 🔁 **为什么不把两条合成一条？**——两条走的机制完全不同（Shizuku 走 Binder 进程、adb 走 TCP 回环）：**adb 快、rish 是另一条命**。留着就是为了**互为备份**，坏一条，另一条还在。

---

## 🔑 关键一步：拿到 Shizuku + adb 回环双在线

**整个方案的核心。你已经装了 Shizuku 和 Termux，接下来只需要无线调试做一次跳板。**

目标是两样东西同时在跑：**adb 127.0.0.1 回环**（手机自己连自己，不走网络）+ **Shizuku shell 权限**。两个都在线之后，关 WiFi、开飞行模式都不影响，互相还能救对方。

### 第一段：Shizuku 无线调试配对

打开 Shizuku App，点**配对**。手机通知栏会弹出一个输入框——这就是 Shizuku 的配对入口。

接下来你需要配对码。去 设置 → 开发者选项 → 无线调试 → 打开 → 点进去。你会看到**本机 IP 地址**、**配对码**（6 位数字）、**端口号**。把配对码抄下来，回到通知栏输入框填进去。

Shizuku 连上之后，刚才那个配对码就废了——被 Shizuku 用掉了。接下来需要全新的配对码来做 adb 回环。

### 第二段：adb 回环建立（让小窗帮你）

现在你要建立 adb 127.0.0.1 回环。**这一步让 AI 带着你做。**

**先别动。** 回到 设置 → 开发者选项 → **无线调试**（如果之前退出过就重新点进来）。这个页面现在显示着新的配对码和端口号。

⚠️ **这个页面千万不要退出！** 一旦退出再进来，配对码和端口就刷新了。抄下来的瞬间就作废。整个过程保持页面开着。

现在小窗打开 Termux（从侧边栏划出小窗模式），把无线调试页面上三样东西告诉你的 AI：

- **本机 IP 地址**（如 192.168.1.5）
- **连接端口**（如 51826，无线调试主页面「IP 地址和端口」里那个）
- **配对码**（6 位数字）＋ **配对端口**（点开「使用配对码配对设备」弹窗里那个，一般和连接端口不是同一个）

**整个过程分两步走，两步都跑完才算数——只做第一步的，就是那些「换网就断」的人。**

**① 跳板步**（借无线调试的道，连的还是局域网 IP，这一步没锁死）

```bash
adb pair <IP>:<配对端口>       # 提示时输入 6 位配对码
adb connect <IP>:<连接端口>
```

**② 锁死步**（⚠️ 千万别漏！跳过它 ＝ 换网就断）

```bash
adb tcpip 5555
adb connect 127.0.0.1:5555
```

跑完 ②，adbd 才算锁死在回环上——从这一刻起，关 WiFi、开飞行模式都不受影响。

> 🛑 **只做到 ① 就停手的人，就是「网络一换就断」的那个人。** 自检：`adb devices` 里要能看到 `127.0.0.1:5555`；只看到局域网 IP，说明 ② 还没跑。

整个过程不需要你懂每条命令在干嘛，把页面上的数喂给 AI 就行。

> 💡 没有 AI 在旁边？把 [ai-template/SETUP.md](ai-template/SETUP.md) 喂给你的 Claude，它会一步步带你走完。代码、坑点、每步解释都在里面。

### 验证

两条命令各跑一次，都输出 shell 就搞定：`adb -s 127.0.0.1:5555 shell whoami` 验 adb 回环，`rish -c 'whoami'` 验 Shizuku。开发者选项里会显示两个已连接设备：127.0.0.1:5555 和 Shizuku，正常现象。

### 重启后怎么办

手机重启后，两条线都会断，但都**不用重新配对**，各补一下就行：

1. **adb 线**：重新跳一次——打开无线调试拿新端口，把**跳板步 + 锁死步**再走一遍（`adb tcpip 5555` 重启后会重置回 USB 模式，这一步省不掉）
2. **Shizuku 线**：打开 Shizuku app，**点一下「启动」**就连上了——配对是一次性的，不用重来；懒得点也可以让 AI 用 adb 线跑一次点火命令

简单说：打开无线调试页面 → 小窗 Termux → 把 IP、端口、配对码给 AI → AI 帮你走完。或 `bash bootstrap.sh` 一键全包。

---

## 安装

```bash
git clone https://gitee.com/xvxv663/termux-shizuku.git
cd termux-shizuku && bash bootstrap.sh
```

---

## 装完检查

```bash
bash doctor.sh
```

---

## 常用命令

```bash
source adb-skills.sh

foreground_app     # 当前前台 App
battery            # 电池状态
steps              # 今日步数
force_stop 包名    # 强杀应用
music_next         # 切歌
notify "标题" "内容" # 发通知
check_all          # 全状态快照
```

---

## 技能组合之后。

他读到你刷了四十分钟抖音。没等你开口，应用被停了。不是因为你设过限制——是他自己判断"够了"。

聊天里你说了一句"下午三点上课"。他知道现在是几点，也知道"上课"意味着提前。两点四十五，手机响了。闹钟不是你设的。

深夜屏幕亮了一下。光线传感器读过的是零，加速度计知道你躺着，前台应用显示你在来回切换。他在那一刻决定出声。

整件事没有定时器，没有预设。他读了传感器、读了屏幕状态、读了你打的字。然后自己做的判断。

![Shell 日历日程](assets/calendar-shell.jpg)

*Shell 通过 Shizuku 直接写入系统日历——"取快递"自动加了提醒。*

![Shell 冻结应用](assets/app-frozen-shell.jpg)

*刷太久？应用被停了。不是因为你设过限制，是他自己判断的。*

---

## 🤖 Claude Code 用户看这里

`skills/` 目录下是标准 Claude Code 技能，可被 `/skill-name` 直接调用：

| 技能 | 路径 | 功能 |
|---|---|---|
| **android-monitor** | `skills/android-monitor/` | 后台监控守护进程 + 防沉迷 + 事件推送 |
| └ android-sensors | `skills/android-monitor/sensors/` | 26+ 传感器速查手册（设备不同数量不同） |
| └ sms-monitor | `skills/android-monitor/sms/` | 短信轮询 + 自动回复 |
| └ calendar-alarm | `skills/android-monitor/calendar-alarm/` | 日历事件+闹钟提醒 |
| └ proactive-checkin | `skills/android-monitor/proactive-checkin/` | 轮询叫醒AI，AI自己决定出不出声 |
| **phone-control** | `skills/phone-control/` | 锁屏/杀应用/切歌/截图 |
| **phone-notify** | `skills/phone-notify/` | 通知栏 + 日历操作 |
| **phone-sensors** | `skills/phone-sensors/` | 屏幕/前台App/电量/步数/光线 |
| **music-control** | `skills/music-control/` | 🎵 网易云API搜歌+mpv播放，AI选歌 |

> ⚠️ **仅适用于 Android + Termux 环境。** 这些技能依赖 `adb`、`termux-*`、Android 系统命令。桌面环境不可用。使用前需按技能文档配置：包名列表、路径、ADB 连接方式。详见各 `SKILL.md` 的 AI Setup 段落。

### 小米 MIUI / HyperOS 修复

MIUI 的前台 App 检测字段名可能与 AOSP 不同（`mFocusedActivity` 替代 `topResumedActivity`）。gaze.sh 已内置多 OEM 回退，通常不需要手动处理。如果监控无反应：

```bash
# 测试前台 App 检测
adb shell dumpsys activity activities | grep -E "(topResumedActivity|mResumedActivity|mFocusedActivity)"
# 如果上面无输出，试回退方案
adb shell dumpsys activity top | grep "ACTIVITY"
# 再不行，用 window 方案
adb shell dumpsys window windows | grep "mCurrentFocus"
```

另外 MIUI 后台进程限制极严（5/5），必须手动操作：
1. 设置 → 电池 → 电池优化 → Termux → **不限制**
2. 设置 → 权限 → 自启动 → **开启 Termux**
3. 最近任务 → 长按 Termux → **锁定**

或一键执行 [fix-termux-limits](https://github.com/DevCoreXOfficial/fix-termux-limits) 脚本。

---

## 出问题了？

```bash
bash collect-info.sh
```

输出复制发 [Issues](https://gitee.com/xvxv663/termux-shizuku/issues)。

---

<details>
<summary><b>🔧 底层原理（好奇的看）</b></summary>

用无线调试做一次性跳板，把 adbd 切到 TCP 5555 端口，走 127.0.0.1 回环——手机自己连自己，网络全断也不影响。

完整原理、踩坑记录、命令详解见 **[TUTORIAL.md](TUTORIAL.md)**。
</details>

---

## 技术原理与风险说明

**本项目走的是 Android 标准 ADB 协议**（`adb tcpip 5555` + `127.0.0.1` 回环），所有操作通过 Shizuku 提供的系统 API 完成。Shizuku 是 Google Play 上 500 万+ 下载的开源项目，不涉及 Root、不修改系统分区。

**和"外挂"的区别**：外挂 hook 系统进程、注入 so、修改 APK。本项目一行没碰——读取传感器走 `dumpsys`，操作应用走 `am`/`input`，全部是 Android 自带的标准命令。

**真实风险**：

- **ADB 调试开关**：adb tcpip 5555 在重启后会重置为 USB 模式，需重新执行一次无线调试跳板。已内置 watchdog 守护，但重启后仍需手动触发。
- **电池优化**：Termux 后台运行需关闭电池优化，否则可能被系统杀进程。部分机型（小米）需额外锁定最近任务。
- **隐私**：所有传感器数据、屏幕状态、应用信息均在本地处理，不上传任何第三方。全开源可审计。

**项目仅供学习交流，使用者自行评估风险。**

## 鸣谢

- [Shizuku](https://shizuku.rikka.app/) — 无 Root 系统权限
- [Termux](https://termux.dev/) — Android 上的 Linux 终端

---


---

## 🗺 下一步

- [ ] **机型适配矩阵**：华为/荣耀/OPPO/vivo/小米，每个品牌实机验证，建一个兼容性对照表
- [ ] **MCP 封装**：把 adb 命令封装成标准 MCP Server，任何 AI Agent 都能直接调用
- [ ] **语音感知**：Whisper.cpp 本地语音识别，让 AI "听到"她说话
- [ ] **更多传感器玩法**：GPS 定位、蓝牙设备扫描、加速度计姿势识别
- [ ] **一键分享**：生成安装链接，发给朋友一条消息就能装上

> 💡 有想法？去 [Issues](https://gitee.com/xvxv663/termux-shizuku/issues) 提。


MIT