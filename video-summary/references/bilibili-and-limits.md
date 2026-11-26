# B站高清解析、双宿主限制与总结参考

## 1. Windows Edge / Chrome Cookie 加密与 B站高清鉴权

B站从 720P/1080P 起要求登录态，1080P 高码率 / 1080P60 / 4K 需要大会员 Cookie，且高清流采用音视频分离的 DASH 格式（需要 `ffmpeg` 合流）；B站 AI 字幕同样通常需要已登录会话。

Windows 平台下 Chrome 与 Edge 127+ 启用了 **App-Bound Encryption (ABE)**，因此直接执行 `yt-dlp --cookies-from-browser edge` 或 `chrome` 常出现无法解密 Cookie 数据库的问题。推荐按以下顺序处理：

1. **B站高清首选：`BBDown`（按需安装，不入技能库）**
   - 仅在真正需要 B站高清流或受限 AI 字幕、且本机未检测到 `BBDown` 时，向用户说明并询问是否安装：

     ```powershell
     scoop install bbdown
     # 或 winget install nilaoda.BBDown
     ```

   - 安装后在本机执行一次扫码登录：

     ```powershell
     BBDown login
     ```

   - 登录态保存在本机用户目录，不进技能仓库；后续即可绕开 Edge ABE 稳定获取 1080P/4K DASH 与 AI 字幕。
2. **通用方案：`yt-dlp` + 本机私有 `cookies.txt` 或 Firefox**
   - Edge 插件方案：在 Edge 使用 *Get cookies.txt LOCALLY* 导出 B站/YouTube 的 Netscape 格式 `cookies.txt` 到本机私有目录，并通过 `--cookies "<file>"` 或用户环境变量 `VIDEO_SUMMARY_COOKIES` 传入。
   - Firefox 方案：Windows 上 Firefox 不受 Chromium ABE 限制，登录 B站后可直接使用 `--cookies-from-browser firefox`。
   - **安全边界**：绝不把 `cookies.txt`、`SESSDATA` 或 `BBDown.data` 提交到任何 Git 仓库，也不在对话/日志中明文回显 Cookie 值。

## 2. Codex 与 Antigravity 双宿主体积限制

| 媒体类型 | Codex | Antigravity | 脚本自动应对策略 |
| --- | --- | --- | --- |
| 视频文件 | 支持 > 20 MB | 上限 20 MB | `compress` 子命令按 `fps=1, scale=720:-2, libx264, crf 30, veryfast, ac 1, 32k` 压缩；若单文件仍 > `18 MB`，按估算码率自动切分为 `ai_small_part_001.mp4`...（Codex 可设 `--max-mb 0`） |
| 文本 / 字幕 / 转写稿 | 支持 > 1 MB | 上限 1 MB | `fetch`、`split-text`、`asr` 均在完整时间戳/行边界自动切分（默认 `--max-text-kb 800` 适配上传上限；若希望直接用 `read_file` 逐块读取可设 `--max-text-kb 40`） |
| 高清代码 / PPT / UI 小字 | 原画帧更清晰 | 原画帧更清晰且体积小 | `keyframes` 默认保持原始分辨率（1080P/4K，`--max-width 0`），按字幕定位的时间戳精确截单帧（每张约 150~400 KB），避免 720p 压制发糊 |

## 3. CPU 友好的本地 ASR 兜底

若本机无 NVIDIA CUDA（例如 AMD 显卡或纯 CPU），无字幕视频的语音转写建议优先用 CPU `int8` 量化：

```powershell
pip install faster-whisper
python "<skill-dir>/scripts/video_pipeline.py" asr --input "<AUDIO_FILE>" --model small --device cpu --compute-type int8
```

- `base` 速度最快，`small` 对中文技术术语和混合英文术语（如 Agent、MCP、Prompt）准确率更稳。
- 仅在无原生字幕且用户确实需要逐字稿时才触发，不静默执行 `pip install`。

## 4. AI 使用类视频推荐总结模板

对话输出默认采用以下结构；用户确认沉淀到提笔书时，再交由 `tibishu-notes` 补齐标准 Blog front matter 并运行 `Validate-TibishuNote.ps1`：

```markdown
# <视频标题> - 要点总结

- **来源**：<B站 / YouTube> | [原视频链接](<URL>)
- **UP 主 / 频道**：<作者> | **时长**：<MM:SS> | **发布日期**：<YYYY-MM-DD>
- **证据来源**：<B站 AI 字幕 / yt-dlp 字幕 / 本地 ASR / 1080P 关键帧 N 张 / 压缩视频>

## 一句话核心结论

<2~3 句概括视频解决什么问题、核心方法是什么、值不值得复现>

## 提到的工具、模型与链接

- **工具/仓库名**：用途说明（附简介中的真实链接）

## 核心步骤 / 可复用 Prompt 与命令

1. ...

## 关键时间戳大纲

- `[00:00]` ...

## 适用边界、踩坑与待核实

- **视频原话提到的限制**：...
- **未在字幕/画面中确认的细节**：...
```

## 5. 调研参考（上游 GitHub 项目）

本技能设计与脚本架构在实现前评估并参考了以下公开仓库的实践：

- [Roxy-ljy/bilibili-video-summary-skill](https://github.com/Roxy-ljy/bilibili-video-summary-skill)：面向 Codex / Claude Code 的 B站与 YouTube 字幕采集和 JSON 交接思路。
- [RookieCuzz/codex-bilibili-skills](https://github.com/RookieCuzz/codex-bilibili-skills)：将视频证据采集（字幕、ASR 兜底、按时间戳关键帧）与笔记写作解耦的设计模式。
- [nilaoda/BBDown](https://github.com/nilaoda/BBDown)：B站 DASH 高清（1080P/4K）、AI 字幕与扫码登录 CLI 参考。
- [JefferyHcool/BiliNote](https://github.com/JefferyHcool/BiliNote)：字幕时间戳对齐与关键帧辅助笔记生成的成熟产品思路。
- [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp)：跨站点元数据、字幕与音视频流下载底座。
