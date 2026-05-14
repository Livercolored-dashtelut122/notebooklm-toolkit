#!/bin/bash
# ============================================================
# NotebookLM Notebook Manager
# 크로스노트북 검색, 중복 스캔, 백업
# (NotebookLM Tools 크롬확장의 관리 기능 대체)
#
# 사용법:
#   nlm-notebook-manage.sh search "키워드"
#   nlm-notebook-manage.sh duplicates [--notebook <id>]
#   nlm-notebook-manage.sh backup [--output <dir>]
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
    echo "  $0 search \"키워드\"              크로스노트북 소스 검색"
    echo "  $0 duplicates [--notebook <id>]  중복 소스 스캔"
    echo "  $0 backup [--output <dir>]       노트북 메타데이터 백업"
    exit 1
}

[[ $# -lt 1 ]] && usage

MODE="$1"
shift

KEYWORD=""
NOTEBOOK_ID=""
OUTPUT_DIR="$HOME/Downloads/notebooklm-backup"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notebook) NOTEBOOK_ID="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        *)
            if [[ -z "$KEYWORD" ]]; then
                KEYWORD="$1"
            fi
            shift ;;
    esac
done

# ============================================================
# 크로스노트북 검색
# ============================================================
cross_search() {
    local query="$1"
    echo -e "${BLUE}🔍 전체 노트북에서 \"$query\" 검색 중...${NC}" >&2

    # 노트북 목록
    local NOTEBOOKS
    NOTEBOOKS=$(notebooklm list --json 2>/dev/null)

    if [[ -z "$NOTEBOOKS" ]] || [[ "$NOTEBOOKS" == *"error"* ]]; then
        echo -e "${RED}❌ 노트북 목록을 가져올 수 없습니다. 인증을 확인해주세요.${NC}"
        exit 1
    fi

    local NB_IDS
    NB_IDS=$(echo "$NOTEBOOKS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
notebooks = data.get('notebooks', [])
for nb in notebooks:
    print(nb['id'] + '\t' + nb.get('title', 'Untitled'))
")

    if [[ -z "$NB_IDS" ]]; then
        echo -e "${YELLOW}⚠️  노트북이 없습니다.${NC}"
        exit 0
    fi

    local TOTAL_MATCHES=0
    local QUERY_LOWER
    QUERY_LOWER=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    echo ""
    echo "=== 크로스노트북 검색: \"$query\" ==="
    echo ""

    while IFS=$'\t' read -r nb_id nb_title; do
        # 각 노트북의 소스 목록 가져오기
        local SOURCES
        SOURCES=$(notebooklm source list --notebook "$nb_id" --json 2>/dev/null || echo "")

        if [[ -z "$SOURCES" ]]; then
            continue
        fi

        local MATCHES
        MATCHES=$(echo "$SOURCES" | python3 -c "
import json, sys
query = '${QUERY_LOWER}'.lower()
data = json.load(sys.stdin)
sources = data.get('sources', [])
matches = []
for s in sources:
    title = s.get('title', '').lower()
    if query in title:
        matches.append(s)
for m in matches:
    status = m.get('status', 'unknown')
    print(m.get('id','')[:8] + '  ' + m.get('title','') + '  [' + status + ']')
" 2>/dev/null || echo "")

        if [[ -n "$MATCHES" ]]; then
            local MATCH_COUNT
            MATCH_COUNT=$(echo "$MATCHES" | wc -l | tr -d ' ')
            TOTAL_MATCHES=$((TOTAL_MATCHES + MATCH_COUNT))
            echo -e "  ${GREEN}📓 $nb_title${NC} ($MATCH_COUNT건)"
            echo "$MATCHES" | sed 's/^/     /'
            echo ""
        fi
    done <<< "$NB_IDS"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  총 ${TOTAL_MATCHES}건 발견"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================
# 중복 소스 스캔
# ============================================================
scan_duplicates() {
    echo -e "${BLUE}🔍 중복 소스 스캔 중...${NC}" >&2

    local NOTEBOOKS
    if [[ -n "$NOTEBOOK_ID" ]]; then
        # 특정 노트북만
        echo -e "${BLUE}  대상: 노트북 $NOTEBOOK_ID${NC}" >&2
        local SOURCES
        SOURCES=$(notebooklm source list --notebook "$NOTEBOOK_ID" --json 2>/dev/null)
        echo "$SOURCES" | python3 -c "
import json, sys
from collections import Counter

data = json.load(sys.stdin)
sources = data.get('sources', [])
titles = [s.get('title', '') for s in sources]
dups = {t: c for t, c in Counter(titles).items() if c > 1}

if not dups:
    print('  중복 없음 ✅')
else:
    print(f'  ⚠️  {len(dups)}개 중복 발견:')
    for title, count in sorted(dups.items(), key=lambda x: -x[1]):
        print(f'    [{count}회] {title}')
"
    else
        # 전체 노트북
        NOTEBOOKS=$(notebooklm list --json 2>/dev/null)
        local NB_IDS
        NB_IDS=$(echo "$NOTEBOOKS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for nb in data.get('notebooks', []):
    print(nb['id'] + '\t' + nb.get('title', 'Untitled'))
")

        # 모든 소스를 수집
        ALL_SOURCES=""
        while IFS=$'\t' read -r nb_id nb_title; do
            local SOURCES
            SOURCES=$(notebooklm source list --notebook "$nb_id" --json 2>/dev/null || echo "")
            if [[ -n "$SOURCES" ]]; then
                local SRC_TITLES
                SRC_TITLES=$(echo "$SOURCES" | python3 -c "
import json, sys
data = json.load(sys.stdin)
nb_title = '${nb_title}'
for s in data.get('sources', []):
    print(nb_title + '\t' + s.get('title', '') + '\t' + s.get('id', ''))
" 2>/dev/null || echo "")
                if [[ -n "$SRC_TITLES" ]]; then
                    ALL_SOURCES="${ALL_SOURCES}${SRC_TITLES}"$'\n'
                fi
            fi
        done <<< "$NB_IDS"

        echo ""
        echo "=== 중복 소스 스캔 결과 ==="
        echo ""

        echo "$ALL_SOURCES" | python3 -c "
import sys
from collections import defaultdict

lines = [l.strip() for l in sys.stdin if l.strip()]
title_map = defaultdict(list)

for line in lines:
    parts = line.split('\t')
    if len(parts) >= 3:
        nb_title, src_title, src_id = parts[0], parts[1], parts[2]
        if src_title:
            title_map[src_title].append(nb_title)

dups = {t: nbs for t, nbs in title_map.items() if len(nbs) > 1}

if not dups:
    print('  중복 없음 ✅')
else:
    # 노트북 간 중복
    cross_dups = {t: nbs for t, nbs in dups.items() if len(set(nbs)) > 1}
    same_dups = {t: nbs for t, nbs in dups.items() if len(set(nbs)) == 1}

    if cross_dups:
        print(f'  🔴 노트북 간 중복 ({len(cross_dups)}개):')
        for title, nbs in sorted(cross_dups.items()):
            unique_nbs = list(set(nbs))
            print(f'    \"{title}\"')
            for nb in unique_nbs:
                count = nbs.count(nb)
                print(f'      → {nb} ({count}회)')
        print()

    if same_dups:
        print(f'  🟡 같은 노트북 내 중복 ({len(same_dups)}개):')
        for title, nbs in sorted(same_dups.items()):
            print(f'    [{len(nbs)}회] \"{title}\" in {nbs[0]}')
"
    fi
}

# ============================================================
# 백업
# ============================================================
backup_notebooks() {
    echo -e "${BLUE}💾 노트북 백업 시작...${NC}" >&2

    mkdir -p "$OUTPUT_DIR"

    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_FILE="$OUTPUT_DIR/notebooklm_backup_${TIMESTAMP}.json"

    echo -e "${BLUE}  노트북 목록 수집 중...${NC}" >&2
    local NOTEBOOKS
    NOTEBOOKS=$(notebooklm list --json 2>/dev/null)

    local NB_IDS
    NB_IDS=$(echo "$NOTEBOOKS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for nb in data.get('notebooks', []):
    print(nb['id'] + '\t' + nb.get('title', 'Untitled'))
")

    local NB_COUNT
    NB_COUNT=$(echo "$NB_IDS" | wc -l | tr -d ' ')
    echo -e "${GREEN}  ${NB_COUNT}개 노트북 발견${NC}" >&2

    # 전체 백업 데이터 수집
    python3 << PYEOF > "$BACKUP_FILE"
import json, subprocess, sys
from datetime import datetime

backup = {
    "backup_date": datetime.now().isoformat(),
    "backup_type": "notebooklm-plus",
    "notebooks": []
}

# 노트북 목록
notebooks_raw = json.loads('''$NOTEBOOKS''')
notebooks = notebooks_raw.get('notebooks', [])

for i, nb in enumerate(notebooks, 1):
    nb_id = nb['id']
    nb_title = nb.get('title', 'Untitled')
    print(f"  [{i}/{len(notebooks)}] {nb_title}...", file=sys.stderr)

    nb_data = {
        "id": nb_id,
        "title": nb_title,
        "created_at": nb.get("created_at", ""),
        "sources": []
    }

    # 소스 목록
    try:
        result = subprocess.run(
            ["notebooklm", "source", "list", "--notebook", nb_id, "--json"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            sources = json.loads(result.stdout).get('sources', [])
            nb_data["sources"] = sources
            nb_data["source_count"] = len(sources)
    except:
        nb_data["sources"] = []
        nb_data["source_count"] = 0

    backup["notebooks"].append(nb_data)

backup["total_notebooks"] = len(notebooks)
backup["total_sources"] = sum(nb.get("source_count", 0) for nb in backup["notebooks"])

print(json.dumps(backup, ensure_ascii=False, indent=2))
PYEOF

    local FILE_SIZE
    FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1 | tr -d ' ')

    echo ""
    echo -e "${GREEN}✅ 백업 완료${NC}"
    echo -e "  파일: $BACKUP_FILE"
    echo -e "  크기: $FILE_SIZE"
    echo -e "  노트북: $NB_COUNT개"

    # 요약
    python3 -c "
import json
with open('$BACKUP_FILE') as f:
    data = json.load(f)
print(f'  소스 총: {data[\"total_sources\"]}개')
for nb in data['notebooks']:
    print(f'    📓 {nb[\"title\"]}: {nb.get(\"source_count\", 0)}개 소스')
"
}

# ============================================================
# 실행
# ============================================================
case "$MODE" in
    search)
        [[ -z "$KEYWORD" ]] && { echo -e "${RED}검색어를 입력해주세요.${NC}"; usage; }
        cross_search "$KEYWORD"
        ;;
    duplicates|dup)
        scan_duplicates
        ;;
    backup)
        backup_notebooks
        ;;
    *)
        usage
        ;;
esac
