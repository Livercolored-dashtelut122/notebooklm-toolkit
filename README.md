# NotebookLM Toolkit

CLI scripts that replace 5 Chrome extensions for [Google NotebookLM](https://notebooklm.google.com/) — bulk import, transcript download, cross-notebook search, and more.

Built as a [Claude Code](https://claude.ai/) skill, these scripts run entirely from the command line, eliminating the need for browser extensions.

## Background

This project builds on top of [notebooklm-py](https://github.com/teng-lin/notebooklm-py) (MIT License) by Teng Lin — an unofficial Python CLI for Google NotebookLM. While `notebooklm-py` handles core operations (notebook CRUD, source management, chat, artifact generation), it doesn't cover bulk import workflows that several Chrome extensions provide.

**This toolkit adds 9 capabilities across 7 shell scripts**, replacing the functionality of these 5 Chrome extensions:

| Chrome Extension | What It Does | Replaced By |
|---|---|---|
| [YouTube to NotebookLM](https://chromewebstore.google.com/detail/youtube-to-notebooklm/empty) | Playlist/channel bulk import, search results | `nlm-youtube-bulk.sh`, `nlm-yt-search.sh` |
| [NotebookLM AI Sidebar](https://chromewebstore.google.com/detail/notebooklm-ai-sidebar/empty) | Channel category scan, transcript download | `nlm-yt-channel-scan.sh`, `nlm-transcript.sh` |
| [Grabbit – Link Automator](https://chromewebstore.google.com/detail/grabbit/empty) | Web page link extraction & bulk import | `nlm-web-links.sh` |
| [NotebookLM Web Importer](https://chromewebstore.google.com/detail/notebooklm-web-importer/empty) | RSS/Atom feed import | `nlm-rss-import.sh` |
| [NotebookLM Tools](https://chromewebstore.google.com/detail/notebooklm-tools/empty) | Cross-notebook search, duplicate scan, backup | `nlm-notebook-manage.sh` |

## Prerequisites

- **[notebooklm-py](https://github.com/teng-lin/notebooklm-py)** v0.3.x — `pip install notebooklm-py`
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)** — `brew install yt-dlp` (or `pip install yt-dlp`)
- **Python 3** — for RSS parsing and JSON processing
- **curl, grep** — system defaults

Make sure `notebooklm` CLI is authenticated before use:
```bash
notebooklm login
```

## Features

### 1. YouTube Playlist/Channel Bulk Import

Import all videos from a YouTube playlist or channel into NotebookLM at once.

```bash
# List videos without importing
./nlm-youtube-bulk.sh list-only "https://www.youtube.com/playlist?list=PLxxxx"

# Import entire playlist
./nlm-youtube-bulk.sh playlist "https://www.youtube.com/playlist?list=PLxxxx" --notebook <id>

# Import latest 20 videos from a channel
./nlm-youtube-bulk.sh channel "https://www.youtube.com/@channelname" --notebook <id> --limit 20
```

### 2. Web Page Link Extraction & Bulk Import

Extract links from any web page and import them into NotebookLM. Uses [r.jina.ai](https://r.jina.ai) for page parsing.

```bash
# Extract links from a page
./nlm-web-links.sh extract "https://blog.example.com/archive"

# Extract only matching links
./nlm-web-links.sh extract "https://example.com" --filter "youtube.com\|arxiv.org"

# Extract and import
./nlm-web-links.sh import "https://example.com/resources" --notebook <id>

# Import from a text file of URLs
./nlm-web-links.sh import-file urls.txt --notebook <id>
```

### 3. YouTube Transcript Download

Download subtitles/transcripts from YouTube videos or entire playlists.

```bash
# Print transcript to terminal
./nlm-transcript.sh "https://youtu.be/xxxxx"

# Save as markdown with timestamps
./nlm-transcript.sh "https://youtu.be/xxxxx" --format md --timestamps --output transcript.md

# Download all transcripts from a playlist
./nlm-transcript.sh --playlist "https://www.youtube.com/playlist?list=PLxxxx" --output-dir ./transcripts

# Specify language (default: ko → en fallback)
./nlm-transcript.sh "https://youtu.be/xxxxx" --lang en
```

### 4. RSS/Atom Feed Import

Parse RSS or Atom feeds and import articles into NotebookLM.

```bash
# List feed items
./nlm-rss-import.sh list "https://example.com/feed"

# Import latest 10 items
./nlm-rss-import.sh import "https://example.com/feed" --notebook <id> --limit 10

# YouTube channel RSS
./nlm-rss-import.sh import "https://www.youtube.com/feeds/videos.xml?channel_id=UCxxxx" --notebook <id>
```

### 5. YouTube Search & Import

Search YouTube and import results directly into NotebookLM.

```bash
# List search results
./nlm-yt-search.sh list "machine learning basics" --limit 10

# Import search results
./nlm-yt-search.sh import "machine learning basics" --notebook <id> --limit 10
```

### 6. YouTube Channel Category Scan

Scan a channel's playlists for selective import.

```bash
# Scan all playlists
./nlm-yt-channel-scan.sh scan "https://www.youtube.com/@channelname"

# Import a specific playlist
./nlm-yt-channel-scan.sh import-playlist "https://www.youtube.com/playlist?list=PLxxxx" --notebook <id>
```

### 7. Cross-Notebook Search

Search for sources across all your notebooks.

```bash
./nlm-notebook-manage.sh search "keyword"
```

### 8. Duplicate Source Scan

Find duplicate sources within or across notebooks.

```bash
# Scan all notebooks
./nlm-notebook-manage.sh duplicates

# Scan specific notebook
./nlm-notebook-manage.sh duplicates --notebook <id>
```

### 9. Notebook Backup

Export all notebook metadata and source lists to JSON.

```bash
# Backup to default location (~/Downloads/notebooklm-backup/)
./nlm-notebook-manage.sh backup

# Backup to custom directory
./nlm-notebook-manage.sh backup --output ~/my-backups
```

## Installation

### As Claude Code Skill (Recommended)

Copy the scripts to your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills/notebooklm-plus
cp *.sh SKILL.md ~/.claude/skills/notebooklm-plus/
chmod +x ~/.claude/skills/notebooklm-plus/*.sh
```

Claude Code will auto-detect the skill and use it when you say things like:
- *"Import this YouTube playlist into NotebookLM"*
- *"Download transcripts from this playlist"*
- *"Search all notebooks for keyword X"*

### Standalone Usage

Clone and run the scripts directly:

```bash
git clone https://github.com/curara81/notebooklm-toolkit.git
cd notebooklm-toolkit
chmod +x *.sh

# Make sure notebooklm-py is in your PATH
./nlm-youtube-bulk.sh list-only "https://www.youtube.com/playlist?list=PLxxxx"
```

## Common Workflows

### Research a YouTube Channel

```bash
# 1. Scan channel playlists
./nlm-yt-channel-scan.sh scan "https://www.youtube.com/@channel"

# 2. List videos from interesting playlist
./nlm-youtube-bulk.sh list-only "https://www.youtube.com/playlist?list=PLxxxx"

# 3. Import selected playlist
./nlm-youtube-bulk.sh playlist "https://www.youtube.com/playlist?list=PLxxxx" --notebook <id>
```

### Collect Blog Articles

```bash
# 1. Extract article links
./nlm-web-links.sh extract "https://blog.example.com/archive" --filter "article\|post"

# 2. Import filtered links
./nlm-web-links.sh import "https://blog.example.com/archive" --filter "article" --notebook <id>
```

### Download Lecture Transcripts

```bash
# 1. Download all transcripts as markdown
./nlm-transcript.sh --playlist "https://youtube.com/playlist?list=PLxxx" --format md --output-dir ./lectures

# 2. Review and import to NotebookLM
./nlm-web-links.sh import-file <(ls ./lectures/*.md) --notebook <id>
```

## Credits

- **[notebooklm-py](https://github.com/teng-lin/notebooklm-py)** by Teng Lin — the core NotebookLM CLI that this toolkit depends on (MIT License)
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)** — YouTube metadata and subtitle extraction
- **[r.jina.ai](https://r.jina.ai)** — web page to markdown conversion for link extraction
- Built with [Claude Code](https://claude.ai/) by Anthropic

## License

MIT License — see [LICENSE](LICENSE) for details.
