#!/usr/bin/env bash
# =====================================================================
# bilibili-dl.sh - B站音频/视频下载脚本 (Minis / iSH - Alpine Linux)
# 基于 yt-dlp，内置 B站反爬(412)规避参数 + buvid cookie 自动获取
#
# 用法:
#   bilibili-dl.sh <视频URL|BV号> [audio|video|list] [输出目录]
#
# 模式: audio(默认) | video | list(批量UP主)
# =====================================================================
set -euo pipefail

# ---------- 配置 ----------
WORK="${HOME:-/root}/B站音频下载"
YTDLP="$(command -v yt-dlp)"
COOKIE_FILE="${HOME:-/root}/.cache/bilibili-buvid.txt"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
mkdir -p "$WORK" "${HOME:-/root}/.cache"

# ---------- 获取 buvid cookie (B站反爬必需) ----------
get_buvid() {
    if [[ -s "$COOKIE_FILE" ]]; then
        return 0
    fi
    echo ">>> 获取 buvid cookie..."
    curl -s -c "$COOKIE_FILE" \
        -A "$UA" \
        "https://www.bilibili.com/" -o /dev/null
    chmod 600 "$COOKIE_FILE" 2>/dev/null || true
    echo ">>> buvid cookie 已保存"
}

# ---------- 标准化 URL ----------
normalize_url() {
    local input="$1"
    if [[ "$input" =~ ^BV[0-9A-Za-z]{10,}$ ]]; then
        echo "https://www.bilibili.com/video/$input"
    elif [[ "$input" =~ b23\.tv ]]; then
        curl -s -o /dev/null --max-redirs 5 -A "$UA" -w "%{url_effective}" -L "$input"
    elif [[ "$input" =~ ^[0-9]{6,}$ ]]; then
        echo "https://space.bilibili.com/$input/video"
    else
        echo "$input"
    fi
}

# ---------- 主逻辑 ----------
[[ $# -lt 1 ]] && {
    echo "用法: bilibili-dl.sh <URL|BV号> [audio|video|list] [输出目录]" >&2
    exit 1
}

INPUT="$1"
MODE="${2:-audio}"
OUTDIR="${3:-$WORK}"

URL="$(normalize_url "$INPUT")"
echo "============================================"
echo " B站下载 | 模式: $MODE"
echo " 目标  : $URL"
echo " 输出  : $OUTDIR"
echo "============================================"

mkdir -p "$OUTDIR"
get_buvid
cd "$OUTDIR"

# 公共参数数组
ARGS=(
    --user-agent "$UA"
    --add-header "Referer:https://www.bilibili.com/"
    --add-header "Origin:https://www.bilibili.com"
    --cookies "$COOKIE_FILE"
    --extractor-args "bilibili:player_client=web"
    --retries 8 --fragment-retries 8
)

case "$MODE" in
    audio|a)
        echo ">>> 下载音频..."
        yt-dlp "${ARGS[@]}" \
            -o "%(title)s.%(ext)s" \
            -f "ba/b[height<=480]" \
            "$URL"
        ;;
    video|v)
        echo ">>> 下载视频(max 480p, 游客可用)..."
        yt-dlp "${ARGS[@]}" \
            -o "%(title)s.%(ext)s" \
            -f "bv*[height<=480]+ba/b[height<=480]" \
            --merge-output-format mkv \
            "$URL"
        ;;
    list|l)
        [[ "$URL" =~ space\.bilibili\.com ]] || {
            echo "list 模式需要 UP主空间链接" >&2; exit 2
        }
        echo ">>> 批量下载 UP主视频(间隔避免风控)..."
        yt-dlp "${ARGS[@]}" \
            -o "%(title)s.%(ext)s" \
            -f "ba/b[height<=480]" \
            --download-archive "$OUTDIR/archive.txt" \
            --sleep-interval 3 --max-sleep-interval 6 \
            --concurrent-fragments 8 \
            "$URL"
        ;;
    *)
        echo "未知模式: $MODE (可用: audio/video/list)" >&2; exit 2
        ;;
esac

echo ""
echo "============================================"
echo " ✅ 完成！文件在: $OUTDIR"
echo "============================================"
ls -lh "$OUTDIR" | tail -10
