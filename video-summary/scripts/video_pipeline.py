#!/usr/bin/env python3
"""
Local open-source video parsing, subtitle/transcript chunking, Antigravity-safe
compression/splitting, HD keyframe extraction, and optional CPU ASR pipeline.

Zero third-party Python dependencies for core subcommands (stdlib only).
External CLI tools (yt-dlp, ffmpeg, ffprobe, optional BBDown) are discovered
at runtime and never bundled or silently installed.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import locale
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple
from urllib.parse import urlparse


def configure_stdio() -> None:
    """Ensure UTF-8 output on Windows PowerShell terminals."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except Exception:
                pass


def decode_bytes(data: bytes) -> str:
    """Decode subprocess bytes robustly across Windows and Unix locales."""
    encodings = ["utf-8", locale.getpreferredencoding(False), "gb18030", "utf-8-sig"]
    seen = set()
    for enc in encodings:
        if not enc:
            continue
        low = enc.lower()
        if low in seen:
            continue
        seen.add(low)
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def run_cmd(
    cmd: Sequence[str],
    cwd: Optional[Path] = None,
    timeout: int = 300,
    env: Optional[Dict[str, str]] = None,
) -> Tuple[int, str, str]:
    """Run a subprocess and return (returncode, stdout_text, stderr_text)."""
    merged_env = os.environ.copy()
    merged_env.setdefault("PYTHONUTF8", "1")
    merged_env.setdefault("PYTHONIOENCODING", "utf-8")
    if env:
        merged_env.update(env)
    proc = subprocess.run(
        list(cmd),
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        timeout=timeout,
        env=merged_env,
    )
    return proc.returncode, decode_bytes(proc.stdout), decode_bytes(proc.stderr)


def find_bbdown() -> Optional[str]:
    """Locate BBDown via environment variable or PATH (case-insensitive)."""
    env_bin = os.environ.get("BBDOWN_BIN", "").strip()
    if env_bin and Path(env_bin).is_file():
        return env_bin
    for name in ("bbdown", "BBDown", "BBDown.exe", "bbdown.exe"):
        found = shutil.which(name)
        if found:
            return found
    return None


def find_cookie_file(explicit: Optional[str]) -> Optional[str]:
    """Resolve explicit cookie file or user environment variable without exposing contents."""
    candidates = [
        explicit,
        os.environ.get("VIDEO_SUMMARY_COOKIES"),
        os.environ.get("BILIBILI_COOKIES_FILE"),
    ]
    for item in candidates:
        if item and Path(item).is_file():
            return str(Path(item).resolve())
    return None


def is_bilibili_url(url: str) -> bool:
    host = urlparse(url).netloc.lower()
    return "bilibili.com" in host or host.endswith("b23.tv")


def extract_bvid(text: str) -> Optional[str]:
    match = re.search(r"(BV[0-9A-Za-z]+)", text)
    return match.group(1) if match else None


def sanitize_filename(name: str, fallback: str = "video") -> str:
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]+', "_", name).strip(" .")
    if not cleaned:
        return fallback
    return cleaned[:80]


def format_timestamp(seconds: float) -> str:
    total = max(0, int(seconds))
    hours, rem = divmod(total, 3600)
    minutes, secs = divmod(rem, 60)
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def parse_timestamp_to_seconds(ts: str) -> float:
    raw = ts.strip()
    if not raw:
        raise ValueError("Empty timestamp")
    if re.fullmatch(r"\d+(?:\.\d+)?", raw):
        return float(raw)
    parts = raw.split(":")
    if len(parts) == 2:
        return int(parts[0]) * 60 + float(parts[1])
    if len(parts) == 3:
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
    raise ValueError(f"Unsupported timestamp format: {ts}")


def format_ts_slug(seconds: float) -> str:
    total = max(0, int(round(seconds)))
    hours, rem = divmod(total, 3600)
    minutes, secs = divmod(rem, 60)
    if hours > 0:
        return f"{hours:02d}h{minutes:02d}m{secs:02d}s"
    return f"{minutes:02d}m{secs:02d}s"


def extract_links_from_text(text: str) -> List[str]:
    if not text:
        return []
    raw_links = re.findall(r"https?://[^\s<>()\[\]\"'，。；！？、]+", text)
    seen = set()
    result: List[str] = []
    for link in raw_links:
        trimmed = link.rstrip(".,;:!?)")
        if trimmed and trimmed not in seen:
            seen.add(trimmed)
            result.append(trimmed)
    return result


def is_edge_or_chrome_abe_error(stderr: str) -> bool:
    """Detect Windows Chromium App-Bound Encryption or locked cookie DB errors."""
    low = stderr.lower()
    markers = (
        "app-bound",
        "failed to decrypt",
        "dpapi",
        "could not copy chrome cookie database",
        "could not copy edge cookie database",
        "could not find edge cookies",
        "cookie database",
        "permission denied",
    )
    return any(m in low for m in markers)


def make_bbdown_install_prompt(reason: str) -> Dict[str, Any]:
    return {
        "type": "optional_tool_install",
        "tool": "bbdown",
        "reason": reason,
        "install_commands": [
            "scoop install bbdown",
            "winget install nilaoda.BBDown",
        ],
        "login_command": "BBDown login",
        "alternative": "在 Edge 使用 Get cookies.txt LOCALLY 导出 cookies.txt 并通过 --cookies 或 VIDEO_SUMMARY_COOKIES 传入，或改用 Firefox (--cookies-from-browser firefox)。",
    }


def detect_tools() -> Dict[str, Any]:
    ytdlp = shutil.which("yt-dlp")
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    bbdown = find_bbdown()
    node = shutil.which("node")
    faster_whisper = importlib.util.find_spec("faster_whisper") is not None
    cookie_env = find_cookie_file(None)

    return {
        "yt_dlp": {"installed": bool(ytdlp), "path": ytdlp},
        "ffmpeg": {"installed": bool(ffmpeg), "path": ffmpeg},
        "ffprobe": {"installed": bool(ffprobe), "path": ffprobe},
        "bbdown": {"installed": bool(bbdown), "path": bbdown},
        "node": {"installed": bool(node), "path": node},
        "faster_whisper": {"installed": faster_whisper},
        "cookie_file_env_configured": bool(cookie_env),
    }


