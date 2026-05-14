#!/bin/bash
# ============================================================
# NotebookLM Web Link Extractor & Bulk Importer
# 웹페이지에서 링크를 추출하여 NotebookLM에 일괄 추가
# (Grabbit 크롬확장 대체)
#
# 사용법:
#   nlm-web-links.sh extract <page_url> [--filter <pattern>]
#   nlm-web-links.sh import <page_url> [--notebook <id>] [--filter <pattern>] [--limit <n>]
#   nlm-web-links.sh import-file <file_path> [--notebook <id>] [--limit <n>]
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
    echo "  $0 extract <page_url> [--filter <pattern>]"
    echo "  $0 import <page_url> [--notebook <id>] [--filter <pattern>] [--limit <n>]"
    echo "  $0 import-file <file_path> [--notebook <id>] [--limit <n>]"
    echo ""
    echo "옵션:"
    echo "  --filter <pattern>  URL 필터 (grep 패턴, 예: 'youtube.com|blog')"
    echo "  --notebook <id>     대상 노트북 ID"
    echo "  --limit <n>         최대 링크 수 (기본: 30)"
    echo "  --exclude <pattern> 제외할 URL 패턴 (예: 'login|signup|#')"
    exit 1
}

[[ $# -lt 2 ]] && usage

MODE="$1"
TARGET="$2"
shift 2

NOTEBOOK_ID=""
FILTER=""
EXCLUDE="(login|signup|logout|javascript:|mailto:|tel:|#$|\.css|\.js|\.png|\.jpg|\.gif|\.svg|\.ico)"
LIMIT=30

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notebook) NOTEBOOK_ID="$2"; shift 2 ;;
        --filter) FILTER="$2"; shift 2 ;;
        --exclude) EXCLUDE="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) echo "알 수 없는 옵션: $1"; usage ;;
    esac
done

extract_links() {
    local url="$1"
    echo -e "${BLUE}🔍 '$url' 에서 링크 추출 중...${NC}" >&2

    # r.jina.ai를 사용하여 웹페이지를 마크다운으로 변환 후 링크 추출
    # (백프롬 영상에서도 r.jina.ai를 꿀팁으로 소개)
    local CONTENT
    CONTENT=$(curl -sL "https://r.jina.ai/$url" 2>/dev/null)

    if [[ -z "$CONTENT" ]]; then
        # fallback: 직접 curl로 HTML 파싱
        CONTENT=$(curl -sL "$url" 2>/dev/null)
        echo "$CONTENT" | grep -oE 'href="https?://[^"]+"' | sed 's/href="//;s/"$//' | sort -u
    else
        # 마크다운에서 링크 추출
        echo "$CONTENT" | grep -oE 'https?://[^)>"'"'"' ]+' | sort -u
    fi
}

extract_from_file() {
    local filepath="$1"
    echo -e "${BLUE}🔍 파일에서 링크 추출 중: $filepath${NC}" >&2
    grep -oE 'https?://[^ <>"'"'"')]+' "$filepath" | sort -u
}

# 링크 추출
if [[ "$MODE" == "import-file" ]]; then
    LINKS=$(extract_from_file "$TARGET")
else
    LINKS=$(extract_links "$TARGET")
fi

# 필터 적용
if [[ -n "$FILTER" ]]; then
    LINKS=$(echo "$LINKS" | grep -iE "$FILTER" || true)
fi

# 제외 패턴 적용
if [[ -n "$EXCLUDE" ]]; then
    LINKS=$(echo "$LINKS" | grep -ivE "$EXCLUDE" || true)
fi

# 중복 제거 및 제한
LINKS=$(echo "$LINKS" | head -n "$LIMIT")

if [[ -z "$LINKS" ]]; then
    echo -e "${RED}❌ 추출된 링크가 없습니다.${NC}"
    exit 1
fi

COUNT=$(echo "$LINKS" | wc -l | tr -d ' ')
echo -e "${GREEN}✅ ${COUNT}개 링크 추출됨${NC}"

# extract 모드면 목록만 출력
if [[ "$MODE" == "extract" ]]; then
    echo ""
    echo "=== 추출된 링크 ==="
    echo "$LINKS" | nl
    echo ""
    echo "총 ${COUNT}개"
    echo ""
    echo "이 링크들을 NotebookLM에 추가하려면:"
    echo "  $0 import <url> --filter '<패턴>'"
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

while IFS= read -r link_url; do
    [[ -z "$link_url" ]] && continue
    IDX=$((IDX + 1))
    # URL을 짧게 표시 (60자 이하)
    DISPLAY_URL="${link_url:0:60}"
    [[ ${#link_url} -gt 60 ]] && DISPLAY_URL="${DISPLAY_URL}..."
    echo -n "  [$IDX/$COUNT] $DISPLAY_URL ... "

    if notebooklm source add "$link_url" $NB_FLAG --json 2>/dev/null | grep -q "source_id"; then
        echo -e "${GREEN}✅${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${RED}❌${NC}"
        FAIL=$((FAIL + 1))
    fi

    sleep 1
done <<< "$LINKS"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}성공: $SUCCESS${NC}"
echo -e "  ${RED}실패: $FAIL${NC}"
echo -e "  총: $COUNT"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
