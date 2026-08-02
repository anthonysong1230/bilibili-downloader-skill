#!/usr/bin/env bash
# =====================================================================
# bilibili-dl.sh - B站音频/视频下载脚本 (Minis / iSH - Alpine Linux)
# 基于 yt-dlp，内置 B站反爬(412)规避参数 + buvid cookie 自动获取
#
# 用法:
#   bilibili-dl.sh <视频URL|BV号> [audio|video|list] [输出目录] [容器mp4|mkv] [最高分辨率]
#
# 模式: audio(默认,只要音频) | video(视频+音频合并) | list(批量UP主)
# 分辨率: 480(默认游客) | 720 | 1080  (720+ 需登录, 见 bilibili-login.sh)
#
# video 模式说明:
#   分两次下载视频流和音频流(避免一次多格式触发 yt-dlp 自动 merge 崩溃),
#   再用独立 ffmpeg 手动合并。规避 iSH 环境 yt-dlp 后处理的 bug。
# =====================================================================
set -euo pipefail

# ---------- 配置 ----------
WORK="${HOME:-/root}/B站音频下载"
YTDLP="$(command -v yt-dlp)"
FFMPEG="$(command -v ffmpeg)"
BUFILE="${HOME:-/root}/.cache/bilibili-buvid.txt"
LOGINFILE="${HOME:-/root}/.cache/bilibili-login-cookies.txt"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
mkdir -p "$WORK" "${HOME:-/root}/.cache"

# ---------- 分辨率映射 ----------
# 480=游客, 720=登录级, 1080=登录级
# ⚠️ AV1 规避: 优先选 H.264(avc1) 编码, 否则 iSH 精简 ffmpeg 无法解码 AV1 会转码失败
RES_MAX="${5:-480}"
case "$RES_MAX" in
    1080|720) RES_EXPR="bv*[height<=${RES_MAX}][vcodec~='^avc']/bv*[height<=${RES_MAX}]" ;;
    *)        RES_EXPR="bv*[height<=480][vcodec~='^avc']/bv*[height<=480]" ;;
esac

