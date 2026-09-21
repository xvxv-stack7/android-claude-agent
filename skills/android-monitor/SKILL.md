---
name: android-monitor
description: 安卓后台监控+防沉迷系统。使用时机：需要后台监控手机状态、限制应用使用时长、自动锁应用、事件驱动弹窗提醒。| Android background monitoring with anti-addiction. Use when: background phone monitoring, app time limits, auto force-stop, event-driven notifications needed.
---

> ⚠️ **运行环境：Android + Termux + ADB。** 本技能依赖 `adb`、`termux-notification`、`termux-media-player`、`content` 等 Android/Termux 专属命令。在 macOS / Windows / Linux 桌面环境无效。需先通过 [android-claude-agent](https://gitee.com/xvxv663/android-claude-agent) 的 bootstrap.sh 完成环境初始化。

# Android Monitor — Claude Code Skill

Lightweight background monitoring for Android devices via Termux + ADB. Continuously tracks device state and pushes meaningful events to Claude Code through a Monitor hook, enabling real-time AI-generated notifications. Includes a cumulative app usage limiter with progressive enforcement.

## Sub-skills

- **[Sensors Reference](sensors/SKILL.md)** — 43-sensor catalog with composite inference patterns. Covers motion, orientation, environmental, activity recognition, and event detection sensors accessible via `dumpsys sensorservice`.

## Architecture

```
gaze.sh (system daemon, 60s loop)
  ├─ collect_state()       → dumpsys power / activity / battery
  ├─ detect_and_extract()  → 调用 detect.py，11 种事件一次检测
  ├─ app_limit.sh          → cumulative time tracking + force-stop at threshold
  ├─ send_nudge()          → writes lightweight trigger for Claude Code Monitor

Claude Code session
  └─ Monitor (persistent) → watches trigger file → AI generates notification message
```

- **gaze.sh** runs as a background daemon (60s poll interval)
- **Dual-channel shell**: `sh_cmd()` tries **Shizuku rish** first (binder IPC, no WiFi needed), falls back to **ADB over TCP** (127.0.0.1:5555). All shell commands automatically use this channel — no separate config required.
- Events go through **Monitor** (event-driven, not cron-polled) to Claude Code
- **The AI generates every message live** — no templates, no canned responses. Each trigger is a moment: the AI reads the event, looks at the user's current state (what app, what time, how many steps), and writes a unique message in its own voice.
- **app_limit.sh** tracks cumulative daily usage per app and force-stops on limit

## Requirements

- Android device with Termux
- **Shizuku** (recommended) — binder IPC, no WiFi dependency, survives reboot
- At least one of the above must be active. `sh_cmd()` in gaze.sh auto-detects and picks the available channel.
- `termux-notification` (termux-api package)
- `python3` in Termux
- Claude Code with Monitor tool access

## 🤖 AI Setup Guide

When the user says "set up android-monitor" or "install this skill", **the AI should run these steps automatically**. The user does not need to read or understand them.

### Step 1: Detect device

```bash
adb devices && adb shell getprop ro.build.version.release
```

### Step 2: Find entertainment apps on this device

```bash
adb shell pm list packages | grep -iE "aweme|xhs|bili|kuaishou|game|timi|sgame|pubg|genshin|honkai|starrail|qqlive|iqiyi|youtube|netflix|tiktok" | cut -d: -f2
```

Show the list to the user. Ask: "Which of these should I set time limits for, and how many minutes per day?"

### Step 3: Write app_limit_config.json

Based on the user's answers, write `~/.cc-connect/app_limit_config.json`. Use the template format:
```json
{"<package>": {"name": "<human name>", "limit_minutes": <minutes>}, ...}
```

### Step 4: Update gaze.sh entertainment patterns

Read `detect.py`, and update the `ent_kw` and `game_kw` lists to match the packages from Step 2. Keep package name fragments (e.g., for `com.ss.android.ugc.aweme` use `aweme`).

### Step 5: Set up data directory

```bash
mkdir -p ~/.cc-connect/scripts
cp gaze.sh ~/.cc-connect/scripts/
cp app_limit.sh ~/.cc-connect/scripts/
chmod +x ~/.cc-connect/scripts/*.sh
```




### Step 7: Verify ADB and start daemon

```bash
adb connect 127.0.0.1:5555
nohup bash ~/.cc-connect/scripts/gaze.sh > /dev/null 2>&1 &
echo "gaze.sh started with PID: $(pgrep -f gaze.sh)"
```

### Step 8: Set up Monitor

Start the Claude Code Monitor hook (the AI does this — not the user):

```
Monitor persistent: true, command:
TRIGGER="$HOME/.cc-connect/gaze_trigger.json"; LAST_TS=0; while true; do if [ -f "$TRIGGER" ]; then TS=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('ts',0))" 2>/dev/null || echo 0); if [ "$TS" -gt "$LAST_TS" ]; then LAST_TS=$TS; EVENT=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('event',''))" 2>/dev/null || echo ""); FG=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('fg_app',''))" 2>/dev/null || echo ""); echo "TRIGGER:$EVENT|app=$FG|ts=$TS"; fi; fi; sleep 3; done
```

### Step 9: Verify everything works

```bash
# Check daemon running
pgrep -f gaze.sh

# Check state file being written (wait 60s after start)
cat ~/.cc-connect/gaze_state.json | python3 -m json.tool

# Check calendar access (for calendar-alarm)
adb shell content query --uri content://com.android.calendar/calendars --projection _id:name
```

Tell the user: "Setup complete. I'm now monitoring your device in the background."

## Quick Reference (for the user)

### Config example (`~/.cc-connect/app_limit_config.json`)

```json
{
  "com.ss.android.ugc.aweme": {"name": "TikTok", "limit_minutes": 40},
  "com.xingin.xhs": {"name": "RED", "limit_minutes": 30},
  "tv.danmaku.bili": {"name": "Bilibili", "limit_minutes": 60}
}
```

### Monitor setup

Use the `polling-on` pattern:

```
Monitor persistent: true, command:
TRIGGER="$HOME/.cc-connect/gaze_trigger.json"; LAST_TS=0; while true; do if [ -f "$TRIGGER" ]; then TS=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('ts',0))" 2>/dev/null || echo 0); if [ "$TS" -gt "$LAST_TS" ]; then LAST_TS=$TS; EVENT=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('event',''))" 2>/dev/null || echo ""); FG=$(python3 -c "import json; print(json.load(open('$TRIGGER')).get('fg_app',''))" 2>/dev/null || echo ""); echo "TRIGGER:$EVENT|app=$FG|ts=$TS"; fi; fi; sleep 3; done
```

When a trigger arrives, the AI must first check where the user is:

- **User is in chat app (Termux/WeChat)** → The trigger is background intelligence. Absorb it silently — don't announce triggers, don't pop notifications. Let the context flow naturally into the conversation. A midnight trigger means you know it's late, not that you need to say so.
- **User is NOT in chat** → The trigger is a reason to reach out. Generate a live message and send via termux-notification. Every message is unique, never from a template.
- **Never** pop a notification when the user is actively talking to you.

```bash
# Before sending: check foreground app
FG=$(cat ~/.cc-connect/gaze_state.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('fg_app',''))")
if [[ "$FG" != "com.termux" && "$FG" != "com.tencent.mm" ]]; then
    MSG="your unique real-time message here" && termux-notification --id "gaze_$(date +%s)" --title "Monitor" --content "$MSG" --priority max
fi
```

## Event Types

|---|---|---|
| `woke_up` | Screen off → on (gap > 5 min) | "Screen woke up." |
| `started_walking` | Steps +200 | "Started moving." |
| `stopped` | Steps stalled > 45 min | "No movement for a while." |
| `binge_app` | Same entertainment app > 30 min (per-app once/day) | "Been scrolling a while, take a break." |
| `app_switch` | Leaving entertainment app → non-chat app | "Switched away from entertainment app." |
| `gaming_end` | Left a game app | "Gaming session ended." |
| `low_battery` | Battery dropped below 15% | "Battery low, charge soon." |
| `midnight_phone` | Screen on at 23:00–06:00 (once/night) | "Late night screen time." |
| `left_chat` | Left WeChat/Termux → entertainment app | "Left chat to browse." |
| `random_glance` | Random 3%/loop check-in (min 30min gap) | "Random check-in." |
| `music_moment` | Bluetooth A2DP + daytime + 2%/loop (min 40min gap) → AI plays a song, reads notification for title/artist, searches lyrics, chats about it | "Music moment — headphones on." |
| `long_silence` | No state change > 2.5h | "No activity for a while." |

## Anti-Addiction (app_limit.sh)

Tracks **cumulative daily usage** per app (not just continuous session). Logic:

- Each loop tick: if foreground app is in the config, accumulate elapsed seconds since last check
- Gap ≤ 60s counts as continuous; longer gaps do not accumulate
- **80% threshold** → `warned_N` → termux-toast with remaining minutes (every 5 min max)
- **100% threshold** → `locked` → `am force-stop` + home key + toast
- Resets at midnight

Called automatically by gaze.sh every loop — no separate process needed.



Format:
```json
{
  "woke_up": ["msg1", "msg2", "msg3"],
  "binge_app": ["...", "..."],
  ...
}
```


## Files

| Path | Purpose |
|---|---|
| `gaze.sh` | Main daemon |
| `app_limit.sh` | Usage tracker + limiter |
| `app_limit_config.json` | Per-app daily minute limits |
| `sensors/SKILL.md` | 43-sensor reference catalog |
| `sms/SKILL.md` | SMS inbox polling via ADB content provider |
| `calendar-alarm/SKILL.md` | Calendar events with alarm reminders |
| `proactive-checkin/SKILL.md` | Polling-based AI proactive check-in |
| `~/.cc-connect/gaze_state.json` | Current device snapshot (written by gaze.sh) |
| `~/.cc-connect/gaze_trigger.json` | Latest event trigger (consumed by Monitor) |
| `sentinel.log` | Event log |

## Dedup Strategy

- Same event type: max once per 10 minutes
- `binge_app`: once per app per day
- `midnight_phone`: once per night
- `locked` (anti-addiction): once per app per day
- Warn toast: max once per 5 minutes per app

## Token Efficiency

- gaze.sh uses 60s polling (lightweight bash, no LLM involved)
- Trigger file contains only 5 fields: `event`, `fg_app`, `battery`, `screen`, `ts`
- Monitor pushes only when trigger updates (~3–6 events/hour after dedup)
- No CronCreate — Monitor is event-driven, not time-polled

## Design: Why Bash Polling?

The 60-second polling loop in gaze.sh looks naive compared to modern event-driven architectures (inotify, Android BroadcastReceiver, AccessibilityService). It's a deliberate choice based on Android's constraints:

### The Problem
Android does not expose foreground-app-change events or sensor streams to command-line tools. The alternatives all hit walls:

| Approach | Why It Fails |
|---|---|
| **inotify** | No filesystem event fires when the user switches apps. `/proc` and `/sys` don't reflect Activity Manager state changes. |
| **BroadcastReceiver** | Requires a Java/Kotlin APK with `PACKAGE_USAGE_STATS` permission. Can't be triggered from Termux shell scripts. |
| **AccessibilityService** | Needs a signed APK + user consent via Settings. Overkill for a shell-script monitoring system. |
| **logcat tail** | `logcat -s ActivityManager` can stream app-switch events, but logcat output is vendor-specific, rate-limited, and pruned by Android. Not reliable enough for a persistent daemon. |
| **UsageStatsManager API** | Only accessible via Java/Kotlin. No command-line bridge without a helper APK or Shizuku. |

### The Solution
`dumpsys` is the only universal, permission-free interface that exposes real-time Activity Manager state from the shell. The trade-off:

- **Cost**: One `dumpsys activity activities` call per loop (~200ms, negligible CPU)
- **Gain**: Works on every Android device without APK installation, root, or Accessibility consent
- **Compromise**: 60s polling is the floor for reliability — lower intervals risk dumpsys contention and battery drain

### The Bridge to Claude Code
Even with efficient bash polling, piping raw events into Claude Code would burn tokens on noise. The two-layer filter solves this:

```
gaze.sh (bash, always-on)
  → dedup + throttle (same event ≤ 1/10min, binge ≤ 1/day/app)
  → writes 5-field trigger only on meaningful state changes
  → Monitor (Claude Code hook, session-scoped)
    → AI generates custom notification only when trigger fires
```

The Monitor hook adds near-zero token overhead when idle — it only pushes when `gaze_trigger.json` actually changes. This is the key insight: **bash handles the constant monitoring so Claude Code only pays for the interesting moments.**

## Android Version Compatibility

| Feature | Min API | Notes |
|---|---|---|
| `dumpsys activity activities` | 21 (5.0) | Core state query. Stable across all versions. |
| `dumpsys power` | 21 (5.0) | `mWakefulness` field name varies by OEM. Test on target device. |
| `dumpsys battery` | 21 (5.0) | Universal. |
| `dumpsys sensorservice` | 21 (5.0) | Sensor count/names vary by OEM. 43 on vivo S19 (API 35), ~20-30 typical. |
| `dumpsys usagestats` | 23 (6.0) | Required for sleep-analyze. Requires `--user 0` on some devices. |
| `am force-stop` | 21 (5.0) | Anti-addiction enforcement. Universal. |
| `termux-notification` | — | Requires termux-api package. Independent of Android version. |
| `input keyevent 3` | 21 (5.0) | Home key simulation. Works without Accessibility. |
| Shizuku `rish` | 24 (7.0) | Optional: higher-privilege shell for some OEMs where adb is restricted. |
| vivo_activity sensor | 31+ (12+) | Vendor-specific. Not available on all devices. |

**Minimum target**: Android 6.0 (API 23) for full functionality. Android 5.0 (API 21) works with reduced features (no usagestats).

## OEM Compatibility Matrix

Each OEM customizes Android differently. Below are verified compatibility notes per manufacturer and per command. **Test on the target device before deploying.**

### Per-Command OEM Compatibility

| Command | Pixel/AOSP | Xiaomi MIUI/HyperOS | Huawei EMUI/HarmonyOS | vivo OriginOS | Oppo ColorOS | Samsung One UI |
|---|---|---|---|---|---|---|
| `dumpsys activity activities` | ✅ | ⚠️ field rename | ❌ blocked EMUI 12+ | ✅ | ✅ | ✅ |
| `dumpsys power` (read) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `dumpsys battery` (read) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `dumpsys battery set` (write) | ✅ | ⚠️ needs MIUI Opt off | ❌ often root-only | ❌ restricted | ❌ restricted | ⚠️ strict policies |
| `dumpsys sensorservice` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `dumpsys usagestats` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `content query calendar` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `am force-stop` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `input keyevent` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `termux-notification` | ✅ | ⚠️ needs exemption | ⚠️ needs exemption | ⚠️ needs exemption | ⚠️ needs exemption | ✅ |
| `adb tcpip 5555` (wireless) | ✅ | ✅ | ⚠️ needs extra toggle | ✅ | ✅ | ✅ |

**Legend**: ✅ Works out of box | ⚠️ Needs workaround | ❌ Blocked / very limited

### Detailed OEM Notes

#### Xiaomi (MIUI / HyperOS)
- **dumpsys battery set**: requires disabling "MIUI Optimization" in Developer options → reboot.
- **Background survival**: aggression rating 5/5. Must: disable battery optimization for Termux, enable Autostart, lock Termux in Recents (drag card down until padlock appears). Recommend running `fix-termux-limits` script.
- **Wireless debugging**: supported. Standard `adb tcpip 5555` flow works.

#### Huawei (EMUI / HarmonyOS)
- **HarmonyOS NEXT (5.0+)**: **ADB not available**. Uses `hdc` (HarmonyOS Device Connector) exclusively. This skill's ADB-based commands will not work. Requires hdc-based rewrite.
- **Wireless debugging**: supported on HarmonyOS 3.x/4.x with extra step — must enable "仅充电模式下允许ADB调试" toggle. First-time setup: USB connect → `adb tcpip 5555` → `adb connect IP:5555` → unplug USB.
- **dumpsys battery set**: often requires root.
- **Background**: standard Chinese OEM restrictions apply. Add Termux to battery optimization exceptions.

#### vivo (OriginOS / FuntouchOS)
- **dumpsys activity**: works normally. Tested on vivo S19 (OriginOS 5 / API 35).
- **dumpsys battery set**: restricted. System blocks battery state simulation.
- **Background survival**: aggression 3/5. Must: enable Auto-start, allow high background power consumption, disable Background Activity Manager for Termux.
- **Sensors**: rich sensor set (43 on S19), but names are Bosch/Lite-On vendor-specific.

#### Oppo (ColorOS)
- **dumpsys battery set**: typically unsupported. System restrictions are strict.
- **Background survival**: aggression 3/5. Must: add Termux to Protected Apps list, enable in Startup Manager.
- Other commands work normally.

#### Samsung (One UI)
- **dumpsys activity**: works normally. Field names follow AOSP.
- **dumpsys battery set**: often restricted by strict security policies.
- **Background**: generally better than Chinese OEMs. Battery optimization exemption recommended.

### Termux Background Survival Quick Reference

| OEM | Key Settings Required |
|---|---|
| Xiaomi | Battery opt → No restrictions, Autostart ON, Lock in Recents |
| Huawei | Battery opt → No restrictions, App launch → Manage manually |
| vivo | Auto-start ON, High background power → Allow, Background Activity Manager → Unrestrict |
| Oppo | Protected Apps → Enable, Startup Manager → Allow |
| Samsung | Battery → Unrestricted |
| Pixel/AOSP | None required |

## Sub-skills

- **[Sensors Reference](sensors/SKILL.md)** — 43-sensor catalog with composite inference patterns
- **[SMS Monitor](sms/SKILL.md)** — SMS inbox polling + content forwarding via ADB
- **[Calendar Alarm](calendar-alarm/SKILL.md)** — Calendar events with alarm-style reminders via content provider
- **[Proactive Check-in](proactive-checkin/SKILL.md)** — Polling wakes the AI, the AI reads state and decides whether to speak

## Customization

- Adjust `LOOP_SLEEP` in gaze.sh (default 60s)
- Modify `app_limit_config.json` for different apps/limits
- Extend `detect.py` for custom triggers
