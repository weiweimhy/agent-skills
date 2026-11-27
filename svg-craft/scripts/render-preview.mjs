#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";
import { isCliEntry, lintSvg, parseXml } from "./lint-svg.mjs";

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PNG_IEND_CHUNK = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]);
const WIN_EXEC_EXTS = new Set([".exe", ".cmd", ".bat", ".com"]);

export function validateBg(bg) {
  if (!bg || typeof bg !== "string") {
    throw new Error("--bg 不能为空。");
  }
  const trimmed = bg.trim();
  if (!trimmed || /[;{}<>\r\n]/.test(trimmed) || trimmed.includes("/*") || trimmed.includes("*/")) {
    throw new Error(`--bg 包含非法 CSS 字符：${bg}`);
  }
  return trimmed;
}

export function isExecutableFile(filePath, platform = process.platform) {
  if (!filePath) return false;
  try {
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) return false;
    if (platform === "win32") {
      return WIN_EXEC_EXTS.has(path.extname(filePath).toLowerCase());
    }
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

export function parseArgs(argv) {
  const opts = {
    file: null,
    out: null,
    scale: 2,
    bg: "transparent",
    browser: null,
    freeze: false,
    standalone: false,
    noSandbox: false,
    skipXmlCheck: false,
    timeMs: null,
    dryRun: false,
    help: false,
  };

  const requireValue = (flag, idx) => {
    if (idx + 1 >= argv.length || argv[idx + 1].startsWith("--")) {
      throw new Error(`参数 ${flag} 缺少取值。`);
    }
    return argv[idx + 1];
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--out" || arg === "-o") {
      opts.out = requireValue(arg, i);
      i += 1;
    } else if (arg === "--scale") {
      const val = Number(requireValue(arg, i));
      i += 1;
      if (!Number.isFinite(val) || val <= 0 || val > 8) {
        throw new Error(`--scale 必须为 (0, 8] 范围内的有效数字。`);
      }
      opts.scale = val;
    } else if (arg === "--bg") {
      opts.bg = validateBg(requireValue(arg, i));
      i += 1;
    } else if (arg === "--browser") {
      opts.browser = requireValue(arg, i);
      i += 1;
    } else if (arg === "--time-ms") {
      const val = Number(requireValue(arg, i));
      i += 1;
      if (!Number.isFinite(val) || val < 0 || val > 60000) {
        throw new Error(`--time-ms 必须为 [0, 60000] 范围内的数字。`);
      }
      opts.timeMs = Math.round(val);
    } else if (arg === "--freeze") {
      opts.freeze = true;
    } else if (arg === "--standalone") {
      opts.standalone = true;
    } else if (arg === "--no-sandbox") {
      opts.noSandbox = true;
    } else if (arg === "--skip-xml-check") {
      opts.skipXmlCheck = true;
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    } else if (arg === "-h" || arg === "--help") {
      opts.help = true;
    } else if (arg.startsWith("-")) {
      throw new Error(`未知参数：${arg}（使用 --help 查看用法）`);
    } else if (!opts.file) {
      opts.file = arg;
    } else {
      throw new Error(`检测到多余的位置参数：${arg}`);
    }
  }

  if (opts.standalone && opts.freeze) {
    throw new Error("--standalone 模式不支持 --freeze（原生直渲无法注入 t=0 暂停脚本），请移除其中一个参数。");
  }
  if (opts.standalone && opts.bg !== "transparent") {
    throw new Error("--standalone 模式不支持自定义 --bg，请使用默认包装模式或移除 --bg。");
  }

  if (opts.timeMs === null) {
    opts.timeMs = opts.freeze ? 200 : 1500;
  }
  return opts;
}

function parseAbsolutePx(val) {
  if (!val) return NaN;
  const trimmed = String(val).trim();
  if (trimmed.endsWith("%")) return NaN;
  const m = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))(?:px)?$/i);
  return m ? Number(m[1]) : NaN;
}

export function detectSvgSize(svgContent) {
  const { rootElements } = parseXml(svgContent);
  const svgRoot = rootElements.find((el) => el.tag.toLowerCase() === "svg");
  if (svgRoot) {
    const vbStr = svgRoot.attrs.viewBox;
    if (vbStr) {
      const parts = vbStr.trim().split(/[\s,]+/).map(Number);
      if (parts.length === 4 && parts.every((n) => Number.isFinite(n)) && parts[2] > 0 && parts[3] > 0) {
        return { width: Math.ceil(parts[2]), height: Math.ceil(parts[3]) };
      }
    }
    const w = parseAbsolutePx(svgRoot.attrs.width);
    const h = parseAbsolutePx(svgRoot.attrs.height);
    if (Number.isFinite(w) && Number.isFinite(h) && w > 0 && h > 0) {
      return { width: Math.ceil(w), height: Math.ceil(h) };
    }
  }
  return { width: 1280, height: 720 };
}

