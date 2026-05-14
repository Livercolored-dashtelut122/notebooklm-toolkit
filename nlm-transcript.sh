#!/bin/bash
# ============================================================
# NotebookLM YouTube Transcript Downloader
# YouTube 영상의 자막/트랜스크립트를 다운로드
# (NotebookLM AI Sidebar의 트랜스크립트 다운로드 기능 대체)
#
# 사용법:
#   nlm-transcript.sh <youtube_url> [--lang <ko|en|ja>] [--format <txt|md|srt>] [--output <path>]
#   nlm-transcript.sh --playlist <playlist_url> [--lang <ko>] [--output-dir <dir>]
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo "사용법:"
    echo "  $0 <youtube_url> [--lang <code>] [--format <txt|md|srt>] [--output <path>]"
    echo "  $0 --playlist <playlist_url> [--lang <code>] [--output-dir <dir>]"
    echo ""
    echo "옵션:"
    echo "  --lang <code>       자막 언어 (기본: ko, 없으면 en 시도)"
    echo "  --format <fmt>      출력 형식: txt, md, srt (기본: txt)"
    echo "  --output <path>     출력 파일 경로"
    echo "  --output-dir <dir>  재생목록 출력 디렉토리"
    echo "  --timestamps        타임스탬프 포함 (기본: 제외)"
    echo "  --playlist <url>    재생목록 전체 트랜스크립트 다운로드"
    exit 1
}

[[ $# -lt 1 ]] && usage

# 인자 파싱
VIDEO_URL=""
PLAYLIST_URL=""
LANG="ko"
FORMAT="txt"
OUTPUT=""
OUTPUT_DIR="./transcripts"
TIMESTAMPS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang) LANG="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --timestamps) TIMESTAMPS=true; shift ;;
        --playlist) PLAYLIST_URL="$2"; shift 2 ;;
        -h|--help) usage ;;
        *)
            if [[ -z "$VIDEO_URL" ]]; then
                VIDEO_URL="$1"
            fi
            shift ;;
    esac
done

