# termux-shizuku 完整教程

> 仓库地址：https://gitee.com/xvxv663/termux-shizuku（GitHub 镜像：https://github.com/xvxv-stack7/termux-shizuku）

---

## 一、这是什么

**让 AI Agent 免 Root、免电脑、永久控制 Android 手机。**

传统方案要么 root，要么 USB 连着电脑。本项目用无线调试做一次性跳板，把 adbd 切到固定端口后通过 127.0.0.1 回环自连——关 WiFi、开飞行模式，连接不中断。单台手机，零外设。

## 二、原理

```
① 开无线调试 → adbd 获得随机端口（如 38435）
        ↓ 此时还依赖 WiFi 局域网 IP
② adb connect 127.0.0.1:38435 → adbd 可达
        ↓ 通过这个跳板发一条命令
③ adb tcpip 5555 → adbd 切到固定 5555 TCP 模式
        ↓ 从这一刻起，不再需要无线调试
④ adb connect 127.0.0.1:5555 → 回环自连
        ↓ 127.0.0.1 不走任何网络栈
⑤ Shizuku 通过 ADB 5555 启动 → rish 永久 shell 权限
        ↓
⑥ AI Agent 直接控制手机
```

核心洞察：`adb tcpip` 是 Android 为 USB 调试设计的命令。adbd 不区分连接来源——只要连上了，执行 `adb tcpip 5555` 就能切到固定 TCP 模式。切完后连 127.0.0.1 是手机自己连自己，网络全断也不影响。

## 三、踩过的坑

| 方法 | 结果 |
|------|------|
| `setprop service.adb.tcp.port 5555` | SELinux 拦截 |
| 无线调试 → 关 WiFi | adbd 自杀 |
| 无线调试做跳板 → `adb tcpip 5555` → 127.0.0.1 回环 | ✅ 唯一能活的方案 |
| 关 WiFi / 开飞行模式 | 5555 回环不受影响 |

## 四、安装

