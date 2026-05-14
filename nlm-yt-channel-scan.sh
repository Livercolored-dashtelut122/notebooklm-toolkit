#!/bin/bash
# ============================================================
# NotebookLM YouTube Channel Category Scanner
# 채널의 재생목록별로 분류하여 선택적 import
# (NotebookLM AI Sidebar의 채널 카테고리 분류 기능 대체)
#
# 사용법:
#   nlm-yt-channel-scan.sh scan <channel_url>
#   nlm-yt-channel-scan.sh import-playlist <playlist_url> [--notebook <id>] [--limit <n>]
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

export PATH="$HOME/.venvs/gcp-automation/bin:$PATH"

usage() {
    echo "사용법:"
    echo "  $0 scan <channel_url>                              채널 재생목록 스캔"
    echo "  $0 import-playlist <playlist_url> [--notebook <id>] [--limit <n>]  특정 재생목록 import"
    exit 1
}

[[ $# -lt 2 ]] && usage

MODE="$1"
URL="$2"
shift 2

NOTEBOOK_ID=""
LIMIT=50

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notebook) NOTEBOOK_ID="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ============================================================
# 채널 스캔: 재생목록 목록 추출
# ============================================================
scan_channel() {
    local channel_url="$1"

    # 채널 URL에서 /playlists 탭으로 이동
    local PLAYLISTS_URL
    if [[ "$channel_url" == *"/playlists"* ]]; then
        PLAYLISTS_URL="$channel_url"
    elif [[ "$channel_url" == *"/@"* ]]; then
        PLAYLISTS_URL="${channel_url%/}/playlists"
    elif [[ "$channel_url" == *"/c/"* ]] || [[ "$channel_url" == *"/channel/"* ]]; then
        PLAYLISTS_URL="${channel_url%/}/playlists"
    else
        PLAYLISTS_URL="${channel_url}/playlists"
    fi

    echo -e "${BLUE}🔍 채널 재생목록 스캔 중: $channel_url${NC}" >&2

    # 채널 이름 가져오기
    local CHANNEL_NAME
    CHANNEL_NAME=$(yt-dlp --print "%(channel)s" --playlist-items 1 --no-warnings "$channel_url" 2>/dev/null || echo "Unknown Channel")

    echo -e "${GREEN}📺 채널: $CHANNEL_NAME${NC}" >&2

    # yt-dlp로 재생목록 탭에서 재생목록 추출
    local PLAYLISTS
    PLAYLISTS=$(yt-dlp --flat-playlist -j \
        --no-warnings "$PLAYLISTS_URL" 2>/dev/null | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    item = json.loads(line)
    pl_id = item.get('id','')
    title = item.get('title','')
    count = item.get('playlist_count', '') or '?'
    print(f'{pl_id}\t{title}\t{count}')
" 2>/dev/null || echo "")

    if [[ -z "$PLAYLISTS" ]]; then
        echo -e "${YELLOW}⚠️  재생목록 탭에서 추출 실패. 개별 영상 모드로 전환...${NC}" >&2
        # fallback: 채널의 전체 영상 수만 표시
        local VIDEO_COUNT
        VIDEO_COUNT=$(yt-dlp --flat-playlist --print "%(id)s" --no-warnings "$channel_url" 2>/dev/null | wc -l | tr -d ' ')
        echo ""
        echo "=== 채널: $CHANNEL_NAME ==="
        echo ""
        echo "  재생목록을 추출할 수 없습니다."
        echo "  전체 영상 수: ${VIDEO_COUNT}개"
        echo ""
        echo "  전체 영상 import:"
        echo "    nlm-youtube-bulk.sh channel \"$channel_url\" --limit $LIMIT"
        return
    fi

    local PL_COUNT
    PL_COUNT=$(echo "$PLAYLISTS" | wc -l | tr -d ' ')

    echo ""
    echo "=== 채널: $CHANNEL_NAME — 재생목록 ${PL_COUNT}개 ==="
    echo ""

    local IDX=0
    while IFS=$'\t' read -r pl_id pl_title pl_count; do
        IDX=$((IDX + 1))
        local COUNT_DISPLAY="${pl_count:-?}"
        echo "  ${IDX}. 📋 ${pl_title} (${COUNT_DISPLAY}개)"
        echo "     https://www.youtube.com/playlist?list=${pl_id}"
        echo "     → import: nlm-yt-channel-scan.sh import-playlist \"https://www.youtube.com/playlist?list=${pl_id}\" --notebook <id>"
        echo ""
    done <<< "$PLAYLISTS"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  총 ${PL_COUNT}개 재생목록"
    echo ""
    echo "  특정 재생목록만 import하려면:"
    echo "    $0 import-playlist \"<playlist_url>\" --notebook <id>"
    echo ""
    echo "  전체 영상 import하려면:"
    echo "    ~/.claude/skills/notebooklm-plus/nlm-youtube-bulk.sh channel \"$channel_url\" --limit $LIMIT"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================
# 특정 재생목록 import
# ============================================================
import_playlist() {
    local pl_url="$1"
    # 기존 nlm-youtube-bulk.sh에 위임
    local SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    exec "$SCRIPT_DIR/nlm-youtube-bulk.sh" playlist "$pl_url" \
        ${NOTEBOOK_ID:+--notebook "$NOTEBOOK_ID"} --limit "$LIMIT"
}

# ============================================================
# 실행
# ============================================================
case "$MODE" in
    scan)
        scan_channel "$URL"
        ;;
    import-playlist)
        import_playlist "$URL"
        ;;
    *)
        usage
        ;;
esac
