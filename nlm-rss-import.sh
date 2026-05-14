#!/bin/bash
# ============================================================
# NotebookLM RSS Feed Importer
# RSS/Atom 피드에서 링크를 추출하여 NotebookLM에 일괄 추가
# (NotebookLM Web Importer 크롬확장의 RSS 기능 대체)
#
# 사용법:
#   nlm-rss-import.sh list <feed_url> [--limit <n>]
#   nlm-rss-import.sh import <feed_url> [--notebook <id>] [--limit <n>]
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
    echo "  $0 list <feed_url> [--limit <n>]"
    echo "  $0 import <feed_url> [--notebook <id>] [--limit <n>]"
    echo ""
    echo "옵션:"
    echo "  --notebook <id>  대상 노트북 ID"
    echo "  --limit <n>      최대 항목 수 (기본: 20)"
    echo "  --title-only     제목만 표시 (list 모드)"
    exit 1
}

[[ $# -lt 2 ]] && usage

MODE="$1"
FEED_URL="$2"
shift 2

NOTEBOOK_ID=""
LIMIT=20
TITLE_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notebook) NOTEBOOK_ID="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --title-only) TITLE_ONLY=true; shift ;;
        *) echo "알 수 없는 옵션: $1"; usage ;;
    esac
done

echo -e "${BLUE}🔍 RSS 피드 파싱 중: $FEED_URL${NC}" >&2

# RSS/Atom 피드 다운로드 및 파싱
FEED_CONTENT=$(curl -sL "$FEED_URL" 2>/dev/null)

if [[ -z "$FEED_CONTENT" ]]; then
    echo -e "${RED}❌ 피드를 가져올 수 없습니다.${NC}"
    exit 1
fi

# RSS <link> 또는 Atom <link href=""> 추출
# RSS 2.0: <item><link>URL</link><title>TITLE</title></item>
# Atom: <entry><link href="URL"/><title>TITLE</title></entry>

# 피드 타입 감지
if echo "$FEED_CONTENT" | grep -q "<feed"; then
    FEED_TYPE="atom"
else
    FEED_TYPE="rss"
fi

# Python으로 안전하게 파싱 (XML 파서 사용)
PARSED=$(echo "$FEED_CONTENT" | python3 -c '
import xml.etree.ElementTree as ET
import sys, json

feed_content = sys.stdin.read()
items = []

try:
    root = ET.fromstring(feed_content)
except ET.ParseError:
    print("PARSE_ERROR")
    sys.exit(1)

# Atom namespace
ns = {"atom": "http://www.w3.org/2005/Atom"}

# Try RSS 2.0
for item in root.findall(".//item"):
    link = item.findtext("link", "").strip()
    title = item.findtext("title", "").strip()
    if link:
        items.append({"url": link, "title": title})

# Try Atom
if not items:
    for entry in root.findall(".//atom:entry", ns):
        link_el = entry.find("atom:link[@rel=\"alternate\"]", ns)
        if link_el is None:
            link_el = entry.find("atom:link", ns)
        link = link_el.get("href", "").strip() if link_el is not None else ""
        title = entry.findtext("atom:title", "", ns).strip()
        if link:
            items.append({"url": link, "title": title})

    # Atom without namespace
    if not items:
        for entry in root.findall(".//entry"):
            link_el = entry.find("link[@rel=\"alternate\"]")
            if link_el is None:
                link_el = entry.find("link")
            link = link_el.get("href", "").strip() if link_el is not None else ""
            title = entry.findtext("title", "").strip()
            if link:
                items.append({"url": link, "title": title})

print(json.dumps(items))
')

if [[ "$PARSED" == "PARSE_ERROR" ]] || [[ -z "$PARSED" ]] || [[ "$PARSED" == "[]" ]]; then
    echo -e "${RED}❌ RSS 파싱 실패. 유효한 RSS/Atom 피드인지 확인해주세요.${NC}"
    exit 1
fi

COUNT=$(echo "$PARSED" | python3 -c "import json,sys; print(min(len(json.load(sys.stdin)), $LIMIT))")
echo -e "${GREEN}✅ ${COUNT}개 항목 발견${NC}"

if [[ "$MODE" == "list" ]]; then
    echo ""
    echo "=== RSS 피드 항목 ==="
    echo "$PARSED" | python3 -c "
import json, sys
items = json.load(sys.stdin)[:$LIMIT]
for i, item in enumerate(items, 1):
    title = item['title'][:60] + '...' if len(item['title']) > 60 else item['title']
    if $( [[ "$TITLE_ONLY" == true ]] && echo "True" || echo "False" ):
        print(f'  {i:3d}. {title}')
    else:
        print(f'  {i:3d}. {title}')
        print(f'       {item[\"url\"]}')
"
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

# Python에서 URL 목록만 추출
URLS=$(echo "$PARSED" | python3 -c "
import json, sys
items = json.load(sys.stdin)[:$LIMIT]
for item in items:
    print(item['url'])
")

SUCCESS=0
FAIL=0
IDX=0

while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    IDX=$((IDX + 1))
    DISPLAY_URL="${url:0:60}"
    [[ ${#url} -gt 60 ]] && DISPLAY_URL="${DISPLAY_URL}..."
    echo -n "  [$IDX/$COUNT] $DISPLAY_URL ... "

    if notebooklm source add "$url" $NB_FLAG --json 2>/dev/null | grep -q "source_id"; then
        echo -e "${GREEN}✅${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${RED}❌${NC}"
        FAIL=$((FAIL + 1))
    fi
    sleep 1
done <<< "$URLS"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}성공: $SUCCESS${NC}"
echo -e "  ${RED}실패: $FAIL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