def strip_subtitle_markup(text: str) -> str:
    cleaned = re.sub(r"\{\\[^}]*\}", "", text)  # ASS override tags
    cleaned = re.sub(r"<[^>]+>", "", cleaned)  # HTML / WebVTT tags
    cleaned = cleaned.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


def parse_vtt_or_srt(content: str) -> List[Tuple[float, str]]:
    """Parse WebVTT or SRT subtitle text into deduplicated (start_seconds, text) tuples."""
    entries: List[Tuple[float, str]] = []
    blocks = re.split(r"\r?\n\r?\n+", content.strip())
    ts_pattern = re.compile(
        r"(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})"
    )
    last_text = ""

    for block in blocks:
        lines = [ln.strip() for ln in block.splitlines() if ln.strip()]
        if not lines:
            continue
        if lines[0].upper().startswith(("WEBVTT", "NOTE", "STYLE", "REGION", "KIND:", "LANGUAGE:")):
            continue

        ts_idx = -1
        start_sec = 0.0
        for idx, line in enumerate(lines):
            m = ts_pattern.search(line)
            if m:
                ts_idx = idx
                h = int(m.group(1) or 0)
                mi = int(m.group(2))
                s = int(m.group(3))
                ms = int(m.group(4))
                start_sec = h * 3600 + mi * 60 + s + ms / 1000.0
                break
        if ts_idx < 0:
            continue

        body_lines = lines[ts_idx + 1 :]
        text = strip_subtitle_markup(" ".join(body_lines))
        if not text:
            continue
        if text == last_text:
            continue
        # Remove incremental overlap common in rolling auto-captions
        if last_text and text.startswith(last_text) and len(text) > len(last_text):
            delta = text[len(last_text) :].strip()
            if delta:
                entries.append((start_sec, delta))
                last_text = text
                continue
        entries.append((start_sec, text))
        last_text = text

    return entries


def parse_bcc_json(content: str) -> List[Tuple[float, str]]:
    """Parse Bilibili BCC JSON subtitle format."""
    data = json.loads(content)
    body = data.get("body") if isinstance(data, dict) else data
    if not isinstance(body, list):
        return []
    entries: List[Tuple[float, str]] = []
    last_text = ""
    for item in body:
        if not isinstance(item, dict):
            continue
        raw_text = item.get("content") or item.get("text") or ""
        text = strip_subtitle_markup(str(raw_text))
        if not text or text == last_text:
            continue
        start_sec = float(item.get("from", item.get("start", 0.0)) or 0.0)
        entries.append((start_sec, text))
        last_text = text
    return entries


def parse_ass(content: str) -> List[Tuple[float, str]]:
    """Parse ASS/SSA Dialogue events."""
    entries: List[Tuple[float, str]] = []
    last_text = ""
    for line in content.splitlines():
        if not line.startswith("Dialogue:"):
            continue
        parts = line.split(",", 9)
        if len(parts) < 10:
            continue
        start_raw = parts[1].strip()
        try:
            start_sec = parse_timestamp_to_seconds(start_raw)
        except ValueError:
            start_sec = 0.0
        text = strip_subtitle_markup(parts[9].replace("\\N", " ").replace("\\n", " "))
        if not text or text == last_text:
            continue
        entries.append((start_sec, text))
        last_text = text
    return entries


def parse_subtitle_file(path: Path) -> List[Tuple[float, str]]:
    raw = path.read_text(encoding="utf-8", errors="replace")
    suffix = path.suffix.lower()
    if suffix in (".vtt", ".srt"):
        return parse_vtt_or_srt(raw)
    if suffix in (".bcc", ".json"):
        try:
            return parse_bcc_json(raw)
        except Exception:
            return []
    if suffix in (".ass", ".ssa"):
        return parse_ass(raw)
    # Fallback plain text lines
    return [(0.0, ln.strip()) for ln in raw.splitlines() if ln.strip()]


def render_transcript_markdown(
    entries: Sequence[Tuple[float, str]],
    metadata: Optional[Dict[str, Any]] = None,
) -> str:
    lines: List[str] = []
    if metadata:
        title = metadata.get("title") or "Untitled Video"
        lines.append(f"# {title}")
        lines.append("")
        if metadata.get("webpage_url"):
            lines.append(f"- URL: {metadata['webpage_url']}")
        if metadata.get("channel"):
            lines.append(f"- Channel: {metadata['channel']}")
        if metadata.get("duration"):
            lines.append(f"- Duration: {metadata['duration']}")
        if metadata.get("upload_date"):
            lines.append(f"- Upload Date: {metadata['upload_date']}")
        lines.append("")
        lines.append("## Transcript")
        lines.append("")
    for start_sec, text in entries:
        lines.append(f"- [{format_timestamp(start_sec)}] {text}")
    lines.append("")
    return "\n".join(lines)


