---
name: ui-input
description: 输入框聚焦+文本输入（支持中文）。使用时机：需要先定位并聚焦当前屏幕的输入框，再输入文本；解决 adb input text 不支持中文的问题。| Input field focus + text input (supports Chinese). Use when: need to locate & focus the active input field then type text; solves adb input text lacking Unicode support.
---

# UI Input — Claude Code Skill

Focus the active input field, then type text — including Chinese/Unicode. Solves the two classic adb typing pain points in one command:

1. **`input text` cannot send non-ASCII** (Chinese/emoji throw `NullPointerException`) → routes Unicode through ADBKeyBoard's base64 broadcast.
2. **Text lands in the wrong place when no input field is focused** → locates the field first (`focused=true`, else `EditText` class) and taps it before typing.

No root. No PC. Runs entirely on the phone over the adb loopback (or Shizuku).

## 🚀 一句话原理 / The gist

| 步骤 Step | 动作 Action |
|---|---|
| 定位输入框 | 读 `uiautomator` 树 → 找 `focused=true` 节点（次选 `EditText` 类） |
| 聚焦 | `input tap <中心点>` |
| 输入 ASCII | `input text`（原生，快） |
| 输入中文/Unicode | 切到 ADBKeyBoard → `am broadcast ADB_INPUT_B64`（base64）→ 切回原输入法 |

## Requirements

- ADB over TCP loopback (`adb -s 127.0.0.1:5555`) or Shizuku `rish`
- Python 3 (stdlib only — no pip deps)
- **Chinese/Unicode 输入需装 ADBKeyBoard**（可选，只输英文/ASCII 不需要）
  - 来源：[senzhk/ADBKeyBoard](https://github.com/senzhk/ADBKeyBoard)（开源，GPL-2.0，社区标准方案）
  - 一步装：`adb install ADBKeyboard.apk && adb shell ime enable com.android.adbkeyboard/.AdbIME`

## 🤖 AI Setup

```bash
# 先确认 adb 回环通
adb -s 127.0.0.1:5555 shell echo ok
# 或走 Shizuku（脚本自动优先 rish）
```

## 用法 Usage

```bash
# 聚焦当前输入框（不输入）
python3 ui-input.py --focus

# 输入文本（自动分流：英文走 input text；中文走 ADBKeyBoard 广播）
python3 ui-input.py --type "你好 Hello"

# 找控件坐标（text/desc/id）
python3 ui-input.py --find "确认"
```

## 关键实现细节 Implementation notes

### 输入框定位 / Input field discovery
- 优先 `focused=true` 的节点（最准）；次选 `class` 含 `EditText`/`Input` 的节点。
- 黑盒 app（微信/部分 WebView/Flutter）不向 uiautomator 吐控件树 → 读不到输入框 → 返回 `✗`，此时需退回**截图+视觉**定位坐标，不可硬 input。

### 中文输入 / Unicode input
- `input text` 仅支持 ASCII，中文必报 `NullPointerException`（Android 设计限制，非 bug）。
- 方案：ADBKeyBoard 是一个「隐形虚拟键盘」，不占屏幕、不弹键盘，通过系统广播喂字。
- 命令：`am broadcast -a ADB_INPUT_B64 --es msg <base64文本>`（base64 规避编码坑，比 ADB_INPUT_TEXT 稳）。

### 输入法自动切回 / IME auto-restore
- 脚本不写死任何输入法。输入前记录 `settings get secure default_input_method`，发完中文自动切回用户原来的输入法。
- 只输入 ASCII 时**完全不切输入法**，零副作用。

## 与其他技能的关系

- `phone-elements`：纯读 UI 树、找坐标。本技能在其上**加了「聚焦输入框 + 输入文本」动作**，两者互补不冲突。
- `phone-open` / `phone-control`：锁屏/杀应用/切歌等，与输入无关。

## OEM 注意

- vivo OriginOS：`uiautomator dump /dev/tty` 不通 → 走文件 dump（脚本已处理）。
- 小米 MIUI/HyperOS：`uiautomator dump` 退出码可能非零但 XML 有效 → 本脚本只看 XML 内容，不查退出码。
- ADBKeyBoard 安装后需在「语言与输入法」里允许启用，或 `adb shell ime enable` 一条搞定。
