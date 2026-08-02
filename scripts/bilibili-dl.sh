#!/usr/bin/env bash
# =====================================================================
# bilibili-dl.sh - B站音频/视频下载脚本 (Minis / iSH - Alpine Linux)
# 基于 yt-dlp，内置 B站反爬(412)规避参数 + buvid cookie 自动获取
#
# 用法:
#   bilibili-dl.sh <视频URL|BV号> [audio|video|list] [输出目录] [容器mp4|mkv]
#
# 模式: audio(默认,只要音频) | video(视频+音频合并) | list(批量UP主)
#
# video 模式说明:
#   分两次下载视频流和音频流(避免一次多格式触发 yt-dlp 自动 merge 崩溃),
#   再用独立 ffmpeg 手动合并。规避 iSH 环境 yt-dlp 后处理的 bug。
#   容器: mp4(H.264便于通用播放,默认) | mkv(AV1/HEVC)
# =====================================================================
set -euo pipefail

# ---------- 配置 ----------
WORK="${HOME:-/root}/B站音频下载"
YTDLP="$(command -v yt-dlp)"
FFMPEG="$(command -v ffmpeg)"
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

# ---------- 清理文件名中的危险字符 ----------
safe_name() {
    echo "$1" | tr -d '/\\:*?"<>|'
}

# ---------- 读取标题(从信息json) ----------
fetch_title() {
    local url="$1"
    yt-dlp "${ARGS[@]}" --skip-download --print "%(title)s" "$url" 2>/dev/null
}

# ---------- 视频+音频下载并手动合并 ----------
download_video() {
    local url="$1" outdir="$2" container="$3"
    local title vfile afile out
    : > "$outdir/.running"

    # 1) 获取干净标题
    title="$(fetch_title "$url" | head -1)"
    title="$(safe_name "${title:-video}")"
    echo ">>> 标题: $title"

    # 2) 分两次下载(单格式, 不触发 yt-dlp 自动 merge)
    echo ">>> [1/2] 下载视频流 (游客 max 480p)..."
    yt-dlp "${ARGS[@]}" \
        -o "$outdir/video_part.%(ext)s" \
        -f "bv*[height<=480]/b[height<=480]" \
        "$url"

    echo ">>> [2/2] 下载音频流..."
    yt-dlp "${ARGS[@]}" \
        -o "$outdir/audio_part.%(ext)s" \
        -f "ba/b[height<=480]" \
        "$url"

    # 3) 定位分离文件
    vfile="$(ls -t "$outdir"/video_part.* 2>/dev/null | head -1)"
    afile="$(ls -t "$outdir"/audio_part.* 2>/dev/null | head -1)"

    if [[ -z "$vfile" || -z "$afile" ]]; then
        echo "ERROR: 流下载不完整 video='${vfile:-无}' audio='${afile:-无}'" >&2
        return 1
    fi

    out="${outdir}/${title}.${container}"
    echo ">>> 合并 → $title.$container"
    echo "    视频: $(basename "$vfile") ($(du -h "$vfile"|cut -f1))"
    echo "    音频: $(basename "$afile") ($(du -h "$afile"|cut -f1))"

    case "$container" in
        mkv)
            "$FFMPEG" -y -i "$vfile" -i "$afile" -c copy "$out" 2>&1 | tail -3
            ;;
        *) # mp4
            "$FFMPEG" -y -i "$vfile" -i "$afile" \
                -c:v copy -c:a copy -movflags +faststart \
                "$out" 2>&1 | tail -3
            ;;
    esac

    # 清理中间文件
    rm -f "$vfile" "$afile" "$outdir/.running"

    if [[ -f "$out" ]]; then
        echo ">>> ✅ 已生成: $out ($(du -h "$out"|cut -f1))"
    else
        echo ">>> ⚠️ 合并产物不存在, 保留中间文件供检查" >&2
        return 1
    fi
}

# ---------- 主逻辑 ----------
[[ $# -lt 1 ]] && {
    echo "用法: bilibili-dl.sh <URL|BV号> [audio|video|list] [输出目录] [容器mp4|mkv]" >&2
    exit 1
}

INPUT="$1"
MODE="${2:-audio}"
OUTDIR="${3:-$WORK}"
CONTAINER="${4:-mp4}"

URL="$(normalize_url "$INPUT")"
echo "============================================"
echo " B站下载 | 模式: $MODE"
echo " 目标  : $URL"
echo " 输出  : $OUTDIR"
echo "============================================"

mkdir -p "$OUTDIR"
get_buvid

# 公共参数数组
ARGS=(
    --user-agent "$UA"
    --add-header "Referer:https://www.bilibili.com/"
    --add-header "Origin:https://www.bilibili.com"
    --cookies "$COOKIE_FILE"
    --extractor-args "bilibili:player_client=web"
    --retries 8 --fragment-retries 8
    --no-mtime
)

case "$MODE" in
    audio|a)
        echo ">>> 下载音频..."
        yt-dlp "${ARGS[@]}" \
            -o "$OUTDIR/%(title)s.%(ext)s" \
            -f "ba/b[height<=480]" \
            "$URL"
        ;;
    video|v)
        download_video "$URL" "$OUTDIR" "$CONTAINER"
        ;;
    list|l)
        [[ "$URL" =~ space\.bilibili\.com ]] || {
            echo "list 模式需要 UP主空间链接" >&2; exit 2
        }
        echo ">>> 批量下载 UP主音频(间隔避免风控)..."
        yt-dlp "${ARGS[@]}" \
            -o "$OUTDIR/%(title)s.%(ext)s" \
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