def split_text_by_bytes(
    text: str,
    max_bytes: int,
    preserve_srt_blocks: bool = False,
) -> List[str]:
    """
    Split UTF-8 text into chunks each <= max_bytes at clean line or SRT block boundaries.
    Never slices inside a multi-byte UTF-8 character.
    """
    if max_bytes <= 0:
        return [text]
    encoded = text.encode("utf-8")
    if len(encoded) <= max_bytes:
        return [text]

    if preserve_srt_blocks:
        units = [blk + "\n\n" for blk in re.split(r"\r?\n\r?\n+", text.strip()) if blk.strip()]
    else:
        units = text.splitlines(keepends=True)

    chunks: List[str] = []
    current: List[str] = []
    current_bytes = 0

    def flush() -> None:
        nonlocal current, current_bytes
        if current:
            chunks.append("".join(current))
            current = []
            current_bytes = 0

    for unit in units:
        unit_bytes = len(unit.encode("utf-8"))
        if unit_bytes > max_bytes:
            flush()
            # Character-safe split for an oversized single line
            buf: List[str] = []
            buf_bytes = 0
            for ch in unit:
                ch_b = len(ch.encode("utf-8"))
                if buf and buf_bytes + ch_b > max_bytes:
                    chunks.append("".join(buf))
                    buf = [ch]
                    buf_bytes = ch_b
                else:
                    buf.append(ch)
                    buf_bytes += ch_b
            if buf:
                chunks.append("".join(buf))
            continue

        if current and current_bytes + unit_bytes > max_bytes:
            flush()
        current.append(unit)
        current_bytes += unit_bytes

    flush()
    return chunks


def extract_timestamp_range(chunk_text: str) -> Dict[str, Optional[str]]:
    matches = re.findall(r"\[(\d{1,2}:\d{2}(?::\d{2})?)\]|(\d{2}:\d{2}:\d{2}[.,]\d{3})", chunk_text)
    found = [m[0] or m[1] for m in matches if m[0] or m[1]]
    if not found:
        return {"start": None, "end": None}
    return {"start": found[0], "end": found[-1]}


def write_text_chunks(
    text: str,
    out_dir: Path,
    stem: str,
    suffix: str,
    max_text_kb: int,
    preserve_srt_blocks: bool = False,
) -> Dict[str, Any]:
    out_dir.mkdir(parents=True, exist_ok=True)
    normalized = text.replace("\r\n", "\n")
    full_path = out_dir / f"{stem}{suffix}"
    full_path.write_text(normalized, encoding="utf-8", newline="\n")
    total_bytes = full_path.stat().st_size

    max_bytes = max_text_kb * 1024 if max_text_kb > 0 else 0
    if max_bytes <= 0 or total_bytes <= max_bytes:
        ts_range = extract_timestamp_range(normalized)
        return {
            "full_path": str(full_path),
            "total_bytes": total_bytes,
            "max_text_kb": max_text_kb,
            "chunked": False,
            "parts": [
                {
                    "index": 1,
                    "path": str(full_path),
                    "bytes": total_bytes,
                    "lines": len(normalized.splitlines()),
                    "time_range": ts_range,
                }
            ],
        }

    parts_text = split_text_by_bytes(normalized, max_bytes=max_bytes, preserve_srt_blocks=preserve_srt_blocks)
    parts_info: List[Dict[str, Any]] = []
    for idx, chunk in enumerate(parts_text, start=1):
        part_path = out_dir / f"{stem}_part_{idx:03d}{suffix}"
        part_path.write_text(chunk, encoding="utf-8", newline="\n")
        parts_info.append(
            {
                "index": idx,
                "path": str(part_path),
                "bytes": part_path.stat().st_size,
                "lines": len(chunk.splitlines()),
                "time_range": extract_timestamp_range(chunk),
            }
        )

    return {
        "full_path": str(full_path),
        "total_bytes": total_bytes,
        "max_text_kb": max_text_kb,
        "chunked": True,
        "parts": parts_info,
    }


def probe_media(path: Path) -> Dict[str, Any]:
    """Query duration and video stream dimensions via ffprobe."""
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        raise RuntimeError("ffprobe not found in PATH")
    rc, out, err = run_cmd(
        [
            ffprobe,
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            str(path),
        ],
        timeout=60,
    )
    if rc != 0:
        raise RuntimeError(f"ffprobe failed: {err[:300]}")
    data = json.loads(out)
    duration = float((data.get("format") or {}).get("duration") or 0.0)
    width = None
    height = None
    for st in data.get("streams") or []:
        if st.get("codec_type") == "video":
            width = st.get("width")
            height = st.get("height")
            break
    return {
        "duration_seconds": duration,
        "width": width,
        "height": height,
        "bytes": path.stat().st_size,
        "size_mb": round(path.stat().st_size / (1024 * 1024), 3),
    }


def build_ytdlp_base_cmd(
    cookies: Optional[str],
    cookies_from_browser: Optional[str],
) -> List[str]:
    cmd = ["yt-dlp", "--no-warnings"]
    if shutil.which("node"):
        cmd.extend(["--js-runtimes", "node"])
    if cookies:
        cmd.extend(["--cookies", cookies])
    elif cookies_from_browser:
        cmd.extend(["--cookies-from-browser", cookies_from_browser])
    return cmd


def choose_best_subtitle_file(sub_dir: Path) -> Optional[Path]:
    exts = (".vtt", ".srt", ".bcc", ".json", ".ass")
    files = [p for p in sub_dir.rglob("*") if p.is_file() and p.suffix.lower() in exts]
    if not files:
        return None

    def score(p: Path) -> Tuple[int, int]:
        name = p.name.lower()
        lang_score = 0
        if any(k in name for k in ("zh-cn", "zh-hans", "ai-zh", ".zh.")):
            lang_score = 40
        elif "zh" in name:
            lang_score = 30
        elif ".en." in name or "en-" in name:
            lang_score = 20
        else:
            lang_score = 10
        ext_priority = {".vtt": 5, ".srt": 4, ".bcc": 3, ".json": 2, ".ass": 1}.get(p.suffix.lower(), 0)
        return (lang_score, ext_priority)

    files.sort(key=score, reverse=True)
    return files[0]


