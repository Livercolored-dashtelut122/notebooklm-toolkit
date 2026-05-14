#!/bin/bash
# ============================================================
# NotebookLM YouTube Search & Import
# YouTube 검색결과를 NotebookLM에 일괄 추가
# (YouTube to NotebookLM 크롬확장의 검색결과 전송 기능 대체)
#
# 사용법:
#   nlm-yt-search.sh list "검색어" [--limit <n>]
#   nlm-yt-search.sh import "검색어" [--notebook <id>] [--limit <n>]
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
    echo "  $0 list \"검색어\" [--limit <n>]"
    echo "  $0 import \"검색어\" [--notebook <id>] [--limit <n>]"
    echo ""
    echo "옵션:"
    echo "  --notebook <id>  대상 노트북 ID"
    echo "  --limit <n>      최대 결과 수 (기본: 10)"
    echo "  --sort <option>  정렬: relevance(기본), date, views, rating"
    exit 1
}

[[ $# -lt 2 ]] && usage

MODE="$1"
QUERY="$2"
shift 2

NOTEBOOK_ID=""
LIMIT=10
SORT="relevance"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notebook) NOTEBOOK_ID="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --sort) SORT="$2"; shift 2 ;;
        *) echo "알 수 없는 옵션: $1"; usage ;;
    esac
done

# yt-dlp 정렬 옵션 매핑
SORT_FLAG=""
case "$SORT" in
    date) SORT_FLAG="--playlist-reverse" ;;
    views) SORT_FLAG="" ;;  # yt-dlp는 기본 relevance
    *) SORT_FLAG="" ;;
esac

echo -e "${BLUE}🔍 YouTube 검색: \"$QUERY\" (최대 $LIMIT개)${NC}" >&2

# yt-dlp JSON → 탭 구분 변환
RESULTS=$(yt-dlp --flat-playlist -j \
    --playlist-end "$LIMIT" --no-warnings $SORT_FLAG \
    "ytsearch${LIMIT}:${QUERY}" 2>/dev/null | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    item = json.loads(line)
    vid_id = item.get('id','')
    title = item.get('title','')
    dur = item.get('duration_string','')
    views = item.get('view_count', 0) or 0
    print(f'{vid_id}\t{title}\t{dur}\t{views}')
")

if [[ -z "$RESULTS" ]]; then
    echo -e "${RED}❌ 검색 결과가 없습니다.${NC}"
    exit 1
fi

COUNT=$(echo "$RESULTS" | wc -l | tr -d ' ')
echo -e "${GREEN}✅ ${COUNT}개 결과${NC}"

if [[ "$MODE" == "list" ]]; then
    echo ""
    echo "=== YouTube 검색 결과: \"$QUERY\" ==="
    IDX=0
    while IFS=$'\t' read -r vid_id vid_title vid_duration vid_views; do
        IDX=$((IDX + 1))
        # 조회수 포맷
        if [[ -n "$vid_views" ]] && [[ "$vid_views" != "NA" ]] && [[ "$vid_views" != "None" ]]; then
            VIEWS_FMT=$(printf "%'d" "$vid_views" 2>/dev/null || echo "$vid_views")
        else
            VIEWS_FMT="N/A"
        fi
        TITLE_SHORT="${vid_title:0:55}"
        [[ ${#vid_title} -gt 55 ]] && TITLE_SHORT="${TITLE_SHORT}..."
        echo "  ${IDX}. ${TITLE_SHORT}"
        echo "     ${vid_duration:-??:??} | 조회 ${VIEWS_FMT} | https://youtu.be/${vid_id}"
    done <<< "$RESULTS"
    echo ""
    echo "총 ${COUNT}개"
    exit 0
fi

# Import 모드
echo ""
echo -e "${BLUE}📥 NotebookLM에 추가 시작 (${COUNT}개)...${NC}"

NB_FLAG=""
if [[ -n "$NOTEBOOK_ID" ]]; then
    NB_FLAG="--notebook $NOTEBOOK_ID"
fi

SUCCESS=0
FAIL=0
IDX=0

while IFS=$'\t' read -r vid_id vid_title vid_duration vid_views; do
    IDX=$((IDX + 1))
    TITLE_SHORT="${vid_title:0:50}"
    [[ ${#vid_title} -gt 50 ]] && TITLE_SHORT="${TITLE_SHORT}..."
    echo -n "  [$IDX/$COUNT] $TITLE_SHORT ... "

    VIDEO_URL="https://www.youtube.com/watch?v=$vid_id"
    if notebooklm source add "$VIDEO_URL" $NB_FLAG --json 2>/dev/null | grep -q "source_id"; then
        echo -e "${GREEN}✅${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${RED}❌${NC}"
        FAIL=$((FAIL + 1))
    fi
    sleep 1
done <<< "$RESULTS"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}성공: $SUCCESS${NC}"
echo -e "  ${RED}실패: $FAIL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