# ---------- cookies 准备: 优选登录, 回落 buvid ----------
get_cookies() {
    local ck=""
    if [[ -s "$LOGINFILE" ]]; then
        ck="$LOGINFILE"
        echo ">>> 使用登录 cookies (高清可用)" >&2
    else
        # 生成 buvid (若没有)
        if [[ ! -s "$BUFILE" ]]; then
            echo ">>> 获取 buvid cookie..." >&2
            curl -s -c "$BUFILE" -A "$UA" "https://www.bilibili.com/" -o /dev/null
            chmod 600 "$BUFILE" 2>/dev/null || true
        fi
        ck="$BUFILE"
    fi
    echo "$ck"
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

# ---------- 读取标题 ----------
fetch_title() {
    local url="$1" ck="$2"
    shift 2
    local extra=("$@")
    yt-dlp "${ARGS[@]}" --cookies "$ck" "${extra[@]}" --skip-download --print "%(title)s" "$url" 2>/dev/null
}

# ---------- 视频+音频下载并合并 ----------
download_video() {
    local url="$1" outdir="$2" ck="$3"
    local part_num="${5:-}"
    local p_args=()
    local title vfile afile out
    : > "$outdir/.running"

    if [[ -n "$part_num" && "$part_num" != "all" ]]; then
        p_args=(--playlist-items "$part_num")
    fi

    title="$(fetch_title "$url" "$ck" "${p_args[@]}" | head -1 || true)"
    title="$(safe_name "${title:-video}")"
    echo ">>> 标题: $title"

    echo ">>> [1/2] 下载视频流 (max ${RES_MAX}p)..."
    yt-dlp "${ARGS[@]}" --cookies "$ck" "${p_args[@]}" \
        -o "$outdir/video_part.%(ext)s" \
        -f "${RES_EXPR}/b[height<=${RES_MAX}]" \
        "$url"

    echo ">>> [2/2] 下载音频流..."
    yt-dlp "${ARGS[@]}" --cookies "$ck" "${p_args[@]}" \
        -o "$outdir/audio_part.%(ext)s" \
        -f "ba/b[height<=${RES_MAX}]" \
        "$url"

    vfile="$(ls -t "$outdir"/video_part.* 2>/dev/null | head -1)"
    afile="$(ls -t "$outdir"/audio_part.* 2>/dev/null | head -1)"

    if [[ -z "$vfile" || -z "$afile" ]]; then
        echo "ERROR: 流下载不完整 video='${vfile:-无}' audio='${afile:-无}'" >&2
        return 1
    fi

    local container="${4:-mp4}"
    out="${outdir}/${title}.${container}"
    if [[ -n "$part_num" && "$part_num" != "all" ]]; then
        out="${outdir}/P${part_num}_${title}.${container}"
    fi
    echo ">>> 合并 → $title.$container"
    echo "    视频: $(basename "$vfile") ($(du -h "$vfile"|cut -f1))"
    echo "    音频: $(basename "$afile") ($(du -h "$afile"|cut -f1))"

    # 检测视频流编码
    local vcodec="unknown"
    vcodec="$( "$FFMPEG" -i "$vfile" 2>&1 | grep -oaE 'Video: [a-z0-9_]+' | head -1 | sed 's/Video: //' || true )"
    echo "    诊断: 视频流编码=${vcodec}"

    case "$container" in
        mkv)
            "$FFMPEG" -y -i "$vfile" -i "$afile" -c copy "$out" 2>&1 | tail -3
            ;;
        *)
            if [[ "$vcodec" == h264 || "$vcodec" == *avc* ]]; then
                "$FFMPEG" -y -i "$vfile" -i "$afile" \
                    -map 0:v:0 -map 1:a:0 \
                    -c:v copy -c:a copy -movflags +faststart \
                    "$out" 2>&1 | tail -3
            else
                local H264_ENC="" ENCODERS
                ENCODERS="$("$FFMPEG" -hide_banner -encoders 2>/dev/null)"
                if [[ "$ENCODERS" == *libx264* ]]; then
                    H264_ENC=libx264
                elif [[ "$ENCODERS" == *h264_videotoolbox* ]]; then
                    H264_ENC=h264_videotoolbox
                fi
                if [[ -n "$H264_ENC" ]]; then
                    echo "    ⚠️ 视频流是 ${vcodec}, 尝试用 ${H264_ENC} 转码为 H.264..."
                    if [[ "$H264_ENC" == "libx264" ]]; then
                        "$FFMPEG" -y -i "$vfile" -i "$afile" \
                            -map 0:v:0 -map 1:a:0 \
                            -c:v libx264 -preset fast -crf 26 -maxrate 1200k -bufsize 2400k \
                            -c:a aac -b:a 96k -movflags +faststart "$out" 2>&1 | tail -3
                    else
                        "$FFMPEG" -y -i "$vfile" -i "$afile" \
                            -map 0:v:0 -map 1:a:0 \
                            -c:v h264_videotoolbox -b:v 1200k \
                            -c:a aac -b:a 96k -movflags +faststart "$out" 2>&1 | tail -3
                    fi
                    # 验证转码结果: 必须同时有视频+音频流, 否则回退
                    local has_video
                    has_video="$("$FFMPEG" -i "$out" 2>&1 | grep -c 'Video:')"
                    if [[ "$has_video" -eq 0 || ! -s "$out" ]]; then
                        echo "    ⚠️ ${H264_ENC} 转码失败(解码器不支持${vcodec}), 尝试重新下载 avc(H.264) 视频流..."
                        rm -f "$out"
                        local vfile2=""
                        yt-dlp "${ARGS[@]}" --cookies "$ck" \
                            -o "$outdir/video_part_avc.%(ext)s" \
                            -f "bv*[vcodec~='^avc'][height<=${RES_MAX}]/b[height<=${RES_MAX}]" \
                            "$url" 2>&1 | tail -2 || true
                        vfile2="$(ls -t "$outdir"/video_part_avc.* 2>/dev/null | head -1 || true)"
                        if [[ -n "$vfile2" ]]; then
                            echo "    ✅ 拿到 avc 流, 直接合并 (免转码)..."
                            "$FFMPEG" -y -i "$vfile2" -i "$afile" \
                                -map 0:v:0 -map 1:a:0 \
                                -c:v copy -c:a copy -movflags +faststart "$out" 2>&1 | tail -3
                            rm -f "$vfile2"
                        else
                            echo "    ⚠️ 无 avc 流可用, 回退原样复制 ${vcodec} 流。"
                            "$FFMPEG" -y -i "$vfile" -i "$afile" \
                                -map 0:v:0 -map 1:a:0 \
                                -c:v copy -c:a copy -movflags +faststart "$out" 2>&1 | tail -3
                            echo "    ⚠️ 结果是 ${vcodec} 编码, 需现代播放器(VLC/mpv)或装完整ffmpeg转H264。" >&2
                        fi
                    fi
                else
                    echo "    ⚠️ 无 H264 编码器, 原样复制 ${vcodec} 流。请装完整 ffmpeg。" >&2
                    "$FFMPEG" -y -i "$vfile" -i "$afile" \
                        -map 0:v:0 -map 1:a:0 \
                        -c:v copy -c:a copy -movflags +faststart "$out" 2>&1 | tail -3
                fi
            fi
            ;;
    esac

    rm -f "$vfile" "$afile" "$outdir/.running"
    if [[ -f "$out" ]]; then
        echo ">>> ✅ 已生成: $out ($(du -h "$out"|cut -f1))"
    else
        echo ">>> ⚠️ 合并产物不存在" >&2; return 1
    fi
}