def cmd_doctor(_args: argparse.Namespace) -> int:
    tools = detect_tools()
    prompts: List[Dict[str, Any]] = []
    if not tools["yt_dlp"]["installed"] or not tools["ffmpeg"]["installed"]:
        missing = [k for k in ("yt-dlp", "ffmpeg") if not tools[k.replace("-", "_")]["installed"]]
        prompts.append(
            {
                "type": "missing_core_tools",
                "missing": missing,
                "install_commands": [f"scoop install {' '.join(missing)}"],
            }
        )
    if not tools["bbdown"]["installed"]:
        prompts.append(
            make_bbdown_install_prompt(
                "仅当需要解析 B站 1080P/4K 高清流或受登录限制的 B站 AI 字幕时推荐安装 BBDown；不会自动下载进技能库。"
            )
        )
    payload = {
        "status": "ok",
        "tools": tools,
        "prompts": prompts,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def cmd_fetch(args: argparse.Namespace) -> int:
    tools = detect_tools()
    if not tools["yt_dlp"]["installed"]:
        print(
            json.dumps(
                {
                    "status": "error",
                    "error": "yt-dlp not found in PATH",
                    "install_hint": "scoop install yt-dlp ffmpeg",
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 1

    url = args.url
    bili = is_bilibili_url(url)
    cookie_file = find_cookie_file(args.cookies)
    browser = args.cookies_from_browser
    prompts: List[Dict[str, Any]] = []
    warnings: List[str] = []

    # Step 1: Fetch metadata via yt-dlp
    meta_cmd = build_ytdlp_base_cmd(cookie_file, browser) + ["--skip-download", "-J", url]
    rc, out, err = run_cmd(meta_cmd, timeout=90)
    edge_abe_blocked = False

    if rc != 0 and browser and is_edge_or_chrome_abe_error(err):
        edge_abe_blocked = True
        warnings.append(
            f"yt-dlp 无法从 {browser} 直接解密 Cookie（Windows Edge/Chrome 127+ App-Bound Encryption 限制），已回退无 Cookie 元数据查询。"
        )
        if bili and not tools["bbdown"]["installed"]:
            prompts.append(
                make_bbdown_install_prompt(
                    "Edge Cookie 被 Windows App-Bound Encryption 拦截；安装 BBDown 并扫码登录一次可稳定解析 B站高清流与 AI 字幕。"
                )
            )
        meta_cmd = build_ytdlp_base_cmd(None, None) + ["--skip-download", "-J", url]
        rc, out, err = run_cmd(meta_cmd, timeout=90)

    metadata: Dict[str, Any] = {
        "video_id": extract_bvid(url) or "video",
        "title": "Unknown",
        "webpage_url": url,
        "channel": "Unknown",
        "duration_seconds": 0,
        "duration": "00:00",
        "upload_date": "",
        "description": "",
        "extracted_links": [],
        "is_bilibili": bili,
    }

    if rc == 0 and out.strip():
        try:
            info = json.loads(out)
            duration = int(info.get("duration") or 0)
            desc = info.get("description") or ""
            metadata.update(
                {
                    "video_id": str(info.get("id") or extract_bvid(url) or "video"),
                    "title": info.get("title") or "Unknown",
                    "webpage_url": info.get("webpage_url") or url,
                    "channel": info.get("channel") or info.get("uploader") or "Unknown",
                    "duration_seconds": duration,
                    "duration": format_timestamp(duration),
                    "upload_date": info.get("upload_date") or "",
                    "description": desc,
                    "extracted_links": extract_links_from_text(desc),
                    "extractor": info.get("extractor_key") or info.get("extractor") or "",
                }
            )
        except json.JSONDecodeError:
            warnings.append("yt-dlp 返回的元数据无法解析为 JSON。")
    else:
        warnings.append(f"yt-dlp 获取元数据失败：{err.strip()[:260]}")

    work_dir = (
        Path(args.out_dir).resolve()
        if args.out_dir
        else Path(tempfile.gettempdir()) / "video-summary" / sanitize_filename(metadata["video_id"])
    )
    work_dir.mkdir(parents=True, exist_ok=True)
    sub_dir = work_dir / "raw_subtitles"
    sub_dir.mkdir(parents=True, exist_ok=True)

    (work_dir / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    # Step 2: Fetch subtitles (BBDown first on Bilibili when installed, then yt-dlp)
    transcript_source: Optional[str] = None
    sub_file: Optional[Path] = None

    if bili and args.engine in ("auto", "bbdown") and tools["bbdown"]["installed"]:
        bb_cmd = [tools["bbdown"]["path"], "--sub-only", "--work-dir", str(sub_dir), url]
        bb_rc, _bb_out, bb_err = run_cmd(bb_cmd, cwd=sub_dir, timeout=120)
        sub_file = choose_best_subtitle_file(sub_dir)
        if sub_file:
            transcript_source = "bbdown_subtitle"
        elif bb_rc != 0:
            warnings.append(f"BBDown 字幕拉取未命中，将回退 yt-dlp：{bb_err.strip()[:200]}")

    if not sub_file and args.engine in ("auto", "ytdlp"):
        active_browser = None if edge_abe_blocked else browser
        sub_cmd = build_ytdlp_base_cmd(cookie_file, active_browser) + [
            "--skip-download",
            "--write-subs",
            "--write-auto-subs",
            "--sub-langs",
            args.sub_langs,
            "--sub-format",
            "vtt/srt/best",
            "-o",
            str(sub_dir / "%(id)s.%(ext)s"),
            url,
        ]
        s_rc, _s_out, s_err = run_cmd(sub_cmd, timeout=120)
        if s_rc != 0 and active_browser and is_edge_or_chrome_abe_error(s_err):
            edge_abe_blocked = True
            warnings.append(f"yt-dlp 拉字幕时被 {active_browser} App-Bound Encryption 拦截。")
        sub_file = choose_best_subtitle_file(sub_dir)
        if sub_file:
            transcript_source = "ytdlp_subtitle"

    entries: List[Tuple[float, str]] = []
    transcript_bundle: Optional[Dict[str, Any]] = None
    if sub_file:
        entries = parse_subtitle_file(sub_file)
        if entries:
            md_text = render_transcript_markdown(entries, metadata=metadata)
            transcript_bundle = write_text_chunks(
                md_text,
                out_dir=work_dir,
                stem="transcript",
                suffix=".md",
                max_text_kb=args.max_text_kb,
            )

    if not entries and bili and not tools["bbdown"]["installed"] and not cookie_file:
        if not any(p.get("tool") == "bbdown" for p in prompts):
            prompts.append(
                make_bbdown_install_prompt(
                    "未获取到该 B站视频的公开字幕（B站 AI 字幕通常需登录态）。可按需在本机安装 BBDown 并扫码登录，或导出 Edge cookies.txt，或改走本地 ASR 兜底。"
                )
            )

    manifest = {
        "status": "ok",
        "work_dir": str(work_dir),
        "metadata_path": str(work_dir / "metadata.json"),
        "metadata": {
            "video_id": metadata["video_id"],
            "title": metadata["title"],
            "channel": metadata["channel"],
            "duration": metadata["duration"],
            "upload_date": metadata["upload_date"],
            "webpage_url": metadata["webpage_url"],
            "extracted_links": metadata["extracted_links"],
        },
        "has_transcript": bool(entries),
        "transcript_source": transcript_source,
        "raw_subtitle_file": str(sub_file) if sub_file else None,
        "transcript": transcript_bundle,
        "edge_abe_blocked": edge_abe_blocked,
        "bbdown_available": tools["bbdown"]["installed"],
        "warnings": warnings,
        "prompts": prompts,
    }

    manifest_path = work_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


def cmd_split_text(args: argparse.Namespace) -> int:
    in_path = Path(args.input).resolve()
    if not in_path.is_file():
        print(json.dumps({"status": "error", "error": f"Input file not found: {in_path}"}, ensure_ascii=False))
        return 1

    out_dir = Path(args.out_dir).resolve() if args.out_dir else in_path.parent / f"{in_path.stem}_parts"
    text = in_path.read_text(encoding="utf-8", errors="replace")
    preserve_srt = in_path.suffix.lower() in (".srt", ".vtt")
    bundle = write_text_chunks(
        text,
        out_dir=out_dir,
        stem=in_path.stem,
        suffix=in_path.suffix or ".txt",
        max_text_kb=args.max_text_kb,
        preserve_srt_blocks=preserve_srt,
    )
    result = {
        "status": "ok",
        "source": str(in_path),
        "out_dir": str(out_dir),
        **bundle,
    }
    (out_dir / "split_manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_download(args: argparse.Namespace) -> int:
    tools = detect_tools()
    url = args.url
    bili = is_bilibili_url(url)
    cookie_file = find_cookie_file(args.cookies)
    browser = args.cookies_from_browser
    out_dir = (
        Path(args.out_dir).resolve()
        if args.out_dir
        else Path(tempfile.gettempdir()) / "video-summary" / sanitize_filename(extract_bvid(url) or "download")
    )
    out_dir.mkdir(parents=True, exist_ok=True)

    # Gate Bilibili HD video downloads when BBDown is missing and no auth is provided
    if (
        bili
        and args.mode == "video"
        and args.engine == "auto"
        and not tools["bbdown"]["installed"]
        and not cookie_file
        and not browser
        and not args.fallback_unauth
    ):
        payload = {
            "status": "needs_user_choice",
            "reason": "未检测到 BBDown，且未提供登录 Cookie；无鉴权直接下载 B站视频通常仅能拿到 360P/480P，无法看清高清代码/PPT。",
            "prompts": [
                make_bbdown_install_prompt(
                    "如需稳定下载 B站 1080P/4K 高清视频，建议现在在本机安装 BBDown 并扫码登录一次（或提供 Edge 导出的 cookies.txt / 显式加 --fallback-unauth 降级下载）。"
                )
            ],
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 2

    before_files = {p.resolve() for p in out_dir.rglob("*") if p.is_file()}
    engine_used = ""
    warnings: List[str] = []

    if bili and args.engine in ("auto", "bbdown") and tools["bbdown"]["installed"]:
        engine_used = "bbdown"
        bb_cmd = [tools["bbdown"]["path"], "--work-dir", str(out_dir)]
        if args.mode == "audio":
            bb_cmd.append("--audio-only")
        elif args.quality:
            bb_cmd.extend(["-dfn-priority", args.quality])
        bb_cmd.append(url)
        rc, out, err = run_cmd(bb_cmd, cwd=out_dir, timeout=1800)
        if rc != 0:
            print(
                json.dumps(
                    {
                        "status": "error",
                        "engine": "bbdown",
                        "error": (err or out).strip()[-400:],
                        "hint": "若提示未登录或画质受限，请先在终端执行 BBDown login 扫码登录。",
                    },
                    ensure_ascii=False,
                    indent=2,
                )
            )
            return 1
    else:
        if not tools["yt_dlp"]["installed"]:
            print(json.dumps({"status": "error", "error": "yt-dlp not found in PATH"}, ensure_ascii=False))
            return 1
        engine_used = "yt-dlp"
        dl_cmd = build_ytdlp_base_cmd(cookie_file, browser)
        if args.mode == "audio":
            dl_cmd.extend(["-f", "bestaudio/best", "-x", "--audio-format", "m4a"])
        else:
            dl_cmd.extend(["-f", "bestvideo+bestaudio/best", "--merge-output-format", "mp4"])
        dl_cmd.extend(["-o", str(out_dir / "%(id)s.%(ext)s"), url])
        rc, out, err = run_cmd(dl_cmd, timeout=1800)
        if rc != 0:
            prompts = []
            if browser and is_edge_or_chrome_abe_error(err) and bili and not tools["bbdown"]["installed"]:
                prompts.append(
                    make_bbdown_install_prompt(
                        f"yt-dlp 从 {browser} 读取 Cookie 被 Windows App-Bound Encryption 拦截；建议安装 BBDown 并扫码登录。"
                    )
                )
            print(
                json.dumps(
                    {
                        "status": "error",
                        "engine": "yt-dlp",
                        "error": (err or out).strip()[-400:],
                        "prompts": prompts,
                    },
                    ensure_ascii=False,
                    indent=2,
                )
            )
            return 1

    after_files = [p.resolve() for p in out_dir.rglob("*") if p.is_file() and p.resolve() not in before_files]
    media_exts = {".mp4", ".mkv", ".webm", ".m4a", ".mp3", ".aac", ".flac", ".wav", ".opus"}
    media_files = [p for p in after_files if p.suffix.lower() in media_exts]
    media_files.sort(key=lambda p: p.stat().st_size, reverse=True)
    primary = media_files[0] if media_files else (after_files[0] if after_files else None)
    media_info = probe_media(primary) if (primary and tools["ffprobe"]["installed"]) else None

    result = {
        "status": "ok",
        "engine": engine_used,
        "mode": args.mode,
        "out_dir": str(out_dir),
        "primary_file": str(primary) if primary else None,
        "media_info": media_info,
        "warnings": warnings,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def split_mp4_to_max_mb(
    input_mp4: Path,
    out_dir: Path,
    stem: str,
    max_mb: float,
) -> List[Dict[str, Any]]:
    """Split a compressed MP4 into segments each <= max_mb using stream copy."""
    info = probe_media(input_mp4)
    duration = info["duration_seconds"]
    actual_mb = info["size_mb"]
    if duration <= 0 or actual_mb <= max_mb:
        return [
            {
                "index": 1,
                "path": str(input_mp4),
                "size_mb": actual_mb,
                "bytes": info["bytes"],
                "duration_seconds": round(duration, 2),
            }
        ]

    # Estimate conservative segment duration with safety factor, shrink if any VBR chunk exceeds cap
    safety = 0.88
    parts_meta: List[Dict[str, Any]] = []
    for _attempt in range(3):
        for old in out_dir.glob(f"{stem}_part_*.mp4"):
            old.unlink(missing_ok=True)

        seg_count = max(2, math.ceil((actual_mb / (max_mb * safety))))
        seg_seconds = max(2, int(math.floor(duration / seg_count)))
        pattern = out_dir / f"{stem}_part_%03d.mp4"
        rc, _out, err = run_cmd(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(input_mp4),
                "-c",
                "copy",
                "-map",
                "0",
                "-f",
                "segment",
                "-segment_time",
                str(seg_seconds),
                "-reset_timestamps",
                "1",
                str(pattern),
            ],
            timeout=600,
        )
        if rc != 0:
            raise RuntimeError(f"ffmpeg segment split failed: {err[:300]}")

        part_files = sorted(out_dir.glob(f"{stem}_part_*.mp4"))
        parts_meta = []
        oversized = False
        for idx, pf in enumerate(part_files, start=1):
            p_info = probe_media(pf)
            if p_info["size_mb"] > max_mb:
                oversized = True
            parts_meta.append(
                {
                    "index": idx,
                    "path": str(pf),
                    "size_mb": p_info["size_mb"],
                    "bytes": p_info["bytes"],
                    "duration_seconds": round(p_info["duration_seconds"], 2),
                }
            )
        if not oversized:
            break
        safety *= 0.72

    return parts_meta


def cmd_compress(args: argparse.Namespace) -> int:
    tools = detect_tools()
    if not tools["ffmpeg"]["installed"] or not tools["ffprobe"]["installed"]:
        print(json.dumps({"status": "error", "error": "ffmpeg/ffprobe not found in PATH"}, ensure_ascii=False))
        return 1

    in_path = Path(args.input).resolve()
    if not in_path.is_file():
        print(json.dumps({"status": "error", "error": f"Input video not found: {in_path}"}, ensure_ascii=False))
        return 1

    out_dir = Path(args.out_dir).resolve() if args.out_dir else in_path.parent / "ai_compressed"
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = sanitize_filename(args.output_name or f"{in_path.stem}_ai_small")
    compressed_path = out_dir / f"{stem}.mp4"

    vf = f"fps={args.fps},scale={args.width}:-2"
    gop = max(1, int(round(args.fps * 5)))
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(in_path),
        "-vf",
        vf,
        "-c:v",
        "libx264",
        "-g",
        str(gop),
        "-keyint_min",
        str(gop),
        "-sc_threshold",
        "0",
        "-crf",
        str(args.crf),
        "-preset",
        args.preset,
        "-ac",
        "1",
        "-b:a",
        args.audio_bitrate,
        "-movflags",
        "+faststart",
        str(compressed_path),
    ]
    rc, _out, err = run_cmd(cmd, timeout=1800)
    if rc != 0:
        print(json.dumps({"status": "error", "error": f"ffmpeg compress failed: {err[-400:]}"}, ensure_ascii=False))
        return 1

    orig_info = probe_media(in_path)
    comp_info = probe_media(compressed_path)
    split_needed = args.max_mb > 0 and comp_info["size_mb"] > args.max_mb
    if split_needed:
        parts = split_mp4_to_max_mb(compressed_path, out_dir, stem, args.max_mb)
    else:
        parts = [
            {
                "index": 1,
                "path": str(compressed_path),
                "size_mb": comp_info["size_mb"],
                "bytes": comp_info["bytes"],
                "duration_seconds": round(comp_info["duration_seconds"], 2),
            }
        ]

    result = {
        "status": "ok",
        "input": str(in_path),
        "input_size_mb": orig_info["size_mb"],
        "compressed_path": str(compressed_path),
        "compressed_size_mb": comp_info["size_mb"],
        "max_mb": args.max_mb,
        "split": split_needed,
        "all_parts_within_limit": all((p["size_mb"] <= args.max_mb) for p in parts) if args.max_mb > 0 else True,
        "ffmpeg_recipe": {
            "vf": vf,
            "crf": args.crf,
            "preset": args.preset,
            "audio_channels": 1,
            "audio_bitrate": args.audio_bitrate,
        },
        "parts": parts,
    }
    (out_dir / "compress_manifest.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_keyframes(args: argparse.Namespace) -> int:
    tools = detect_tools()
    if not tools["ffmpeg"]["installed"]:
        print(json.dumps({"status": "error", "error": "ffmpeg not found in PATH"}, ensure_ascii=False))
        return 1

    in_path = Path(args.input).resolve()
    if not in_path.is_file():
        print(json.dumps({"status": "error", "error": f"Input video not found: {in_path}"}, ensure_ascii=False))
        return 1

    out_dir = Path(args.out_dir).resolve() if args.out_dir else in_path.parent / "keyframes"
    out_dir.mkdir(parents=True, exist_ok=True)
    frames: List[Dict[str, Any]] = []
    scale_filter = f"scale='min({args.max_width},iw)':-2" if args.max_width > 0 else None

    if args.mode == "timestamps":
        if not args.timestamps:
            print(json.dumps({"status": "error", "error": "--timestamps is required in timestamps mode"}, ensure_ascii=False))
            return 1
        raw_ts = [t.strip() for t in re.split(r"[,\s]+", args.timestamps.strip()) if t.strip()]
        for idx, ts in enumerate(raw_ts, start=1):
            secs = parse_timestamp_to_seconds(ts)
            out_img = out_dir / f"frame_{idx:02d}_{format_ts_slug(secs)}.jpg"
            cmd = ["ffmpeg", "-y", "-ss", str(secs), "-i", str(in_path), "-frames:v", "1"]
            if scale_filter:
                cmd.extend(["-vf", scale_filter])
            cmd.extend(["-q:v", str(args.quality), str(out_img)])
            rc, _out, err = run_cmd(cmd, timeout=120)
            if rc != 0 or not out_img.is_file():
                continue
            frames.append(
                {
                    "index": idx,
                    "timestamp": format_timestamp(secs),
                    "seconds": round(secs, 2),
                    "path": str(out_img),
                    "bytes": out_img.stat().st_size,
                }
            )
    else:
        # Scene-change detection with timestamp logging, minimum gap dedupe, and hard cap
        vf_parts = [f"select='gt(scene,{args.threshold})'"]
        if scale_filter:
            vf_parts.append(scale_filter)
        vf_parts.append("showinfo")
        tmp_dir = out_dir / "_scene_candidates"
        if tmp_dir.exists():
            shutil.rmtree(tmp_dir)
        tmp_dir.mkdir(parents=True, exist_ok=True)
        pattern = tmp_dir / "cand_%04d.jpg"
        rc, _out, err = run_cmd(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(in_path),
                "-vf",
                ",".join(vf_parts),
                "-vsync",
                "vfr",
                "-q:v",
                str(args.quality),
                str(pattern),
            ],
            timeout=900,
        )
        if rc != 0:
            print(json.dumps({"status": "error", "error": f"ffmpeg scene detection failed: {err[-400:]}"}, ensure_ascii=False))
            return 1

        pts_times = [float(m) for m in re.findall(r"pts_time:([0-9]+(?:\.[0-9]+)?)", err)]
        cand_files = sorted(tmp_dir.glob("cand_*.jpg"))
        paired = []
        for idx, cf in enumerate(cand_files):
            ts_sec = pts_times[idx] if idx < len(pts_times) else 0.0
            paired.append((ts_sec, cf))

        # Apply minimum time gap filter
        filtered: List[Tuple[float, Path]] = []
        last_sec = -1e9
        for ts_sec, cf in paired:
            if ts_sec - last_sec >= args.min_gap:
                filtered.append((ts_sec, cf))
                last_sec = ts_sec

        # Uniformly cap to max_frames so context never explodes
        if args.max_frames > 0 and len(filtered) > args.max_frames:
            step = len(filtered) / args.max_frames
            filtered = [filtered[int(i * step)] for i in range(args.max_frames)]

        for idx, (ts_sec, cf) in enumerate(filtered, start=1):
            dest = out_dir / f"scene_{idx:02d}_{format_ts_slug(ts_sec)}.jpg"
            shutil.move(str(cf), str(dest))
            frames.append(
                {
                    "index": idx,
                    "timestamp": format_timestamp(ts_sec),
                    "seconds": round(ts_sec, 2),
                    "path": str(dest),
                    "bytes": dest.stat().st_size,
                }
            )
        shutil.rmtree(tmp_dir, ignore_errors=True)

    result = {
        "status": "ok",
        "mode": args.mode,
        "input": str(in_path),
        "out_dir": str(out_dir),
        "preserved_original_resolution": args.max_width == 0,
        "frame_count": len(frames),
        "frames": frames,
    }
    (out_dir / "keyframes_manifest.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def format_srt_ts(seconds: float) -> str:
    ms_total = max(0, int(round(seconds * 1000)))
    hours, rem = divmod(ms_total, 3600_000)
    minutes, rem = divmod(rem, 60_000)
    secs, ms = divmod(rem, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{ms:03d}"


def cmd_asr(args: argparse.Namespace) -> int:
    if importlib.util.find_spec("faster_whisper") is None:
        print(
            json.dumps(
                {
                    "status": "missing_dependency",
                    "missing": "faster-whisper",
                    "install_command": "pip install faster-whisper",
                    "note": "默认采用 CPU int8 量化，适配无 NVIDIA CUDA 的设备；请确认后再手动安装。",
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 2

    in_path = Path(args.input).resolve()
    if not in_path.is_file():
        print(json.dumps({"status": "error", "error": f"Input audio/video not found: {in_path}"}, ensure_ascii=False))
        return 1

    out_dir = Path(args.out_dir).resolve() if args.out_dir else in_path.parent / "asr_output"
    out_dir.mkdir(parents=True, exist_ok=True)

    from faster_whisper import WhisperModel  # type: ignore

    model = WhisperModel(args.model, device=args.device, compute_type=args.compute_type)
    segments, info = model.transcribe(str(in_path), language=args.language or None, vad_filter=True)

    entries: List[Tuple[float, str]] = []
    srt_blocks: List[str] = []
    for idx, seg in enumerate(segments, start=1):
        text = strip_subtitle_markup(seg.text)
        if not text:
            continue
        entries.append((seg.start, text))
        srt_blocks.append(f"{idx}\n{format_srt_ts(seg.start)} --> {format_srt_ts(seg.end)}\n{text}\n")

    srt_path = out_dir / "asr.srt"
    srt_path.write_text("\n".join(srt_blocks), encoding="utf-8")

    md_text = render_transcript_markdown(entries, metadata={"title": in_path.stem})
    bundle = write_text_chunks(
        md_text,
        out_dir=out_dir,
        stem="asr_transcript",
        suffix=".md",
        max_text_kb=args.max_text_kb,
    )
    result = {
        "status": "ok",
        "source": str(in_path),
        "language": getattr(info, "language", args.language),
        "srt_path": str(srt_path),
        "segment_count": len(entries),
        "transcript": bundle,
    }
    (out_dir / "asr_manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Local video summary pipeline for Bilibili/YouTube/local videos.")
    sub = parser.add_subparsers(dest="command", required=True)

    p_doc = sub.add_parser("doctor", help="Check local CLI dependencies without installing anything.")
    p_doc.set_defaults(func=cmd_doctor)

    p_fetch = sub.add_parser("fetch", help="Fetch video metadata, links, and subtitles with auto text splitting.")
    p_fetch.add_argument("--url", required=True, help="Bilibili, b23.tv, YouTube, or yt-dlp supported URL.")
    p_fetch.add_argument("--out-dir", help="Output directory (defaults to system temp).")
    p_fetch.add_argument("--engine", choices=("auto", "ytdlp", "bbdown"), default="auto")
    p_fetch.add_argument("--cookies", help="Path to Netscape cookies.txt file.")
    p_fetch.add_argument("--cookies-from-browser", help="Browser name for yt-dlp (e.g. firefox, edge, chrome).")
    p_fetch.add_argument("--sub-langs", default="zh-Hans,zh-CN,zh,ai-zh,en.*,en")
    p_fetch.add_argument("--max-text-kb", type=int, default=800, help="Split transcript above this KB cap (default 800KB < 1MB).")
    p_fetch.set_defaults(func=cmd_fetch)

    p_split = sub.add_parser("split-text", help="Split any large transcript/subtitle file below Antigravity 1MB cap.")
    p_split.add_argument("--input", required=True, help="Path to .md/.txt/.srt/.vtt file.")
    p_split.add_argument("--out-dir", help="Output directory for parts.")
    p_split.add_argument("--max-text-kb", type=int, default=800, help="Max size per part in KB (default 800KB).")
    p_split.set_defaults(func=cmd_split_text)

    p_dl = sub.add_parser("download", help="Download HD video or audio track (prompts for BBDown on unauth Bilibili HD).")
    p_dl.add_argument("--url", required=True)
    p_dl.add_argument("--out-dir", help="Output directory.")
    p_dl.add_argument("--mode", choices=("video", "audio"), default="video")
    p_dl.add_argument("--engine", choices=("auto", "bbdown", "ytdlp"), default="auto")
    p_dl.add_argument("--quality", default="1080P 高清,1080P 高码率,1080P 60帧,4K 超清", help="BBDown quality priority.")
    p_dl.add_argument("--cookies", help="Path to Netscape cookies.txt file.")
    p_dl.add_argument("--cookies-from-browser", help="Browser name for yt-dlp.")
    p_dl.add_argument("--fallback-unauth", action="store_true", help="Allow unauthenticated yt-dlp fallback on Bilibili.")
    p_dl.set_defaults(func=cmd_download)

    p_comp = sub.add_parser("compress", help="Compress video with low-fps ffmpeg recipe and auto-split <= max-mb.")
    p_comp.add_argument("--input", required=True)
    p_comp.add_argument("--out-dir")
    p_comp.add_argument("--output-name", help="Output filename stem.")
    p_comp.add_argument("--fps", type=float, default=1.0)
    p_comp.add_argument("--width", type=int, default=720)
    p_comp.add_argument("--crf", type=int, default=30)
    p_comp.add_argument("--preset", default="veryfast")
    p_comp.add_argument("--audio-bitrate", default="32k")
    p_comp.add_argument("--max-mb", type=float, default=18.0, help="Split compressed video if above MB cap (0=disable).")
    p_comp.set_defaults(func=cmd_compress)

    p_kf = sub.add_parser("keyframes", help="Extract original-resolution HD keyframes by timestamp or scene change.")
    p_kf.add_argument("--input", required=True)
    p_kf.add_argument("--out-dir")
    p_kf.add_argument("--mode", choices=("timestamps", "scene"), default="timestamps")
    p_kf.add_argument("--timestamps", help="Comma-separated timestamps, e.g. 01:23,05:40,12:08")
    p_kf.add_argument("--threshold", type=float, default=0.35, help="ffmpeg scene change threshold (0-1).")
    p_kf.add_argument("--max-frames", type=int, default=8, help="Hard cap on extracted scene frames.")
    p_kf.add_argument("--min-gap", type=float, default=5.0, help="Minimum seconds between scene frames.")
    p_kf.add_argument("--max-width", type=int, default=0, help="0 preserves original HD resolution.")
    p_kf.add_argument("--quality", type=int, default=2, help="JPEG quality 2-31 (2 is sharpest).")
    p_kf.set_defaults(func=cmd_keyframes)

    p_asr = sub.add_parser("asr", help="Optional local CPU ASR fallback using faster-whisper.")
    p_asr.add_argument("--input", required=True)
    p_asr.add_argument("--out-dir")
    p_asr.add_argument("--model", default="small")
    p_asr.add_argument("--device", default="cpu")
    p_asr.add_argument("--compute-type", default="int8")
    p_asr.add_argument("--language", default="zh")
    p_asr.add_argument("--max-text-kb", type=int, default=800)
    p_asr.set_defaults(func=cmd_asr)

    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    configure_stdio()
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
