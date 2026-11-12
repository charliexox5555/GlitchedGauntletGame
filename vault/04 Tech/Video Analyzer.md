# Video Analyzer (YouTube study tool)

Set up 2026-11-12. It turns a video link into a timestamped transcript plus key frames that Claude can look at, so we can study gameplay, UI and dev tutorials. The first use was the [UI References](../03%20Research/UI%20References/00%20UI%20References.md).

## What was picked and why
Compared on GitHub, 2026-11-12:

| Repo | Stars | Last push | Transcript | Frames | OCR | Notes |
|---|---|---|---|---|---|---|
| **[guimatheus92/mcp-video-analyzer](https://github.com/guimatheus92/mcp-video-analyzer)** (picked) | 122 | 2026-11-08 | Native captions, then Whisper | Scene-change or spread, plus single frame, burst and moment tools | Yes (tesseract.js) | 8 MCP tools, a CLI, MIT, bundled ffmpeg |
| [HUANGCHIHHUNGLeo/claude-real-video](https://github.com/HUANGCHIHHUNGLeo/claude-real-video) | 2,307 | 2026-10-23 | Whisper | Best dedup | Only in the paid edition | Runner-up |
| [0xchamin/mcptube](https://github.com/0xchamin/mcptube) | 166 | 2026-04 | Yes | Vision | No | Knowledge-base wiki, no licence |
| [velmighty/youtube-to-knowledge](https://github.com/velmighty/youtube-to-knowledge) | 68 | 2026-04 | Yes | No | No | Transcript + knowledge graph only |

The analyzer won because it has the frame tools that UI study needs (`get_frame_at`, `get_frame_burst`, `analyze_moment`) and prefers free native captions.

## Install (done)
- `yt-dlp` and `whisper-ctranslate2` (faster-whisper) installed with `uv tool install` into `~/.local/bin` (on the user PATH).
- MCP server registered for this project, local scope (private, not in the repo):
  `claude mcp add video-analyzer --scope local -e WHISPER_BIN=C:/Users/charl/.local/bin/whisper-ctranslate2.exe -e WHISPER_MODEL=small -e WHISPER_LANGUAGE=en -- npx -y mcp-video-analyzer@0.11.0`
  (version pinned). It loads in **new** sessions.
- CLI, which works in any session and is token-lean because frames stay on disk:
  ```
  export WHISPER_BIN="C:/Users/charl/.local/bin/whisper-ctranslate2.exe" WHISPER_MODEL=small WHISPER_LANGUAGE=en
  npx -y mcp-video-analyzer@0.11.0 analyze "<url>" --detail detailed --max-frames 12 --max-width 1280 --ocr-language eng --out "<dir>" > "<dir>/result.json"
  ```

## Verified 2026-11-12
- Transcript: 135 timestamped lines from a 23-minute tutorial through the Whisper fallback (YouTube captions returned HTTP 429).
- Frames: 10 evenly spread frames over 8 minutes with `--detail detailed --max-frames 10`.

## Gotchas (learned the hard way)
- **`--detail standard` keeps the first N scene cuts**, so fast-cut gameplay bunches every frame into the first 15 s. Use `detailed` + `--max-frames` (evenly spread), or `get_frame_at` / `analyze_moment` for exact moments.
- **OCR returns nothing on 3D gameplay.** It drops whole-frame results under 50% confidence. It's fine for code and slides; for HUDs, look at the frames.
- **No frames on long, 4K or AV1/webm videos** (3 of the studies hit this). Fallback: `yt-dlp -f "bv*[height<=1080][ext=mp4]"`, then ffmpeg `-vf fps=1/60`. ffmpeg comes from the bundled `ffmpeg-static` in the npx cache, or install it with `winget install Gyan.FFmpeg`.
- YouTube rate-limits captions (429): run videos one at a time; Whisper covers the gap (slow on long videos with the small model on CPU).
- Third-party frames go in `vault/02 Art/References/ui/video-frames/` (git-ignored). Never commit them.
