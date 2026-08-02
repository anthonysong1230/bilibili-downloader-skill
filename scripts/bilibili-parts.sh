#!/usr/bin/env bash
# =====================================================================
# bilibili-parts.sh - 查询B站视频分P信息 (Minis / iSH - Alpine Linux)
# 内置完整反爬参数, 输出: 分P数 + 每P标题/时长/ID
#
# 用法:
#   bilibili-parts.sh "<URL|BV号>"
# 示例:
#   bilibili-parts.sh "BV1GV4y1W7vh"
# =====================================================================
set -euo pipefail

INPUT="${1:-}"
[[ -z "$INPUT" ]] && { echo "用法: bilibili-parts.sh \"<URL|BV号>\"" >&2; exit 1; }

HOME_DIR="${HOME:-/root}"
LOGINFILE="$HOME_DIR/.cache/bilibili-login-cookies.txt"
BUFILE="$HOME_DIR/.cache/bilibili-buvid.txt"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ---------- 标准化 URL ----------
URL="$INPUT"
if [[ "$URL" =~ ^BV[0-9A-Za-z]{10,}$ ]]; then
    URL="https://www.bilibili.com/video/$URL"
elif [[ "$URL" =~ b23\.tv ]]; then
    URL="$(curl -s -o /dev/null --max-redirs 5 -A "$UA" -w "%{url_effective}" -L "$URL")"
fi

# ---------- cookies: 登录优先, buvid 回落 ----------
CK=""
if [[ -s "$LOGINFILE" ]]; then
    CK="$LOGINFILE"
else
    if [[ ! -s "$BUFILE" ]]; then
        curl -s -c "$BUFILE" -A "$UA" "https://www.bilibili.com/" -o /dev/null
        chmod 600 "$BUFILE" 2>/dev/null || true
    fi
    CK="$BUFILE"
fi

# ---------- 查询分P ----------
echo ">>> 查询分P: $URL" >&2
RAW="$(yt-dlp \
    --user-agent "$UA" \
    --add-header "Referer:https://www.bilibili.com/" \
    --add-header "Origin:https://www.bilibili.com" \
    --extractor-args "bilibili:player_client=web" \
    --cookies "$CK" \
    --skip-download --print "%(playlist_index)s|%(title)s|%(id)s|%(duration)s" \
    "$URL" 2>&1)"

if echo "$RAW" | grep -qiE "412|HTTP Error|Unable to download"; then
    echo "ERROR: 查询被风控拦截(412)。不要反复重试; 若未登录先运行 bilibili-login.sh 登录后再查。" >&2
    exit 3
fi

echo "$RAW" | python3 -c "
import sys

lines = [l for l in sys.stdin.read().splitlines() if l.strip() and '|' in l and '[' not in l]
if not lines:
    print('单P视频(无分P)')
    sys.exit(0)

parts = []
for l in lines:
    idx, title, vid, dur = l.split('|', 3)
    parts.append((idx, title, vid, dur))

print(f'分P数: {len(parts)}')
for idx, title, vid, dur in parts:
    d = int(float(dur)) if dur.replace('.','',1).isdigit() else 0
    m, s = divmod(d, 60)
    print(f'P{idx} [{m}:{s:02d}] {title}  ({vid})')
print('END')
"
