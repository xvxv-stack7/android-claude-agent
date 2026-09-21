---
name: music-control
description: 音乐控制——搜索、选歌、播放指定歌曲，搭配AI主动放歌。使用时机：music_moment事件触发时，或用户说"放首歌"时。| Music control — search, select, and play specific songs via NetEase Cloud Music API. Use when: music_moment event fires, or user says "play a song".
---

# Music Control — Claude Code Skill

> ⚠️ **这个技能已经过时了 —— 音乐那套重写过了。**
>
> 新版走**虚拟副屏 + 酷狗**：不抢你的主屏、能读到你正听到哪一句、还带"主动陪你听歌"。
> 👉 **[android-claude-music](https://gitee.com/xvxv663/android-claude-music)**（[GitHub](https://github.com/xvxv-stack7/android-claude-music)）
>
> 下面这份是旧方案（网易云 API + mpv），留着给已经在跑的人做参考。

Play specific songs on Android via NetEase Cloud Music API + mpv. The AI can decide what to play — by mood, time, context — not just next/previous.

Powered by [NeteaseCloudMusicApiEnhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) (MIT License).

## Requirements

- Node.js (for API server) — already included in termux-shizuku environment
- mpv — `pkg install mpv`
- NetEase Cloud Music API — `npm install -g @neteasecloudmusicapienhanced/api`

## 🤖 AI Setup

```bash
# 1. Install mpv
pkg install -y mpv

# 2. Install API
npm install -g @neteasecloudmusicapienhanced/api

# 3. Start API server (background)
TMPDIR=/data/data/com.termux/files/usr/tmp nohup node /data/data/com.termux/files/usr/lib/node_modules/@neteasecloudmusicapienhanced/api/app.js > ~/ncm-api.log 2>&1 &

# 4. Test
curl -s "http://127.0.0.1:3000/search?keywords=测试" | head -1
```

## Commands

### Search for a song
```bash
# Shizuku
curl -s "http://127.0.0.1:3000/search?keywords=song+name+artist"
# Returns JSON with song list: id, name, artists, album, duration
```

### Get streaming URL
```bash
curl -s "http://127.0.0.1:3000/song/url/v1?id=SONG_ID&level=standard"
# Returns JSON with direct mp3 streaming URL
```

### Play a specific song
```bash
# Get URL and play (one-liner)
URL=$(curl -s "http://127.0.0.1:3000/song/url/v1?id=SONG_ID&level=standard" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['url'])")
nohup mpv --no-video "$URL" > /dev/null 2>&1 &
```

### Play by artist + song name
```bash
# Search → find best match → get URL → play
QUERY="TC 熄灭"
RESULT=$(curl -s "http://127.0.0.1:3000/search?keywords=$QUERY")
ID=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['songs'][0]['id'])")
URL=$(curl -s "http://127.0.0.1:3000/song/url/v1?id=$ID&level=standard" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['url'])")
nohup mpv --no-video "$URL" > /dev/null 2>&1 &
echo "Playing: $QUERY"
```

### Stop playback
```bash
kill $(pgrep -f "mpv")
```

## Composite Workflow: music_moment

When the `music_moment` event fires from gaze.sh (Bluetooth A2DP active + daytime + random 2%/loop):

```bash
# AI selects a song based on context (mood, time, weather, recent conversation)
# For example — late night + calm mood → pick a mellow song

# Search for the chosen song
curl -s "http://127.0.0.1:3000/search?keywords=TC%20熄灭" | python3 -c "
import json,sys
d=json.load(sys.stdin)
s=d['result']['songs'][0]
print(s['id'], s['name'], [a['name'] for a in s['ar']])
"

# Play it
URL=$(curl -s "http://127.0.0.1:3000/song/url/v1?id=2040015902&level=standard" | python3 -c "import json,sys; print(json.load(sys.stdin)['data'][0]['url'])")
nohup mpv --no-video "$URL" > /dev/null 2>&1 &

# Find lyrics and chat about it
# Use WebSearch to find the lyrics, then continue the conversation naturally
```

## AI Decision Guide

When choosing a song to play:

- **Late night (23:00-06:00)** → calm, mellow, instrumental
- **Morning (06:00-10:00)** → upbeat, energetic
- **Walking detected** (steps +200) → high tempo, motivating
- **Rainy weather** → cozy, acoustic
- **User mentioned an artist recently** → play that artist
- **User seems stressed/sad** → comforting, familiar

## Notes

- mpv plays in background with **no system media notification** — the phone won't show what's playing. This is intentional: the AI knows what it chose, no need to advertise.
- Streaming URLs expire after a few hours. Always get a fresh URL before playing.
- The API must be running before any music command. Start it once after boot: `nohup node .../app.js &`
- API server uses ~50MB RAM (Node.js). The Rust alternative `ncm-api-rs` uses ~5MB — consider upgrading for production use.

## Attribution

Powered by [NeteaseCloudMusicApiEnhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) v4.37.0 (MIT License). This skill provides integration guidance only — the API package is a separate open-source project maintained by its community.
