---
name: video-summary
description: Extract metadata, subtitles, transcripts, compressed Antigravity-safe video chunks, and HD keyframes from Bilibili, b23.tv, YouTube, or local videos for structured AI summarization and optional Tibishu note archival. Use when summarizing video URLs or local video/audio transcripts, especially AI/coding tutorials needing HD code or PPT inspection across Codex and Antigravity.
---

# Video Summary（本地开源视频解析与总结）

以纯本地开源工具流（`yt-dlp`、`ffmpeg`、按需提示安装的 `BBDown` 及可选本地 CPU ASR）完成视频证据采集与结构化总结，兼顾 **Codex** 与 **Antigravity** 的文件体积上限，默认先在对话中输出总结，经用户确认后再衔接 `tibishu-notes` 入库。

## 核心护栏

- **严禁把二进制或凭据放进技能库**：不内置 `BBDown`、`yt-dlp`、`ffmpeg`、`cookies.txt` 或登录缓存，也不静默安装包。
- **按需提示安装 `BBDown`**：仅当本次任务需要解析 B站高清视频（1080P/4K）或受登录限制的 B站 AI 字幕、且本机未检测到 `BBDown` 时，向用户说明原因并询问是否由本机安装（如 `scoop install bbdown` 后执行 `BBDown login`），或改用导出的 `cookies.txt`。
- **绝不靠浏览器拖进度条盲截几十张图**：先拿逐字稿/字幕，再按需压小视频或从高清源精准抽少量原画帧。
- **严禁凭标题脑补内容**：若字幕、ASR 与画面采集均失败，如实报告缺口并请用户补充字幕或凭据。

## 执行工作流

所有命令统一通过内置脚本调用（默认输出到系统临时目录 `video-summary` 下，不污染当前代码仓）：

### 1. 环境预检（按需）

首次使用或遇到鉴权/工具报错时运行，获取本机工具与 `BBDown` 可用状态：

```powershell
python "<skill-dir>/scripts/video_pipeline.py" doctor
```

### 2. Tier 1：抓元数据、简介链接与字幕（默认首选）

先拉标题、UP 主、时长、简介中的工具/仓库链接与带时间戳逐字稿；超阈值自动按完整时间戳边界分段（默认 `800 KB`，安全低于 Antigravity **1 MB** 文本上限）：

```powershell
python "<skill-dir>/scripts/video_pipeline.py" fetch --url "<VIDEO_URL>" --max-text-kb 800
```

- 返回 `manifest.json` 中若含 `prompts`（如提示 Windows Edge App-Bound Encryption 拦截或缺少 `BBDown`），先按提示征求用户选择，再继续。
- 若已有超过 1 MB 的本地字幕/音频转写文本，直接分段：

```powershell
python "<skill-dir>/scripts/video_pipeline.py" split-text --input "<TRANSCRIPT_FILE>" --max-text-kb 800
```

### 3. Tier 2：高清代码 / PPT 画面解析（原画精准抽帧）

当 AI 教程包含代码、终端命令、Prompt 或架构图时，先下载高清视频（B站有 `BBDown` 优先走 `BBDown`，无 `BBDown` 且无 Cookie 时先提示用户安装或提供 Cookie）：

```powershell
python "<skill-dir>/scripts/video_pipeline.py" download --url "<VIDEO_URL>" --mode video
```

再从高清视频抽取 **原分辨率 JPG 关键帧**（不缩 720p，保证小字锐利；默认最多 8 张防上下文爆炸）：

```powershell
# 优先：根据逐字稿定位的时间戳精准截原画
python "<skill-dir>/scripts/video_pipeline.py" keyframes --input "<HD_MP4>" --mode timestamps --timestamps "02:15,06:40,11:05"

# 备选：按场景切变自动抽原画帧
python "<skill-dir>/scripts/video_pipeline.py" keyframes --input "<HD_MP4>" --mode scene --threshold 0.35 --max-frames 8
```

### 4. Tier 3：整段视频多模态压缩与自动分段（适配 Antigravity 20 MB 上限）

需要让多模态模型看连续动态操作时，使用统一 `ffmpeg` 配方压低体积（`fps=1, scale=720:-2, libx264, crf 30, veryfast, ac 1, 32k`）；若压完仍超 `18 MB`，脚本自动按时长切分为多段 `ai_small_part_001.mp4`...（Codex 场景可传 `--max-mb 0` 不切片）：

```powershell
python "<skill-dir>/scripts/video_pipeline.py" compress --input "<HD_MP4>" --max-mb 18
```

### 5. 无字幕兜底（可选 CPU ASR）

视频无公开字幕且需要逐字稿时，先用 `--mode audio` 下载音轨，再执行 CPU 友好的轻量转写（缺 `faster-whisper` 时提示安装命令，不静默安装）：

```powershell
python "<skill-dir>/scripts/video_pipeline.py" asr --input "<AUDIO_FILE>" --model small --device cpu --compute-type int8 --max-text-kb 800
```

## 总结输出与提笔书入库

1. **默认先在对话中输出中文结构化总结**，明确标出证据来源（原生/AI 字幕、ASR、高清关键帧或压缩视频），严禁混同视频原话与外部补充。
2. 针对 **AI 使用 / 编程教程类视频**，固定提炼：
   - **一句话核心结论**
   - **视频信息与简介工具/仓库链接**
   - **核心方法 / 实操步骤 / 可复用 Prompt 或命令**
   - **关键时间戳大纲**
   - **适用边界、踩坑点与待核实项**
3. **仅在用户确认存入笔记库后**，调用 `tibishu-notes` 技能按其目录约定、Blog front matter 与 `Validate-TibishuNote.ps1` 校验流程写入提笔书。

## 按需参考

- Windows Edge ABE 鉴权、`BBDown` 按需安装指引、双宿主大小限制、总结模板与 GitHub 上游参考：见 [B站高清解析与宿主限制参考](references/bilibili-and-limits.md)。
