#!/bin/bash
#==============================================================================
# download_course.sh - 直播课程下载工具
#
# 用法:
#   ./download_course.sh <课程页面URL> [cookies文件] [输出目录]
#
# 示例:
#   ./download_course.sh "https://szb135927.livec.shangzhibo.tv/watch/11842299" cookies.txt ./videos
#   ./download_course.sh "https://xxx.livec.shangzhibo.tv/watch/12345"
#
#依赖:
#   - yt-dlp (pip install yt-dlp)
#   - curl
#   - ffprobe (optional, 用于验证)
#==============================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COOKIES_FILE="${SCRIPT_DIR}/cookies.txt"
OUTPUT_DIR="${SCRIPT_DIR}/videos"
TEMP_DIR="/tmp/zhibo-course-$$"

# 帮助信息
show_help() {
    cat << EOF
${GREEN}download_course.sh${NC} - 直播课程下载工具

${YELLOW}用法:${NC}
    $0 <课程页面URL> [cookies文件] [输出目录]

${YELLOW}参数:${NC}
    课程页面URL   必填  直播/录播课程页面地址
    cookies文件   可选  Netscape格式的cookies文件，默认为同目录下的cookies.txt
    输出目录     可选  视频保存目录，默认为当前目录

${YELLOW}示例:${NC}
    $0 "https://szb135927.livec.shangzhibo.tv/watch/11842299"
    $0 "https://xxx.livec.shangzhibo.tv/watch/12345" cookies.txt ./videos

${YELLOW}依赖:${NC}
    - yt-dlp    pip install yt-dlp
    - curl
    - ffprobe   可选，用于验证下载文件

EOF
    exit 0
}

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查依赖
check_deps() {
    local missing=()
    for cmd in curl yt-dlp; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "安装命令: pip install yt-dlp"
        exit 1
    fi
}

# 清理函数
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# 解析URL获取域名
get_domain() {
    echo "$1" | sed -E 's|https?://([^/]+).*|\1|'
}

# 解析播放列表名称
parse_playlist_name() {
    local url="$1"
    local domain=$(get_domain "$url")

    # 下载页面源码
    local page_content
    if [ -n "$COOKIES_FILE" ] && [ -f "$COOKIES_FILE" ]; then
        page_content=$(curl -s -L --cookie "$COOKIES_FILE" "$url")
    else
        page_content=$(curl -s -L "$url")
    fi

    # 提取播放列表名称
    local playlist_name=$(echo "$page_content" | grep -oE '"name":"[^"]+' | head -1 | sed 's/"name":"//')
    if [ -z "$playlist_name" ]; then
        playlist_name="course_$(date +%Y%m%d)"
    fi
    echo "$playlist_name"
}

# 提取m3u8列表
extract_m3u8_list() {
    local url="$1"
    local domain=$(get_domain "$url")

    # 下载页面源码
    local page_content
    if [ -n "$COOKIES_FILE" ] && [ -f "$COOKIES_FILE" ]; then
        page_content=$(curl -s -L --cookie "$COOKIES_FILE" "$url")
    else
        page_content=$(curl -s -L "$url")
    fi

    # 提取所有playlistPath（m3u8 URL）
    local m3u8_urls=$(echo "$page_content" | grep -oE '"playlistPath":"[^"]+\.m3u8"' | sed 's/"playlistPath":"//' | sed 's/"$//')

    # 提取所有playbackTitle
    local titles=$(echo "$page_content" | grep -oE '"playbackTitle":"[^"]*"' | sed 's/"playbackTitle":"//' | sed 's/"$//')

    # 使用paste组合（按顺序配对）
    paste <(echo "$m3u8_urls") <(echo "$titles") | while read -r m3u8_path title; do
        if [ -n "$m3u8_path" ]; then
            # 转换为完整URL并去除可能的不同步问题
            local full_url="https:${m3u8_path}"
            echo -e "${full_url}\t${title}"
        fi
    done | awk -F'\t' '!seen[$1]++' # 去重
}

# 下载单个视频
download_video() {
    local url="$1"
    local title="$2"
    local index="$3"
    local total="$4"
    local course_name="$5"

    # 构建文件名
    local safe_title=$(echo "$title" | sed 's/[<>:"\/\\|?*]/_/g')
    local output_file="${OUTPUT_DIR}/${course_name}_第${index}节_${safe_title}.mp4"

    # 跳过已存在的文件
    if [ -f "$output_file" ]; then
        log_warn "文件已存在，跳过: ${output_file}"
        return 0
    fi

    log_info "[${index}/${total}] 下载: ${title}"

    # 构建yt-dlp命令
    local ytdlp_cmd="yt-dlp --no-warnings -f 'best' -o '${output_file}' '${url}'"
    if [ -n "$COOKIES_FILE" ] && [ -f "$COOKIES_FILE" ]; then
        ytdlp_cmd="$ytdlp_cmd --cookies '$COOKIES_FILE'"
    fi

    # 执行下载
    eval "$ytdlp_cmd" 2>&1 | grep -v "^\[" || true

    # 验证下载
    if [ -f "$output_file" ]; then
        local duration=$(ffprobe -v error -show_entries format=duration -select_streams v:0 -of csv=p=0 "$output_file" 2>/dev/null || echo "0")
        if [ "$duration" != "0" ] && [ -n "$duration" ]; then
            log_success "完成: ${title} ($(echo "$duration/60" | bc -l | head -c 4)分钟)"
        else
            log_warn "下载可能不完整: ${title}"
        fi
    else
        log_error "下载失败: ${title}"
        return 1
    fi
}

# 主函数
main() {
    # 检查参数
    if [ $# -lt 1 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help
    fi

    local course_url="$1"
    if [ $# -ge 2 ]; then
        COOKIES_FILE="$2"
    fi
    if [ $# -ge 3 ]; then
        OUTPUT_DIR="$3"
    fi

    # 检查依赖
    check_deps

    # 创建临时目录
    mkdir -p "$TEMP_DIR"
    mkdir -p "$OUTPUT_DIR"

    # 解析课程名称
    log_info "分析课程页面..."
    local course_name=$(parse_playlist_name "$course_url")
    course_name=$(echo "$course_name" | sed 's/[<>:"\/\\|?*]/_/g')
    log_info "课程名称: ${course_name}"

    # 提取视频列表
    log_info "获取视频列表..."
    local m3u8_list=$(extract_m3u8_list "$course_url")

    if [ -z "$m3u8_list" ]; then
        log_error "未找到视频，请检查URL或cookies是否有效"
        exit 1
    fi

    # 转换为数组
    local video_count=$(echo "$m3u8_list" | wc -l)
    log_info "找到 ${video_count} 个视频"

    # 逐个下载
    local index=1
    echo "$m3u8_list" | while read line; do
        local url=$(echo "$line" | cut -f1)
        local title=$(echo "$line" | cut -f2)
        download_video "$url" "$title" "$index" "$video_count" "$course_name"
        index=$((index + 1))
    done

    log_success "下载完成！文件保存在: ${OUTPUT_DIR}"
    log_info "共 $(ls -1 "${OUTPUT_DIR}"/${course_name}_*.mp4 2>/dev/null | wc -l) 个文件"
}

# 运行
main "$@"