download_single() {
    local url="$1"
    local out_path="$2"

    # 영상 제목 가져오기
    local TITLE
    TITLE=$(yt-dlp --print "%(title)s" --no-warnings "$url" 2>/dev/null || echo "unknown")

    echo -e "${BLUE}📝 트랜스크립트 다운로드: ${TITLE}${NC}"

    # 임시 디렉토리
    local TMPDIR
    TMPDIR=$(mktemp -d)

    # 자막 다운로드 시도 (수동 자막 → 자동 자막 순)
    local SUB_FILE=""

    # 1차: 수동 자막 (ko, ko-orig 등)
    yt-dlp --write-subs --sub-langs "${LANG}*" --skip-download \
        --output "$TMPDIR/%(id)s" "$url" 2>/dev/null || true
    SUB_FILE=$(ls "$TMPDIR"/*.vtt 2>/dev/null | head -1 || true)

    # 2차: 자동 자막
    if [[ -z "$SUB_FILE" ]]; then
        yt-dlp --write-auto-subs --sub-langs "${LANG}" --skip-download \
            --output "$TMPDIR/%(id)s" "$url" 2>/dev/null || true
        SUB_FILE=$(ls "$TMPDIR"/*.vtt 2>/dev/null | head -1 || true)
    fi

    # 3차: 영어 자동 자막
    if [[ -z "$SUB_FILE" ]] && [[ "$LANG" != "en" ]]; then
        echo -e "${YELLOW}⚠️  ${LANG} 자막 없음. en 시도...${NC}"
        yt-dlp --write-auto-subs --sub-langs "en" --skip-download \
            --output "$TMPDIR/%(id)s" "$url" 2>/dev/null || true
        SUB_FILE=$(ls "$TMPDIR"/*.vtt 2>/dev/null | head -1 || true)
    fi

    if [[ -z "$SUB_FILE" ]]; then
        echo -e "${RED}❌ 자막을 찾을 수 없습니다.${NC}"
        rm -rf "$TMPDIR"
        return 1
    fi

    # VTT → 원하는 형식으로 변환
    case "$FORMAT" in
        srt)
            # VTT에서 SRT로 간단 변환
            if [[ -n "$out_path" ]]; then
                cp "$SUB_FILE" "${out_path%.srt}.vtt"
                echo -e "${GREEN}✅ 저장: ${out_path%.srt}.vtt${NC}"
            else
                cat "$SUB_FILE"
            fi
            ;;
        md)
            local CLEAN_TEXT
            if [[ "$TIMESTAMPS" == true ]]; then
                CLEAN_TEXT=$(sed '/^WEBVTT/d;/^Kind:/d;/^Language:/d;/^$/d;/^NOTE/d' "$SUB_FILE" \
                    | sed 's/<[^>]*>//g' \
                    | awk '!seen[$0]++')
            else
                CLEAN_TEXT=$(sed '/^WEBVTT/d;/^Kind:/d;/^Language:/d;/^$/d;/^NOTE/d;/^[0-9][0-9]:[0-9][0-9]/d;/-->/d' "$SUB_FILE" \
                    | sed 's/<[^>]*>//g' \
                    | awk '!seen[$0]++' \
                    | tr '\n' ' ' \
                    | sed 's/  / /g')
            fi

            if [[ -n "$out_path" ]]; then
                {
                    echo "# ${TITLE}"
                    echo ""
                    echo "**Source:** ${url}"
                    echo "**Language:** ${LANG}"
                    echo ""
                    echo "---"
                    echo ""
                    echo "$CLEAN_TEXT"
                } > "$out_path"
                echo -e "${GREEN}✅ 저장: $out_path${NC}"
            else
                echo "# ${TITLE}"
                echo ""
                echo "$CLEAN_TEXT"
            fi
            ;;
        txt|*)
            local CLEAN_TEXT
            if [[ "$TIMESTAMPS" == true ]]; then
                CLEAN_TEXT=$(sed '/^WEBVTT/d;/^Kind:/d;/^Language:/d;/^$/d;/^NOTE/d' "$SUB_FILE" \
                    | sed 's/<[^>]*>//g' \
                    | awk '!seen[$0]++')
            else
                CLEAN_TEXT=$(sed '/^WEBVTT/d;/^Kind:/d;/^Language:/d;/^$/d;/^NOTE/d;/^[0-9][0-9]:[0-9][0-9]/d;/-->/d' "$SUB_FILE" \
                    | sed 's/<[^>]*>//g' \
                    | awk '!seen[$0]++' \
                    | tr '\n' ' ' \
                    | sed 's/  / /g')
            fi

            if [[ -n "$out_path" ]]; then
                echo "$CLEAN_TEXT" > "$out_path"
                echo -e "${GREEN}✅ 저장: $out_path${NC}"
            else
                echo "$CLEAN_TEXT"
            fi
            ;;
    esac

    rm -rf "$TMPDIR"
    return 0
}

# 단일 영상
if [[ -n "$VIDEO_URL" ]] && [[ -z "$PLAYLIST_URL" ]]; then
    download_single "$VIDEO_URL" "$OUTPUT"
    exit $?
fi

# 재생목록
if [[ -n "$PLAYLIST_URL" ]]; then
    echo -e "${BLUE}🔍 재생목록 영상 목록 추출 중...${NC}"

    URLS=$(yt-dlp --flat-playlist --print "%(id)s|||%(title)s" \
        --no-warnings "$PLAYLIST_URL" 2>/dev/null)

    COUNT=$(echo "$URLS" | wc -l | tr -d ' ')
    echo -e "${GREEN}✅ ${COUNT}개 영상 발견${NC}"

    mkdir -p "$OUTPUT_DIR"
    SUCCESS=0
    FAIL=0
    IDX=0

    while IFS='|||' read -r vid_id vid_title; do
        IDX=$((IDX + 1))
        # 파일명 안전 처리
        SAFE_TITLE=$(echo "$vid_title" | sed 's/[^a-zA-Z0-9가-힣ㄱ-ㅎㅏ-ㅣ _-]//g' | head -c 80)
        OUT_FILE="$OUTPUT_DIR/${IDX}_${SAFE_TITLE}.${FORMAT}"

        if download_single "https://www.youtube.com/watch?v=$vid_id" "$OUT_FILE"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAIL=$((FAIL + 1))
        fi
        sleep 0.5
    done <<< "$URLS"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}성공: $SUCCESS${NC}"
    echo -e "  ${RED}실패: $FAIL${NC}"
    echo -e "  저장 위치: $OUTPUT_DIR/"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi
