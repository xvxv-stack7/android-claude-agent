#!/data/data/com.termux/files/usr/bin/python3
"""ui-input — focus an input field and type text (ASCII + Chinese/Unicode) via adb/uiautomator.

Solves two long-standing adb problems in one place:
  1. `input text` only accepts ASCII — Chinese/emoji throw NullPointerException.
     Fix: switch to ADBKeyBoard (an open virtual keyboard) and send a base64 broadcast.
  2. Text lands in the wrong place if no input field is focused.
     Fix: locate the input field (focused=true, else EditText class) and tap to focus first.

Ideas from the community:
  - ADBKeyBoard (senzhk/ADBKeyBoard) is the standard way to type Unicode over adb.
  - Input field discovery is the same `focused`/`EditText` heuristic used by uiautomator
    toolchains (uiautomator2 / Appium).

Usage:
  ui-input.py --focus            locate + focus the current input field
  ui-input.py --type "hello"     focus, then type (ASCII → input text; Unicode → ADBKeyBoard broadcast)
  ui-input.py --find "确认"       list matching elements (text/desc/id)

Dependencies: adb (127.0.0.1:5555 loopback, or rish), optional ADBKeyBoard APK for Unicode.
"""
import subprocess, sys, re, json, base64

# Dual channel like elements.py: prefer Shizuku rish, fall back to adb loopback.
CHANNELS = [["rish", "-c"], ["adb", "-s", "127.0.0.1:5555", "shell"]]

ADBKEYBOARD_IME = "com.android.adbkeyboard/.AdbIME"

def sh(cmd, timeout=15):
    """Run through the first available channel; return (ok, stdout).

    A channel counts as "worked" only if it produced output — rish may
    return a "RISH_APPLICATION_ID is not set" error with an empty stdout,
    which must fall through to the adb loopback instead of being treated
    as success.
    """
    for ch in CHANNELS:
        try:
            r = subprocess.run(ch + [cmd], capture_output=True, text=True, timeout=timeout)
            if r.returncode == 0 and r.stdout.strip():
                return True, r.stdout
        except Exception:
            continue
    return False, ""

def dump_xml():
    ok, out = sh("uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && cat /sdcard/ui.xml")
    if not ok:
        return None
    s = out.find("<?xml")
    if s < 0:
        s = out.find("<hierarchy")
    if s < 0:
        return None
    return out[s:]

def parse(xml):
    nodes = re.findall(r"<node\b([^>]*?)/?>", xml)
    res = []
    for n in nodes:
        def g(k):
            m = re.search(k + r'="([^"]*)"', n)
            return m.group(1) if m else ""
        b = g("bounds")
        parts = [int(x) for x in re.findall(r"-?\d+", b)]
        if len(parts) != 4:
            continue
        res.append({
            "text": g("text"), "desc": g("content-desc"),
            "id": g("resource-id"), "class": g("class"),
            "x": (parts[0] + parts[2]) // 2, "y": (parts[1] + parts[3]) // 2,
            "clickable": g("clickable") == "true", "focused": g("focused") == "true",
        })
    return res

def find_input(elems):
    """Return the element most likely to be the input field, else None."""
    for e in elems:
        if e["focused"]:
            return e, "focused"
    for e in elems:
        if "edit" in e["class"].lower() or "input" in e["class"].lower():
            return e, "edittext"
    return None, None

def tap(x, y):
    sh(f"input tap {x} {y}", timeout=5)

def current_ime():
    ok, out = sh("settings get secure default_input_method")
    return out.strip() if ok and out.strip() else None

def set_ime(ime):
    sh(f"ime enable {ime}")
    sh(f"ime set {ime}")

def is_adbkeyboard_installed():
    ok, out = sh("ime list -s")
    return ok and "adbkeyboard" in out.lower()

def has_non_ascii(s):
    return any(ord(c) > 127 for c in s)

def type_text(text):
    """Focus then type. Auto-routes ASCII vs Unicode, restores the original IME."""
    if not text:
        print("✗ 空文本")
        return 1

    # 1) focus input
    xml = dump_xml()
    if xml is None:
        print("✗ 拿不到 UI 树 (adb/rish 不可用)")
        return 2
    e, how = find_input(parse(xml))
    if e is None:
        print("✗ 读不到输入框 (黑盒 app，需截图视觉定位)")
        return 2
    tap(e["x"], e["y"])
    print(f"✓ 聚焦输入框 via {how} ({e['x']},{e['y']})")

    # 2) type
    if not has_non_ascii(text):
        sh(f"input text {text}")
        print(f"✓ 已输入 (ASCII): {text}")
        return 0

    # Unicode path
    if not is_adbkeyboard_installed():
        print("✗ 含中文/Unicode，但未装 ADBKeyBoard。")
        print("  装法: 下载 senzhk/ADBKeyBoard 的 APK 后 adb install，")
        print("  再 adb shell ime enable com.android.adbkeyboard/.AdbIME")
        return 2

    prev = current_ime()
    set_ime(ADBKEYBOARD_IME)
    b64 = base64.b64encode(text.encode("utf-8")).decode()
    sh(f"am broadcast -a ADB_INPUT_B64 --es msg {b64}")
    if prev and prev != ADBKEYBOARD_IME:
        set_ime(prev)
        print(f"✓ 已输入 (Unicode) 并切回原输入法 {prev}")
    else:
        print("✓ 已输入 (Unicode)")
    return 0

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    mode = sys.argv[1]

    if mode == "--type":
        if len(sys.argv) < 3:
            print("用法: ui-input.py --type \"文本\"")
            sys.exit(1)
        sys.exit(type_text(sys.argv[2]))

    if mode == "--focus":
        xml = dump_xml()
        if xml is None:
            print("✗ 拿不到 UI 树"); sys.exit(2)
        e, how = find_input(parse(xml))
        if e is None:
            print("✗ 读不到输入框 (黑盒 app)"); sys.exit(2)
        tap(e["x"], e["y"])
        print(f"✓ 聚焦输入框 via {how} ({e['x']},{e['y']})")
        sys.exit(0)

    if mode == "--find":
        kw = sys.argv[2] if len(sys.argv) > 2 else ""
        xml = dump_xml()
        if xml is None:
            print("✗ 拿不到 UI 树"); sys.exit(2)
        elems = parse(xml)
        hits = [e for e in elems if kw in e["text"] or kw in e["desc"] or kw in e["id"]] if kw else elems
        out = [{"idx": i, "text": e["text"], "desc": e["desc"], "id": e["id"],
                "class": e["class"], "x": e["x"], "y": e["y"], "clickable": e["clickable"]}
               for i, e in enumerate(hits[:15])]
        print(json.dumps(out, ensure_ascii=False, indent=2))
        sys.exit(0)

    print(__doc__)

if __name__ == "__main__":
    main()