### 前提
- Android 11+
- 已安装 [Shizuku](https://shizuku.rikka.app/)
- 已安装 [Termux](https://termux.dev/)

### 步骤

```bash
# 1. 安装依赖
pkg install android-tools

# 2. 克隆仓库
git clone https://gitee.com/xvxv663/termux-shizuku.git
cd termux-shizuku

# 3. 打开 USB 调试
# 设置 → 开发者选项 → USB 调试 → 打开

# 4. 一键启动
bash bootstrap.sh
```

脚本会依次：检查依赖 → 探测 adbd → 切 adbd 到 TCP 5555 → 连接 127.0.0.1:5555 → 启动 Shizuku → 验证。

### 开机自启（需要 Termux:Boot）

```bash
bash boot/startup.sh
```

## 五、使用

### 两条命令线

```bash
# 日常主力：adb 线（直连 adbd，快——查状态、轮询、监控都走它）
adb -s 127.0.0.1:5555 shell 命令

# 备用：rish 线（经 Shizuku 中转，慢一档；服务偶尔被系统杀，断了要重新拉起，别拿它做日常轮询）
rish -c '命令'
```

> 跑得勤的走 adb，跑得少的用 rish。两条互为备份：Shizuku 服务掉了，用 adb 线跑一次点火命令（start.sh）就能救回来。

### 技能库速查

加载技能库：
```bash
source adb-skills.sh    # 纯 adb 版本（推荐）
# 也可用 Shizuku rish 通道：rish -c '命令'
```

**感知类**
```bash
foreground_app          # 当前前台 app
battery                 # 电池/温度
screen_state            # 屏幕亮灭
steps                   # 步数
ambient_light           # 环境光
is_nearby               # 是否在旁边
wifi_info               # WiFi SSID
signal_info              # 手机信号
check_all               # 全状态快照
```

**控制类**
```bash
force_stop com.ss.android.ugc.aweme   # 强杀抖音
music_pp                               # 播放/暂停
music_next                            # 下一首
volume_up                             # 音量+
volume_down                           # 音量-
camera_open                           # 打开相机
lock                                  # 锁屏（adb-skills.sh）
wake                                  # 唤醒屏幕（adb-skills.sh）
```

**通知类**
```bash
notify "标题" "内容"                   # 系统通知
notify "标题" "内容"                     # 系统通知（可加 --id --priority 等参数）
notifications                          # 当前通知列表
```

**日历类**
```bash
cal_list                               # 列出事件
cal_add "标题" 开始ms 结束ms            # 添加事件
cal_del ID                             # 删除事件
```

**蓝牙类（adb-skills.sh）**
```bash
bt_devices                            # 配对设备列表
bt_on                                 # 开蓝牙
bt_off                                # 关蓝牙
bt_status                             # 蓝牙状态
```

**设置类**
```bash
open_display_settings                 # 打开显示设置
open_battery_settings                 # 打开电池设置
open_notify_access                    # 打开通知权限设置
```

## 六、已验证能力清单

### 感知层
| 能力 | 方法 |
|------|------|
| 屏幕亮灭 | `dumpsys power` → mWakefulness |
| 前台 app | `dumpsys activity` → topResumedActivity |
| 加速度（运动检测） | `termux-sensor Accelerometer` |
| 环境光（暗处/口袋检测） | `termux-sensor Ambient Light` |
| 步数 | `termux-sensor pedometer` |
| 电池/温度 | `dumpsys battery` |
| 手机信号 | `dumpsys telephony.registry` |
| WiFi SSID | `dumpsys wifi` → mWifiInfo |
| 蓝牙设备列表 | `dumpsys bluetooth_manager` |
| 应用使用时间线 | `dumpsys usagestats` |

### 控制层
| 能力 | 方法 |
|------|------|
| 锁屏 | `input keyevent 26`（不杀 Shizuku） |
| 唤醒 | `input keyevent 224` |
| 强杀 app | `am force-stop 包名` |
| 音乐播放/暂停/切歌 | `input keyevent 85/87/88` |
| 音量控制 | `input keyevent 24/25` |
| 开关蓝牙 | `svc bluetooth enable/disable` |
| 发系统通知 | `termux-notification` |
| 日历增删改查 | `content query/insert/update/delete` |
| 打开相机 | `am start IMAGE_CAPTURE` |
| 打开任意设置页 | `am start -a android.settings.*` |

### 数据层
| 能力 | 方法 |
|------|------|
| 联系人列表 | `content query contacts` |
| 下载文件列表 | `ls /sdcard/Download` |
| 最近照片 | `ls /sdcard/DCIM/Camera` |
| 内存/存储 | `dumpsys meminfo` + `df` |
| 运行时间 | `cat /proc/uptime` |

### 已知限制（OriginOS/vivo）
| 能力 | 原因 |
|------|------|
| 亮度调节 | vivo_lcm_brightness_service SELinux 锁死 |
| 通知文字内容 | dumpsys 加密，需通知监听器 |
| 剪贴板读取 | vivo 剪贴板 provider 权限拒绝 |
| 无声静默拍照 | 需要 HAL3 API |
| setprop | SELinux 拦截 |

## 七、AI Agent 接入

将 `ai-template/CLAUDE.md` 的内容加到你的 AI 配置中，AI 就能通过 rish/adb 控制手机。

核心用法就两条：
```bash
rish -c '你的命令'                       # Shizuku 通道
adb -s 127.0.0.1:5555 shell 你的命令     # ADB 通道（备选）
```

## 八、常见问题

**Q: 手机重启后连不上了？**
A: 重跑 `bash bootstrap.sh`。或者用开机自启脚本。

**Q: WiFi 关了也能用？**
A: 能。连的是 127.0.0.1 回环，不走任何网络。

**Q: Shizuku 后台被杀？**
A: 打开 Shizuku app → 通过 ADB 启动。或者用自愈命令：
```bash
rish -c 'setprop service.adb.tcp.port 5555 && stop adbd && start adbd'
```

**Q: 支持哪些品牌？**
A: 所有 Android 11+ 设备。已在 vivo S19 (OriginOS/Android 16) 实测通过。

**Q: 需要 root 吗？**
A: 不需要。Shizuku 提供 ADB 级权限，足够用。

## 九、鸣谢

- [Shizuku](https://shizuku.rikka.app/) — 让普通应用获得 ADB 级系统权限
- [Termux](https://termux.dev/) — Android 上的 Linux 终端

## 十、许可

MIT
