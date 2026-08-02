#!/usr/bin/env bash
# =====================================================================
# bilibili-formats.sh - 查询B站视频可用格式 (Minis / iSH - Alpine Linux)
# 内置完整反爬参数(buvid/登录cookies + UA + Referer + Origin + player_client),
# 避免裸调 yt-dlp -F 触发 HTTP 412。输出简洁: 最高分辨率 + H.264最高档 + 完整列表
#
# 用法:
#   bilibili-formats.sh "<URL|BV号>"
# 示例:
#   bilibili-formats.sh "BV1QJ4m1j7oz"
# =====================================================================
set -euo pipefail

INPUT="${1:-}"
[[ -z "$INPUT" ]] && { echo "用法: bilibili-formats.sh \"<URL|BV号>\"" >&2; exit 1; }

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
    echo ">>> 使用登录 cookies" >&2
else
    if [[ ! -s "$BUFILE" ]]; then
        echo ">>> 获取 buvid cookie..." >&2
        curl -s -c "$BUFILE" -A "$UA" "https://www.bilibili.com/" -o /dev/null
        chmod 600 "$BUFILE" 2>/dev/null || true
    fi
    CK="$BUFILE"
fi

# ---------- 查询格式 ----------
echo ">>> 查询格式: $URL" >&2
RAW="$(yt-dlp \
    --user-agent "$UA" \
    --add-header "Referer:https://www.bilibili.com/" \
    --add-header "Origin:https://www.bilibili.com" \
    --extractor-args "bilibili:player_client=web" \
    --cookies "$CK" \
    --no-warnings -F "$URL" 2>&1 || true)"

# 412/风控检测
if echo "$RAW" | grep -qiE "412|HTTP Error|Unable to download|requested format"; then
    echo "ERROR: 查询被风控拦截(412)。不要反复重试; 若未登录先运行 bilibili-login.sh 登录后再查。" >&2
    exit 3
fi

echo "$RAW" | python3 -c "
import sys, re

raw = sys.stdin.read()
lines = [l for l in raw.splitlines() if l.strip()]
vids = []
auds = []
for l in lines:
    if 'audio only' in l:
        m = re.match(r'^\s*(\d+)\s+(\S+)\s+audio only', l)
        if m: auds.append(m.group(1))
        continue
    m = re.match(r'^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\d+)', l)
    if not m: continue
    fid, ext, res, fps = m.groups()
    codec = re.search(r'(avc1|av01|hev1|hvc1|mp4a)\.[0-9A-Za-z.]+', l)
    entry = (fid, res, fps, codec.group(1) if codec else '?')
    vids.append(entry)

if not vids:
    print('未解析到视频格式')
    sys.exit(0)

def h(v):
    # '540x360' → 360 ; '1920x1080' → 1080
    try: return int(v.split('x')[1])
    except: return 0
vids.sort(key=lambda e: h(e[1]))
max_res = max(h(e[1]) for e in vids)
h264 = [e for e in vids if e[3].startswith('avc1')]
h264_max = max((h(e[1]) for e in h264), default=0)

print('=== 视频格式 ===')
for fid, res, fps, codec in vids:
    mark = ' ← H.264' if codec.startswith('avc1') else (' ← HEVC' if codec.startswith(('hev1','hvc1')) else '')
    print(f'{fid:>6}  {res:<10} {fps}fps  {codec}{mark}')
print(f'音频: {len(auds)} 条')
print()
print(f'最高分辨率: {max_res}p')
print(f'H.264最高: {h264_max}p' + ('  (下载可免转码)' if h264_max else '  (无H.264, 需转码)'))
"