# ---------- 主逻辑 ----------
[[ $# -lt 1 ]] && {
    echo "用法: bilibili-dl.sh <URL|BV号> [audio|video|list] [输出目录] [容器mp4|mkv] [分辨率480|720|1080] [分P号]" >&2
    echo "提示: 720P+ 需先登录 → 运行 bilibili-login.sh" >&2
    exit 1
}

INPUT="$1"
MODE="${2:-audio}"
OUTDIR="${3:-$WORK}"
CONTAINER="${4:-mp4}"
RES_MAX="${5:-480}"
PART_NUM="${6:-}"   # 可选: 多P视频指定P号, 空=第1P; all=全部分P

URL="$(normalize_url "$INPUT")"
CK="$(get_cookies)"
echo "============================================"
echo " B站下载 | 模式: $MODE"
echo " 目标  : $URL"
echo " 输出  : $OUTDIR"
echo " 分辨率: ${RES_MAX}p"
[[ -n "$PART_NUM" ]] && echo " 分P   : $PART_NUM"
echo "============================================"

mkdir -p "$OUTDIR"

# 分P参数: 指定P号时附加 --playlist-items
PLAYLIST_ARGS=()
if [[ -n "$PART_NUM" && "$PART_NUM" != "all" ]]; then
    PLAYLIST_ARGS=(--playlist-items "$PART_NUM")
fi

# 公共参数数组
ARGS=(
    --user-agent "$UA"
    --add-header "Referer:https://www.bilibili.com/"
    --add-header "Origin:https://www.bilibili.com"
    --extractor-args "bilibili:player_client=web"
    --retries 8 --fragment-retries 8 --no-mtime
)

case "$MODE" in
    audio|a)
        echo ">>> 下载音频..."
        yt-dlp "${ARGS[@]}" --cookies "$CK" "${PLAYLIST_ARGS[@]}" \
            -o "$OUTDIR/%(playlist_index)s_%(title)s.%(ext)s" \
            -f "ba/b[height<=${RES_MAX}]" \
            "$URL"
        ;;
    video|v)
        download_video "$URL" "$OUTDIR" "$CK" "$CONTAINER" "$PART_NUM"
        ;;
    list|l)
        [[ "$URL" =~ space\.bilibili\.com ]] || {
            echo "list 模式需要 UP主空间链接" >&2; exit 2
        }
        echo ">>> 批量下载 UP主视频 > ${RES_MAX}p..."
        yt-dlp "${ARGS[@]}" --cookies "$CK" \
            -o "$OUTDIR/%(title)s.%(ext)s" \
            -f "ba/b[height<=${RES_MAX}]" \
            --download-archive "$OUTDIR/archive.txt" \
            --sleep-interval 3 --max-sleep-interval 6 \
            --concurrent-fragments 8 \
            "$URL"
        ;;
    *)
        echo "未知模式: $MODE (audio/video/list)" >&2; exit 2
        ;;
esac

echo ""
echo "============================================"
echo " ✅ 完成！文件在: $OUTDIR"
echo "============================================"
ls -lh "$OUTDIR" | tail -10
