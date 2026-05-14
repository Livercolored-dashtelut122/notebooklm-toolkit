---
name: notebooklm-plus
description: NotebookLM 확장 기능 — YouTube 재생목록/채널 일괄 import, 채널 카테고리 스캔, YouTube 검색 import, RSS 피드 import, 웹페이지 링크 일괄 수집, 트랜스크립트 다운로드, 크로스노트북 검색, 중복 스캔, 백업. 크롬확장 5개(Web Importer, YouTube to NLM, Link Automator, AI Sidebar, NLM Tools) 기능을 CLI로 대체.
---

# NotebookLM Plus — 크롬확장 대체 스킬

기존 `notebooklm` 스킬이 커버하지 못하는 **자료 수집·bulk import·노트북 관리** 기능을 추가합니다.
크롬 확장프로그램 5개(Web Importer, YouTube to NLM, Link Automator, AI Sidebar, NLM Tools)의 핵심 기능을 CLI로 구현.

## 의존성

- `yt-dlp` (Homebrew로 설치됨)
- `notebooklm` CLI (`~/.venvs/gcp-automation/bin/`)
- `curl`, `grep` (시스템 기본)

## When This Skill Activates

**Intent detection:** 다음과 같은 요청에서 활성화:
- "이 YouTube 재생목록 전부 NotebookLM에 넣어줘"
- "이 채널 영상 다 추가해줘"
- "이 채널 재생목록 보여줘" / "채널 카테고리 스캔"
- "YouTube에서 OOO 검색해서 NotebookLM에 넣어줘"
- "이 RSS 피드 구독해서 넣어줘"
- "이 웹페이지에서 링크 다 뽑아서 NotebookLM에 넣어"
- "YouTube 자막 다운로드해줘" / "트랜스크립트 뽑아줘"
- "전체 노트북에서 OOO 검색해줘"
- "중복 소스 있는지 확인해줘"
- "노트북 백업해줘"

**Explicit:** "/notebooklm-plus" 또는 "bulk import", "일괄 추가"

## 스크립트 위치

```
~/.claude/skills/notebooklm-plus/
├── SKILL.md                    ← 이 파일
├── nlm-youtube-bulk.sh         ← YouTube 재생목록/채널 일괄 import
├── nlm-yt-search.sh            ← YouTube 검색결과 일괄 import [신규]
├── nlm-yt-channel-scan.sh      ← 채널 재생목록 카테고리별 스캔 [신규]
├── nlm-web-links.sh            ← 웹페이지 링크 추출 및 일괄 import
├── nlm-rss-import.sh           ← RSS/Atom 피드 import [신규]
├── nlm-transcript.sh           ← YouTube 트랜스크립트 다운로드
└── nlm-notebook-manage.sh      ← 크로스노트북 검색, 중복 스캔, 백업 [신규]
```

## Quick Reference

### 1. YouTube 재생목록/채널 일괄 Import

YouTube to NotebookLM 크롬확장 + AI Sidebar의 채널 스캔 기능 대체.

| Task | Command |
|------|---------|
| 재생목록 영상 목록 확인 | `~/.claude/skills/notebooklm-plus/nlm-youtube-bulk.sh list-only "<playlist_url>"` |
| 재생목록 전부 import | `~/.claude/skills/notebooklm-plus/nlm-youtube-bulk.sh playlist "<playlist_url>"` |
| 재생목록 import (노트북 지정) | `~/.claude/skills/notebooklm-plus/nlm-youtube-bulk.sh playlist "<url>" --notebook <id>` |
| 채널 영상 전부 import | `~/.claude/skills/notebooklm-plus/nlm-youtube-bulk.sh channel "<channel_url>"` |
| 채널 최신 20개만 | `~/.claude/skills/notebooklm-plus/nlm-youtube-bulk.sh channel "<channel_url>" --limit 20` |
| 목록만 확인 (추가 안 함) | `~/.claude/skills/notebooklm-plus/nlm-youtube-bulk.sh list-only "<url>" --limit 10` |

**지원 URL 형식:**
- 재생목록: `https://www.youtube.com/playlist?list=PLxxxx`
- 채널: `https://www.youtube.com/@channelname` 또는 `https://www.youtube.com/c/channelname`
- 채널 영상 탭: `https://www.youtube.com/@channelname/videos`

**주의사항:**
- rate limit 방지로 영상 간 1초 대기
- 기본 최대 50개. --limit으로 조절
- 채널 전체 영상이 많으면 --limit 권장
- 소스 추가 후 `notebooklm source list`로 상태 확인

### 2. 웹페이지 링크 일괄 추출 & Import

Grabbit 크롬확장의 링크 bulk 수집 기능 대체.
r.jina.ai를 사용하여 웹페이지를 파싱 (백프롬 영상에서도 소개된 꿀팁).