function searchPathForExecutables(names, env = process.env, platform = process.platform) {
  const pathEnv = env.PATH || env.Path || "";
  if (!pathEnv) return null;
  const dirs = pathEnv.split(path.delimiter).filter(Boolean);
  for (const dir of dirs) {
    for (const name of names) {
      const full = path.join(dir, name);
      if (isExecutableFile(full, platform)) return full;
    }
  }
  return null;
}

export function sortChromiumRevisionDirs(dirs) {
  const parseRev = (name) => {
    const m = name.match(/(\d+)$/);
    return m ? Number(m[1]) : -1;
  };
  return [...dirs].sort((a, b) => {
    const diff = parseRev(b) - parseRev(a);
    return diff !== 0 ? diff : b.localeCompare(a);
  });
}

function findPlaywrightChromium(platform = process.platform, env = process.env, homeDir = os.homedir()) {
  const roots = [];
  if (env.PLAYWRIGHT_BROWSERS_PATH && env.PLAYWRIGHT_BROWSERS_PATH !== "0") {
    roots.push(env.PLAYWRIGHT_BROWSERS_PATH);
  }
  if (platform === "win32") {
    if (env.LOCALAPPDATA) roots.push(path.join(env.LOCALAPPDATA, "ms-playwright"));
  } else if (platform === "darwin") {
    roots.push(path.join(homeDir, "Library", "Caches", "ms-playwright"));
  } else {
    roots.push(path.join(homeDir, ".cache", "ms-playwright"));
  }

  for (const root of roots) {
    if (!root || !fs.existsSync(root)) continue;
    let entries = [];
    try {
      entries = sortChromiumRevisionDirs(fs.readdirSync(root).filter((d) => d.startsWith("chromium")));
    } catch {
      continue;
    }
    for (const dir of entries) {
      const candidates =
        platform === "win32"
          ? [
              path.join(root, dir, "chrome-win", "chrome.exe"),
              path.join(root, dir, "chrome-win64", "chrome.exe"),
            ]
          : platform === "darwin"
            ? [
                path.join(root, dir, "chrome-mac", "Chromium.app", "Contents", "MacOS", "Chromium"),
                path.join(root, dir, "chrome-mac-arm64", "Google Chrome for Testing.app", "Contents", "MacOS", "Google Chrome for Testing"),
              ]
            : [
                path.join(root, dir, "chrome-linux", "chrome"),
                path.join(root, dir, "chrome-linux64", "chrome"),
              ];
      for (const c of candidates) {
        if (isExecutableFile(c, platform)) return c;
      }
    }
  }
  return null;
}

export function findBrowser(explicitPath, env = process.env, platform = process.platform) {
  if (explicitPath) {
    if (!isExecutableFile(explicitPath, platform)) {
      throw new Error(`指定的 --browser 不是有效的可执行文件：${explicitPath}`);
    }
    return explicitPath;
  }

  for (const envKey of ["CHROME_PATH", "EDGE_PATH"]) {
    if (env[envKey] && isExecutableFile(env[envKey], platform)) {
      return env[envKey];
    }
  }

  const localAppData = env.LOCALAPPDATA || "";
  const userProfile = env.USERPROFILE || "";
  const candidates = [];

  if (platform === "win32") {
    candidates.push(
      "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
      "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
      "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
    );
    if (localAppData) {
      candidates.push(
        path.join(localAppData, "Microsoft", "Edge", "Application", "msedge.exe"),
        path.join(localAppData, "Google", "Chrome", "Application", "chrome.exe")
      );
    }
    if (userProfile) {
      candidates.push(
        path.join(userProfile, "scoop", "apps", "googlechrome", "current", "chrome.exe"),
        path.join(userProfile, "scoop", "apps", "chromium", "current", "chrome.exe")
      );
    }
  } else if (platform === "darwin") {
    candidates.push(
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
      "/Applications/Chromium.app/Contents/MacOS/Chromium"
    );
  } else {
    candidates.push(
      "/usr/bin/google-chrome",
      "/usr/bin/google-chrome-stable",
      "/usr/bin/microsoft-edge",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser",
      "/snap/bin/chromium"
    );
  }

  for (const p of candidates) {
    if (isExecutableFile(p, platform)) return p;
  }

  const pathNames =
    platform === "win32"
      ? ["msedge.exe", "chrome.exe", "chromium.exe"]
      : ["google-chrome", "google-chrome-stable", "microsoft-edge", "chromium", "chromium-browser"];
  const fromPath = searchPathForExecutables(pathNames, env, platform);
  if (fromPath) return fromPath;

  return findPlaywrightChromium(platform, env);
}

export function buildDefaultOutPath(svgPath) {
  const stem = path.basename(svgPath, path.extname(svgPath));
  const shortHash = crypto.createHash("sha256").update(svgPath).digest("hex").slice(0, 8);
  return path.join(os.tmpdir(), "svg-craft-previews", `${stem}-${shortHash}.png`);
}

function isSameFilePath(a, b, platform = process.platform) {
  try {
    const sa = fs.statSync(a, { bigint: true });
    const sb = fs.statSync(b, { bigint: true });
    if (sa.ino !== 0n && sa.dev === sb.dev && sa.ino === sb.ino) {
      return true;
    }
  } catch {
    // One or both paths may not exist yet; fall back to path comparison
  }
  const norm = (p) => {
    try {
      return fs.realpathSync(p);
    } catch {
      return path.resolve(p);
    }
  };
  const na = norm(a);
  const nb = norm(b);
  return platform === "win32" ? na.toLowerCase() === nb.toLowerCase() : na === nb;
}

export function readPngDimensions(pngPath) {
  const buf = fs.readFileSync(pngPath);
  if (buf.length < 45 || !buf.subarray(0, 8).equals(PNG_SIGNATURE)) return null;
  if (buf.readUInt32BE(8) !== 13 || buf.toString("ascii", 12, 16) !== "IHDR") return null;
  if (!buf.includes(PNG_IEND_CHUNK)) return null;
  const width = buf.readUInt32BE(16);
  const height = buf.readUInt32BE(20);
  if (width <= 0 || height <= 0) return null;
  return { width, height };
}

