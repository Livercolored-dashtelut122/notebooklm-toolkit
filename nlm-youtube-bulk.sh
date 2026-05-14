#!/bin/bash
# ============================================================
# NotebookLM YouTube Bulk Importer
# YouTube 재생목록/채널의 영상을 NotebookLM에 일괄 추가
#
# 사용법:
#   nlm-youtube-bulk.sh playlist <playlist_url> [--notebook <id>] [--limit <n>]
#   nlm-youtube-bulk.sh channel <channel_url> [--notebook <id>] [--limit <n>]
#   nlm-youtube-bulk.sh list-only <playlist_or_channel_url> [--limit <n>]
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# PATH에 venv 추가
export PATH="$HOME/.venvs/gcp-automation/bin:$PATH"

usage() {
    echo "사용법:"
    echo "  $0 playlist <url> [--notebook <id>] [--limit <n>]"
    echo "  $0 channel <url> [--notebook <id>] [--limit <n>]"
    echo "  $0 list-only <url> [--limit <n>]"
    echo ""
    echo "옵션:"
    echo "  --notebook <id>  대상 노트북 ID (없으면 현재 컨텍스트 사용)"
    echo "  --limit <n>      최대 영상 수 (기본: 50)"
    echo "  --dry-run        URL만 출력, 실제 추가 안 함"
    exit 1
}

[[ $# -lt 2 ]] && usage

MODE="$1"
URL="$2"
shift 2

NOTEBOOK_ID=""
LIMIT=50
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notebook) NOTEBOOK_ID="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "알 수 없는 옵션: $1"; usage ;;
    esac
done

# yt-dlp로 URL 추출
echo -e "${BLUE}🔍 영상 목록 추출 중...${NC}"

URLS=$(yt-dlp --flat-playlist --print "https://www.youtube.com/watch?v=%(id)s" \
    --playlist-end "$LIMIT" --no-warnings "$URL" 2>/dev/null)

if [[ -z "$URLS" ]]; then
    echo -e "${RED}❌ 영상을 찾을 수 없습니다. URL을 확인해주세요.${NC}"
    exit 1
fi

COUNT=$(echo "$URLS" | wc -l | tr -d ' ')
echo -e "${GREEN}✅ ${COUNT}개 영상 발견${NC}"

if [[ "$MODE" == "list-only" ]] || [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "=== 영상 URL 목록 ==="
    echo "$URLS" | nl
    echo ""
    echo "총 ${COUNT}개"
    exit 0
fi

# NotebookLM에 추가
echo ""
echo -e "${BLUE}📥 NotebookLM에 추가 시작 (${COUNT}개)...${NC}"

NB_FLAG=""
if [[ -n "$NOTEBOOK_ID" ]]; then
    NB_FLAG="--notebook $NOTEBOOK_ID"
fi

SUCCESS=0
FAIL=0
IDX=0

while IFS= read -r video_url; do
    IDX=$((IDX + 1))
    echo -n "  [$IDX/$COUNT] $video_url ... "

    if notebooklm source add "$video_url" $NB_FLAG --json 2>/dev/null | grep -q "source_id"; then
        echo -e "${GREEN}✅${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${RED}❌${NC}"
        FAIL=$((FAIL + 1))
    fi

    # Rate limit 방지 (1초 대기)
    sleep 1
done <<< "$URLS"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}성공: $SUCCESS${NC}"
echo -e "  ${RED}실패: $FAIL${NC}"
echo -e "  총: $COUNT"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