| Task | Command |
|------|---------|
| 웹페이지 링크 추출만 | `~/.claude/skills/notebooklm-plus/nlm-web-links.sh extract "<page_url>"` |
| 특정 패턴만 필터 | `~/.claude/skills/notebooklm-plus/nlm-web-links.sh extract "<url>" --filter "youtube.com\|blog"` |
| 추출 후 바로 import | `~/.claude/skills/notebooklm-plus/nlm-web-links.sh import "<url>" --notebook <id>` |
| 필터 + import | `~/.claude/skills/notebooklm-plus/nlm-web-links.sh import "<url>" --filter "arxiv.org" --notebook <id>` |
| 텍스트파일 URL 목록 import | `~/.claude/skills/notebooklm-plus/nlm-web-links.sh import-file urls.txt --notebook <id>` |
| 최대 개수 제한 | `~/.claude/skills/notebooklm-plus/nlm-web-links.sh import "<url>" --limit 10` |

**자동 제외 패턴:** login, signup, logout, javascript:, mailto:, .css, .js, 이미지 파일 등
**커스텀 제외:** `--exclude "광고|ads|tracking"` 

**활용 시나리오:**
- 블로그 글 목록 페이지에서 모든 포스트 링크 수집
- 연구 논문 목록 페이지에서 PDF 링크 추출
- 뉴스 사이트에서 특정 주제 기사 링크 일괄 import
- URL 목록이 담긴 텍스트 파일에서 일괄 import

### 3. YouTube 트랜스크립트 다운로드

NotebookLM AI Sidebar의 트랜스크립트 다운로드 기능 대체.

| Task | Command |
|------|---------|
| 트랜스크립트 출력 (터미널) | `~/.claude/skills/notebooklm-plus/nlm-transcript.sh "<youtube_url>"` |
| 한국어 자막 txt 저장 | `~/.claude/skills/notebooklm-plus/nlm-transcript.sh "<url>" --lang ko --output transcript.txt` |
| 마크다운으로 저장 | `~/.claude/skills/notebooklm-plus/nlm-transcript.sh "<url>" --format md --output transcript.md` |
| 타임스탬프 포함 | `~/.claude/skills/notebooklm-plus/nlm-transcript.sh "<url>" --timestamps --output timed.txt` |
| 영어 자막 | `~/.claude/skills/notebooklm-plus/nlm-transcript.sh "<url>" --lang en` |
| 재생목록 전체 트랜스크립트 | `~/.claude/skills/notebooklm-plus/nlm-transcript.sh --playlist "<playlist_url>" --output-dir ./transcripts` |
| 재생목록 마크다운 형식 | `~/.claude/skills/notebooklm-plus/nlm-transcript.sh --playlist "<url>" --format md --output-dir ./transcripts` |

**자막 우선순위:** 수동 자막 → 자동 자막 → 영어 fallback
**출력 형식:** txt (기본, 순수 텍스트), md (제목+URL 포함), srt (VTT 원본)

### 4. RSS/Atom 피드 Import [신규]

NotebookLM Web Importer 크롬확장의 RSS 기능 대체.

| Task | Command |
|------|---------|
| RSS 피드 항목 목록 | `~/.claude/skills/notebooklm-plus/nlm-rss-import.sh list "<feed_url>"` |
| RSS 피드 → NotebookLM import | `~/.claude/skills/notebooklm-plus/nlm-rss-import.sh import "<feed_url>" --notebook <id>` |
| 최근 10개만 | `~/.claude/skills/notebooklm-plus/nlm-rss-import.sh import "<feed_url>" --limit 10` |

**지원 형식:** RSS 2.0, Atom
**일반적인 RSS URL 예시:**
- 블로그: `https://example.com/feed`, `https://example.com/rss.xml`
- YouTube 채널: `https://www.youtube.com/feeds/videos.xml?channel_id=UCxxxx`

### 5. YouTube 검색결과 일괄 Import [신규]

YouTube to NotebookLM 크롬확장의 검색결과 전송 기능 대체.

| Task | Command |
|------|---------|
| 검색 결과 목록 확인 | `~/.claude/skills/notebooklm-plus/nlm-yt-search.sh list "검색어"` |
| 검색 결과 import | `~/.claude/skills/notebooklm-plus/nlm-yt-search.sh import "검색어" --notebook <id>` |
| 최대 20개 | `~/.claude/skills/notebooklm-plus/nlm-yt-search.sh import "검색어" --limit 20` |

### 6. YouTube 채널 카테고리별 스캔 [신규]

NotebookLM AI Sidebar의 채널 카테고리 분류(재생목록/팟캐스트/코스 분리) 기능 대체.

| Task | Command |
|------|---------|
| 채널 재생목록 스캔 | `~/.claude/skills/notebooklm-plus/nlm-yt-channel-scan.sh scan "<channel_url>"` |
| 특정 재생목록만 import | `~/.claude/skills/notebooklm-plus/nlm-yt-channel-scan.sh import-playlist "<playlist_url>" --notebook <id>` |

**워크플로우:** scan으로 재생목록 확인 → 원하는 재생목록만 선택적 import

### 7. 크로스노트북 검색 [신규]

NotebookLM Tools 크롬확장의 크로스노트북 검색 기능 대체.

| Task | Command |
|------|---------|
| 전체 노트북에서 소스 검색 | `~/.claude/skills/notebooklm-plus/nlm-notebook-manage.sh search "키워드"` |

### 8. 중복 소스 스캔 [신규]

NotebookLM Tools 크롬확장의 중복 스캔 기능 대체.

| Task | Command |
|------|---------|
| 전체 노트북 중복 스캔 | `~/.claude/skills/notebooklm-plus/nlm-notebook-manage.sh duplicates` |
| 특정 노트북만 | `~/.claude/skills/notebooklm-plus/nlm-notebook-manage.sh duplicates --notebook <id>` |

### 9. 노트북 백업 [신규]

NotebookLM Tools 크롬확장의 백업 기능 대체.

| Task | Command |
|------|---------|
| 전체 노트북 메타데이터 백업 | `~/.claude/skills/notebooklm-plus/nlm-notebook-manage.sh backup` |
| 저장 위치 지정 | `~/.claude/skills/notebooklm-plus/nlm-notebook-manage.sh backup --output ~/backups` |

**백업 내용:** 노트북 목록, 각 노트북의 소스 목록·상태, 타임스탬프 (JSON 형식)

## Autonomy Rules

**Run automatically (no confirmation):**
- `list-only`, `list` — 영상/링크/피드 목록만 보여줌
- `extract` — 링크 추출만 (import 안 함)
- `scan` — 채널 재생목록 스캔 (import 안 함)
- `search` — 크로스노트북 검색
- `duplicates` — 중복 스캔
- 트랜스크립트 터미널 출력 (--output 없을 때)

**Ask before running:**
- `playlist` / `channel` / `import` — NotebookLM에 실제 소스 추가
- `import-file` — 파일에서 URL 읽어 일괄 추가
- 트랜스크립트 파일 저장 (--output 있을 때)

## Common Workflows

### 유튜브 채널 연구하기
1. 채널 영상 목록 확인: `nlm-youtube-bulk.sh list-only "https://www.youtube.com/@channel" --limit 30`
2. 노트북 생성: `notebooklm create "채널분석: [이름]"`
3. 일괄 import: `nlm-youtube-bulk.sh channel "https://www.youtube.com/@channel" --notebook <id> --limit 30`
4. 소스 처리 대기 후 분석: `notebooklm ask "이 채널의 주요 주제와 콘텐츠 패턴을 분석해줘"`

### 블로그/뉴스 사이트 일괄 수집
1. 링크 추출 확인: `nlm-web-links.sh extract "https://blog.example.com/archive" --filter "article\|post"`
2. 노트북 생성: `notebooklm create "리서치: [주제]"`
3. 일괄 import: `nlm-web-links.sh import "https://blog.example.com/archive" --filter "article" --notebook <id>`

### 강의 영상 트랜스크립트 정리
1. 재생목록 트랜스크립트 일괄 다운로드: `nlm-transcript.sh --playlist "https://youtube.com/playlist?list=PLxxx" --format md --output-dir ./lectures`
2. 트랜스크립트를 NotebookLM에 소스로 추가: `nlm-web-links.sh import-file <(ls ./lectures/*.md) --notebook <id>`

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| "영상을 찾을 수 없습니다" | URL 오류 또는 비공개 | URL 확인, 공개 영상인지 체크 |
| "자막을 찾을 수 없습니다" | 자막 미제공 영상 | --lang 변경 또는 NotebookLM이 자체 처리하도록 source add |
| source add 실패 | rate limit 또는 인증 만료 | `notebooklm auth check`, 잠시 후 재시도 |
| curl/jina 실패 | 사이트 접근 차단 | 직접 URL 목록을 txt로 만들어 import-file 사용 |

## notebooklm 기본 스킬과의 관계

이 스킬은 기본 `notebooklm` 스킬을 **대체하지 않고 보완**합니다.

- **notebooklm** (기본): 노트북 관리, 소스 개별 추가, 채팅, 아티팩트 생성(팟캐스트/비디오/퀴즈 등), 다운로드, 딥리서치
- **notebooklm-plus** (이 스킬): YouTube bulk import, 웹 링크 bulk 수집, 트랜스크립트 다운로드

일반적인 흐름: **notebooklm-plus로 자료 수집 → notebooklm으로 분석·생성**