export function buildPreviewHtml(svgPath, svgContent, width, height, opts) {
  const baseHref = pathToFileURL(path.dirname(svgPath) + path.sep).href;
  const freezeCss = opts.freeze
    ? `*, *::before, *::after { animation-play-state: paused !important; transition-duration: 0s !important; }`
    : "";
  const freezeScript = opts.freeze
    ? `<script>
    const rootSvg = document.querySelector("body > svg");
    if (rootSvg && typeof rootSvg.pauseAnimations === "function") {
      rootSvg.pauseAnimations();
      try { rootSvg.setCurrentTime(0); } catch {}
    }
    if (typeof document.getAnimations === "function") {
      for (const anim of document.getAnimations({ subtree: true })) {
        try {
          anim.pause();
          anim.currentTime = 0;
        } catch {}
      }
    }
  </script>`
    : "";

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <base href="${baseHref}" />
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    ${freezeCss}
    html, body {
      width: ${width}px;
      height: ${height}px;
      overflow: hidden;
      background: ${opts.bg};
    }
    body > svg {
      display: block;
      width: ${width}px;
      height: ${height}px;
    }
  </style>
</head>
<body>
${svgContent}
${freezeScript}
</body>
</html>`;
}

function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (err) {
    console.error(`错误：${err.message}`);
    process.exit(1);
  }

  if (opts.help) {
    console.log(
      "Usage: node render-preview.mjs <file.svg> [options]\n" +
        "Options:\n" +
        "  --out, -o <path>   Output PNG path (defaults to OS temp dir svg-craft-previews/)\n" +
        "  --scale <N>        Device scale factor in (0, 8] (default: 2)\n" +
        "  --bg <css-color>   Wrapper background color (default: transparent)\n" +
        "  --freeze           Freeze SMIL/CSS animations at t=0 for static-frame verification\n" +
        "  --time-ms <N>      Virtual time budget in ms (default: 1500, or 200 with --freeze)\n" +
        "  --standalone       Open the raw .svg URL directly in Edge/Chrome instead of HTML wrapper\n" +
        "  --no-sandbox       Pass --no-sandbox to Chromium (disabled by default for safety)\n" +
        "  --browser <path>   Explicit Edge/Chrome executable path\n" +
        "  --skip-xml-check   Skip pre-render XML well-formedness gate\n" +
        "  --dry-run          Print resolved render plan as JSON without launching browser"
    );
    process.exit(0);
  }

  if (!opts.file) {
    console.error("错误：请指定要渲染的 SVG 文件路径。");
    process.exit(1);
  }

  const svgPath = path.resolve(opts.file);
  if (!fs.existsSync(svgPath)) {
    console.error(`错误：文件不存在 -> ${svgPath}`);
    process.exit(1);
  }

  const svgContent = fs.readFileSync(svgPath, "utf8");

  if (!opts.skipXmlCheck) {
    const check = lintSvg(svgContent, { inline: false });
    if (!check.ok) {
      console.error("错误：渲染前 XML 校验未通过，已中止渲染（避免 HTML 包装掩盖独立 SVG 解析错误）：");
      for (const e of check.errors) console.error(`  [ERROR] ${e}`);
      process.exit(1);
    }
  }

  const { width, height } = detectSvgSize(svgContent);
  const outPath = path.resolve(opts.out || buildDefaultOutPath(svgPath));
  if (isSameFilePath(svgPath, outPath)) {
    console.error(`错误：输出路径不能与输入 SVG 文件相同 -> ${outPath}`);
    process.exit(1);
  }

  let browserPath = null;
  try {
    browserPath = findBrowser(opts.browser);
  } catch (err) {
    console.error(`错误：${err.message}`);
    process.exit(1);
  }

  if (opts.dryRun) {
    console.log(
      JSON.stringify(
        {
          svgPath,
          outPath,
          width,
          height,
          scale: opts.scale,
          bg: opts.bg,
          freeze: opts.freeze,
          standalone: opts.standalone,
          noSandbox: opts.noSandbox,
          timeMs: opts.timeMs,
          browserPath,
        },
        null,
        2
      )
    );
    process.exit(0);
  }

  if (!browserPath) {
    console.error(
      "错误：未找到本机 Edge/Chrome/Chromium 浏览器，请通过 --browser 或环境变量 CHROME_PATH / EDGE_PATH 指定路径。"
    );
    process.exit(1);
  }

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "svg-craft-preview-"));
  const profileDir = path.join(tmpDir, "profile");
  const stagedPng = path.join(tmpDir, "shot.png");
  let exitCode = 0;

  try {
    let targetUrl = pathToFileURL(svgPath).href;
    if (!opts.standalone) {
      const htmlPath = path.join(tmpDir, "preview.html");
      const html = buildPreviewHtml(svgPath, svgContent, width, height, opts);
      fs.writeFileSync(htmlPath, html, "utf8");
      targetUrl = pathToFileURL(htmlPath).href;
    }

    const args = [
      "--headless=new",
      "--disable-gpu",
      "--hide-scrollbars",
      "--run-all-compositor-stages-before-draw",
      `--virtual-time-budget=${opts.timeMs}`,
      `--user-data-dir=${profileDir}`,
      `--force-device-scale-factor=${opts.scale}`,
      `--window-size=${width},${height}`,
      `--screenshot=${stagedPng}`,
      targetUrl,
    ];
    if (opts.noSandbox) {
      args.splice(2, 0, "--no-sandbox");
    }
    if (opts.bg === "transparent") {
      args.splice(2, 0, "--default-background-color=00000000");
    }

    let browserOk = true;
    try {
      execFileSync(browserPath, args, { stdio: "pipe", timeout: 30000 });
    } catch (err) {
      console.error("渲染失败：", err.stderr?.toString("utf8") || err.message);
      exitCode = 1;
      browserOk = false;
    }

    if (browserOk) {
      if (!fs.existsSync(stagedPng)) {
        console.error("错误：浏览器执行完成但未生成本次 PNG 文件。");
        exitCode = 1;
      } else {
        const dims = readPngDimensions(stagedPng);
        if (!dims) {
          console.error("错误：生成的截图不是有效的 PNG 文件（签名、IHDR 或 IEND 非法）。");
          exitCode = 1;
        } else {
          fs.mkdirSync(path.dirname(outPath), { recursive: true });
          fs.copyFileSync(stagedPng, outPath);
          const sizeKb = (fs.statSync(outPath).size / 1024).toFixed(1);
          console.log(
            `[svg-render] OK -> ${outPath} (${dims.width}x${dims.height}, ${sizeKb} KB, browser: ${path.basename(browserPath)})`
          );
        }
      }
    }
  } finally {
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    } catch {
      // Ignore transient Windows profile lock cleanup errors after output is verified
    }
  }

  if (exitCode !== 0) {
    process.exit(exitCode);
  }
}

if (isCliEntry(import.meta.url)) {
  main();
}
