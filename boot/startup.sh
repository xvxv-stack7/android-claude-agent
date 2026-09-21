#!/data/data/com.termux/files/usr/bin/bash
# android-claude-agent 开机自启脚本
# 追加到 ~/.termux/boot/startup 或直接放 ~/.termux/boot/ 目录

echo "=== android-claude-agent 开机自启 ==="

(
  for i in $(seq 1 20); do
    if adb shell whoami > /dev/null 2>&1; then
      break
    fi
    sleep 3
  done

  adb tcpip 5555 2>&1
  sleep 2
  adb connect 127.0.0.1:5555 2>&1
  adb -s 127.0.0.1:5555 shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh 2>&1
  sleep 5

  if rish -c "whoami" > /dev/null 2>&1; then
    echo "$(date) shizuku boot OK ✅"
  else
    echo "$(date) shizuku boot FAIL ❌"
  fi
) &

