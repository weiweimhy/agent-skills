import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

SCRIPT_DIR = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPT_DIR))

import video_pipeline as vp  # noqa: E402


class VideoPipelineUnitTests(unittest.TestCase):
    def test_parse_vtt_deduplicates_rolling_captions(self) -> None:
        sample = """WEBVTT

00:00:01.000 --> 00:00:03.000
<c>大家好</c>

00:00:03.000 --> 00:00:05.000
大家好 今天讲 AI Agent

00:00:05.000 --> 00:00:07.000
大家好 今天讲 AI Agent
"""
        entries = vp.parse_vtt_or_srt(sample)
        self.assertEqual(entries, [(1.0, "大家好"), (3.0, "今天讲 AI Agent")])

    def test_parse_bcc_json(self) -> None:
        sample = json.dumps(
            {
                "body": [
                    {"from": 12.5, "to": 15.0, "content": "第一句"},
                    {"from": 15.0, "to": 18.0, "content": "第一句"},
                    {"from": 65.0, "to": 70.0, "content": "第二句"},
                ]
            }
        )
        entries = vp.parse_bcc_json(sample)
        self.assertEqual(entries, [(12.5, "第一句"), (65.0, "第二句")])

    def test_extract_links_from_description(self) -> None:
        desc = "项目地址 https://github.com/example/demo，文档见 https://example.com/docs/。重复 https://github.com/example/demo"
        links = vp.extract_links_from_text(desc)
        self.assertEqual(links, ["https://github.com/example/demo", "https://example.com/docs/"])

    def test_split_text_respects_utf8_byte_cap(self) -> None:
        lines = [f"- [{vp.format_timestamp(i * 10)}] 这是一段测试中文逐字稿内容第{i}行。\n" for i in range(120)]
        full = "".join(lines)
        chunks = vp.split_text_by_bytes(full, max_bytes=1024)
        self.assertGreater(len(chunks), 3)
        for chunk in chunks:
            self.assertLessEqual(len(chunk.encode("utf-8")), 1024)
        self.assertEqual("".join(chunks), full)

    def test_split_text_cli_writes_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root / "long_audio.md"
            content = "".join(f"- [00:{i % 60:02d}] 测试音频转写文本内容段落 {i}\n" for i in range(200))
            src.write_text(content, encoding="utf-8")

            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = vp.main(["split-text", "--input", str(src), "--max-text-kb", "2"])
            self.assertEqual(rc, 0)
            res = json.loads(buf.getvalue())
            self.assertTrue(res["chunked"])
            self.assertGreater(len(res["parts"]), 2)
            for part in res["parts"]:
                self.assertLessEqual(part["bytes"], 2048)
                self.assertTrue(Path(part["path"]).is_file())

    def test_bilibili_hd_download_prompts_for_bbdown_instead_of_installing(self) -> None:
        fake_tools = {
            "yt_dlp": {"installed": True, "path": "yt-dlp"},
            "ffmpeg": {"installed": True, "path": "ffmpeg"},
            "ffprobe": {"installed": True, "path": "ffprobe"},
            "bbdown": {"installed": False, "path": None},
            "node": {"installed": True, "path": "node"},
            "faster_whisper": {"installed": False},
            "cookie_file_env_configured": False,
        }
        buf = io.StringIO()
        with mock.patch.object(vp, "detect_tools", return_value=fake_tools), mock.patch.object(
            vp, "find_cookie_file", return_value=None
        ), redirect_stdout(buf):
            rc = vp.main(["download", "--url", "https://www.bilibili.com/video/BV1xx411c7m9", "--mode", "video"])
        self.assertEqual(rc, 2)
        res = json.loads(buf.getvalue())
        self.assertEqual(res["status"], "needs_user_choice")
        self.assertEqual(res["prompts"][0]["tool"], "bbdown")
        self.assertIn("scoop install bbdown", res["prompts"][0]["install_commands"])

    def test_edge_abe_error_detection(self) -> None:
        self.assertTrue(vp.is_edge_or_chrome_abe_error("ERROR: Failed to decrypt with DPAPI / App-Bound Encryption"))
        self.assertFalse(vp.is_edge_or_chrome_abe_error("ERROR: Video unavailable"))

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "ffmpeg/ffprobe required")
    def test_compress_split_and_hd_keyframes_with_real_ffmpeg(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src_video = root / "sample_1080p.mp4"
            # Generate a 12-second 1920x1080 synthetic video so compressed output can split cleanly across keyframes
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-f",
                    "lavfi",
                    "-i",
                    "testsrc2=size=1920x1080:rate=10:duration=12",
                    "-f",
                    "lavfi",
                    "-i",
                    "sine=frequency=440:duration=12",
                    "-c:v",
                    "libx264",
                    "-preset",
                    "ultrafast",
                    "-crf",
                    "26",
                    "-c:a",
                    "aac",
                    str(src_video),
                ],
                check=True,
                capture_output=True,
            )

            # Test HD timestamp keyframes preserve original 1920x1080 resolution
            kf_dir = root / "kf"
            buf_kf = io.StringIO()
            with redirect_stdout(buf_kf):
                rc_kf = vp.main(
                    [
                        "keyframes",
                        "--input",
                        str(src_video),
                        "--out-dir",
                        str(kf_dir),
                        "--mode",
                        "timestamps",
                        "--timestamps",
                        "00:01,00:04",
                    ]
                )
            self.assertEqual(rc_kf, 0)
            kf_res = json.loads(buf_kf.getvalue())
            self.assertEqual(kf_res["frame_count"], 2)
            self.assertTrue(kf_res["preserved_original_resolution"])
            first_frame = Path(kf_res["frames"][0]["path"])
            self.assertTrue(first_frame.is_file())
            frame_info = vp.probe_media(first_frame)
            self.assertEqual((frame_info["width"], frame_info["height"]), (1920, 1080))

            # Test compress recipe (fps=1, scale=720:-2, crf=30, ac=1, 32k) + split trigger via tiny max-mb
            comp_dir = root / "comp"
            buf_c = io.StringIO()
            with redirect_stdout(buf_c):
                rc_c = vp.main(
                    [
                        "compress",
                        "--input",
                        str(src_video),
                        "--out-dir",
                        str(comp_dir),
                        "--max-mb",
                        "18",
                    ]
                )
            self.assertEqual(rc_c, 0)
            c_res = json.loads(buf_c.getvalue())
            self.assertFalse(c_res["split"])
            self.assertTrue(c_res["all_parts_within_limit"])
            comp_info = vp.probe_media(Path(c_res["compressed_path"]))
            self.assertEqual(comp_info["width"], 720)

            # Force auto-split branch with a tiny max-mb below compressed size
            tiny_cap = max(0.01, round(c_res["compressed_size_mb"] * 0.65, 3))
            split_dir = root / "comp_split"
            buf_s = io.StringIO()
            with redirect_stdout(buf_s):
                rc_s = vp.main(
                    [
                        "compress",
                        "--input",
                        str(src_video),
                        "--out-dir",
                        str(split_dir),
                        "--max-mb",
                        str(tiny_cap),
                    ]
                )
            self.assertEqual(rc_s, 0)
            s_res = json.loads(buf_s.getvalue())
            self.assertTrue(s_res["split"])
            self.assertGreaterEqual(len(s_res["parts"]), 2)
            for p in s_res["parts"]:
                self.assertTrue(Path(p["path"]).is_file())


if __name__ == "__main__":
    unittest.main()
