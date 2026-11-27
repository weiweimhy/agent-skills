import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { lintSvg, parseArgs as parseLintArgs } from "./lint-svg.mjs";
import {
  buildDefaultOutPath,
  buildPreviewHtml,
  detectSvgSize,
  findBrowser,
  parseArgs as parseRenderArgs,
  readPngDimensions,
  sortChromiumRevisionDirs,
  validateBg,
} from "./render-preview.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SKILL_ROOT = path.resolve(__dirname, "..");
const EXAMPLE_SVG = path.join(SKILL_ROOT, "examples", "memory-layout-dark.svg");
const LINT_SCRIPT = path.join(__dirname, "lint-svg.mjs");
const RENDER_SCRIPT = path.join(__dirname, "render-preview.mjs");

test("example memory-layout-dark.svg passes lintSvg in --motion mode cleanly", () => {
  const raw = fs.readFileSync(EXAMPLE_SVG, "utf8");
  const res = lintSvg(raw, { motion: true });
  assert.equal(res.ok, true, `unexpected errors: ${res.errors.join("; ")}`);
  assert.equal(res.errors.length, 0);
  assert.equal(res.warnings.length, 0, `unexpected warnings: ${res.warnings.join("; ")}`);
  assert.equal(res.info.viewBox, "0 0 1280 720");
  assert.ok(res.info.renderedIdCount >= 10);
  assert.ok(res.info.dataStepCount >= 5);
});

test("strict XML gate rejects multi-root, trailing text, bad xmlns, comment --, bad close tag, and merged attrs", () => {
  const cases = [
    [
      "multi-root",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs/></svg><b/>',
      /仅允许一个根元素/,
    ],
    [
      "trailing-text",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs/></svg>tail',
      /根元素外存在非法非空白文本/,
    ],
    [
      "leading-text",
      'GARBAGE<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs/></svg>',
      /根元素外存在非法非空白文本/,
    ],
    [
      "xmlns-extra",
      '<svg xmlns="http://www.w3.org/2000/svg-extra" viewBox="0 0 100 100"><defs/></svg>',
      /精确的 xmlns/,
    ],
    [
      "comment-double-dash",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><!-- a -- b --><defs/></svg>',
      /注释内部禁止出现 '--'/,
    ],
    [
      "closing-tag-leading-space",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs/></ svg>',
      /前导空白/,
    ],
    [
      "attrs-without-whitespace",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs/><rect width="10"height="10"/></svg>',
      /缺少空白分隔/,
    ],
    [
      "bare-cdata-close-in-text",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs/><text x="10" y="20">a ]]> b</text></svg>',
      /禁止出现字面量 '\]\]>'/,
    ],
    [
      "unbound-xlink-prefix",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><symbol id="a"/></defs><use xlink:href="#a"/></svg>',
      /未声明的 XML 命名空间前缀 'xlink:'/,
    ],
    [
      "infinity-viewbox",
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="Infinity 0 100 100"><defs/></svg>',
      /viewBox 格式非法/,
    ],
  ];

  for (const [label, xml, pattern] of cases) {
    const res = lintSvg(xml);
    assert.equal(res.ok, false, `expected failure for ${label}`);
    assert.ok(
      res.errors.some((e) => pattern.test(e)),
      `case ${label} errors (${res.errors.join("; ")}) did not match ${pattern}`
    );
  }
});

test("single-pass XML entity decoding avoids crashes on valid &amp;#x110000; and reports out-of-range code points", () => {
  const validLiteral = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" font-family="sans-serif">
    <defs></defs>
    <rect width="400" height="200" fill="#0F172A"/>
    <text x="20" y="60">&amp;#x110000; R&amp;D</text>
  </svg>`;
  const validRes = lintSvg(validLiteral);
  assert.equal(validRes.ok, true, validRes.errors.join("; "));

  const invalidEntities = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" font-family="sans-serif">
    <defs></defs>
    <rect width="400" height="200" fill="#0F172A"/>
    <text x="20" y="60" data-label="X & Y">bad &#99999999; and &#x110000; and A & B</text>
  </svg>`;
  const badRes = lintSvg(invalidEntities);
  assert.equal(badRes.ok, false);
  assert.ok(badRes.errors.some((e) => e.includes("未转义的 '&'") && e.includes("文本内容")));
  assert.ok(badRes.errors.some((e) => e.includes("未转义的 '&'") && e.includes("属性 'data-label'")));
  assert.ok(badRes.errors.some((e) => e.includes("越界的 XML 数值字符引用") && e.includes("&#99999999;")));
  assert.ok(badRes.errors.some((e) => e.includes("越界的 XML 数值字符引用") && e.includes("&#x110000;")));
});

test("stroke-width before width and px units parse cleanly for overlap detection", () => {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" font-family="sans-serif">
    <defs></defs>
    <rect width="800px" height="600px" fill="#0F172A"/>
    <rect stroke-width="2" width="160px" height="80px" x="40px" y="40px" rx="8" fill="#162033"/>
    <rect x="120" y="70" width="160" height="80" rx="8" fill="#162033"/>
  </svg>`;
  const res = lintSvg(svg);
  assert.equal(res.ok, true);
  assert.ok(res.warnings.some((w) => w.includes("疑似部分重叠")));
});

test("CSS cascade, !important, CDATA, @media isolation, and CSS comment url(#...) handling", () => {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600">
    <defs>
      <style><![CDATA[
        /* fill: url(#deleted-in-comment); */
        @media (prefers-color-scheme: light) {
          .bg { fill: #000000; }
        }
        .bg { fill: #ffffff !important; }
        .txt { font-family: 'Noto Sans SC', sans-serif; }
      ]]></style>
    </defs>
    <rect class="bg" width="100%" height="100%" fill="#0F172A"/>
  </svg>`;
  const res = lintSvg(svg);
  assert.equal(res.ok, true, `CSS comments must not trigger broken ref: ${res.errors.join("; ")}`);
  assert.ok(res.warnings.some((w) => w.includes("刺眼纯白")), "CSS class !important should override presentation fill");
  assert.ok(!res.warnings.some((w) => w.includes("纯黑")), "@media block must not leak as global rule");
  assert.ok(!res.warnings.some((w) => w.includes("font-family")), "CDATA CSS font-family must be recognized");

  // Same-specificity classes must follow stylesheet source order, not class attribute order
  const orderSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" font-family="sans-serif">
    <defs><style>.a { fill: #ffffff; } .b { fill: #0F172A; }</style></defs>
    <rect class="b a" width="800" height="600"/>
    <rect x="40" y="40" width="100" height="60" style="fill: #162033; /* url(#commented-out) */"/>
  </svg>`;
  const orderRes = lintSvg(orderSvg);
  assert.equal(orderRes.ok, true, `inline style comment must not fail: ${orderRes.errors.join("; ")}`);
  assert.equal(orderRes.warnings.length, 0, `stylesheet order .b must win over .a: ${orderRes.warnings.join("; ")}`);
});

test("entity-encoded local href matches decoded IDs and catches real broken refs / duplicate IDs", () => {
  const encodedValid = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" font-family="sans-serif">
    <defs><symbol id="A" viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20"/></symbol></defs>
    <rect width="400" height="200" fill="#0F172A"/>
    <use href="#&#65;" x="10" y="10" width="20" height="20"/>
  </svg>`;
  assert.equal(lintSvg(encodedValid).ok, true);

  const broken = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" font-family="sans-serif">
    <defs>
      <marker id="dup" viewBox="0 0 10 10" markerWidth="6" markerHeight="6"><path d="M0 0L10 5L0 10z"/></marker>
      <marker id="dup" viewBox="0 0 10 10" markerWidth="6" markerHeight="6"><path d="M0 0L10 5L0 10z"/></marker>
    </defs>
    <rect width="400" height="200" fill="#0F172A" filter="url(#missing-filter)"/>
    <use href="#missing-icon" x="10" y="10"/>
  </svg>`;
  const res = lintSvg(broken);
  assert.equal(res.ok, false);
  assert.ok(res.errors.some((e) => e.includes('重复 id="dup"')));
  assert.ok(res.errors.some((e) => e.includes("#missing-filter")));
  assert.ok(res.errors.some((e) => e.includes("#missing-icon")));
});

test("text layout checks handle mixed text+tspan, em/pct units, omitted x/y, CSS translateX, and emoji precision", () => {
  const mixedOverflow = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" font-family="sans-serif">
    <defs></defs>
    <rect width="800" height="600" fill="#0F172A"/>
    <rect x="60" y="60" width="120" height="60" rx="8" fill="#162033"/>
    <text x="72" y="96" font-size="14" fill="#F1F5F9">前缀很长一段一定会撑爆卡片的文字 <tspan fill="#22D3EE">OK</tspan> 🚀</text>
  </svg>`;
  const mixRes = lintSvg(mixedOverflow);
  assert.ok(mixRes.warnings.some((w) => w.includes("可能撑爆所在卡片")));
  assert.ok(mixRes.warnings.some((w) => w.includes("彩色 Emoji") && w.includes("🚀")));

  const cssShiftOverflow = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" font-family="sans-serif">
    <defs><style>.shifted { transform: translateX(200px); }</style></defs>
    <rect width="200" height="100" fill="#0F172A"/>
    <text class="shifted" y="40" font-size="1.2em" fill="#F1F5F9">Out of bounds</text>
  </svg>`;
  const shiftRes = lintSvg(cssShiftOverflow);
  assert.ok(shiftRes.warnings.some((w) => w.includes("贴近或超出画布")));

  const safeSymbols = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" font-family="sans-serif">
    <defs>
      <clipPath id="clip-top"><rect x="40" y="40" width="140" height="80" rx="8"/></clipPath>
    </defs>
    <rect width="800" height="600" fill="#0F172A"/>
    <rect x="80" y="60" width="200" height="120" rx="8" fill="#162033" clip-path="url(#clip-top)"/>
    <g transform="translate(400px, 200px)">
      <text font-size="14" fill="#F1F5F9">Copyright © ↗ ↔ → ✓<tspan x="0" dy="1.4em">Line 2</tspan></text>
    </g>
  </svg>`;
  const safeRes = lintSvg(safeSymbols);
  assert.equal(safeRes.ok, true, safeRes.errors.join("; "));
  assert.equal(safeRes.warnings.length, 0, safeRes.warnings.join("; "));

  // CSS transform overrides (not adds to) SVG presentation attribute transform
  const cssOverrideTf = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" font-family="sans-serif">
    <defs><style>.override { transform: translate(120px, 0); } .reset { transform: none; }</style></defs>
    <rect width="200" height="100" fill="#0F172A"/>
    <text class="override" transform="translate(100, 0)" x="10" y="40" font-size="14" fill="#F1F5F9">Hello</text>
    <text class="reset" transform="translate(500, 0)" x="10" y="70" font-size="14" fill="#F1F5F9">Inside</text>
  </svg>`;
  const overrideRes = lintSvg(cssOverrideTf);
  assert.equal(overrideRes.warnings.length, 0, `CSS transform must override attr: ${overrideRes.warnings.join("; ")}`);

  // Nested <tspan x="..."> and percentage dx overflow checks
  const nestedTspanSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" font-family="sans-serif">
    <defs></defs>
    <rect width="200" height="100" fill="#0F172A"/>
    <text x="10" y="30" font-size="12" fill="#F1F5F9"><tspan>a<tspan x="300">far</tspan></tspan></text>
    <text x="10" y="60" font-size="12" fill="#F1F5F9"><tspan dx="150%">shifted</tspan></text>
  </svg>`;
  const nestedRes = lintSvg(nestedTspanSvg);
  assert.ok(nestedRes.warnings.filter((w) => w.includes("贴近或超出画布")).length >= 2);
});

test("validates W3C <animateMotion> including relative <mpath>, omitted cx/cy, lowercase m, and compact negative coords", () => {
  const validSmil = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" font-family="sans-serif">
    <defs><path id="rel" d="M0 0 h40"/></defs>
    <rect width="400" height="200" fill="#0F172A"/>
    <circle cx="50" cy="100" r="5" fill="#22D3EE">
      <animateMotion dur="2s" repeatCount="indefinite" path="M 0 0 L 100 0"/>
    </circle>
    <circle cx="50" cy="100" r="5" fill="#34D399">
      <animateMotion dur="2s" repeatCount="indefinite"><mpath href="#rel"/></animateMotion>
    </circle>
    <g transform="translate(80, 120)">
      <circle cx="0" cy="0" r="5" fill="#A78BFA">
        <animateMotion dur="2s" repeatCount="indefinite" path="M 0 0 L 60 0"/>
      </circle>
    </g>
  </svg>`;
  const validRes = lintSvg(validSmil);
  assert.equal(validRes.ok, true, `valid SMIL should pass: ${validRes.errors.join("; ")}`);
  assert.equal(validRes.info.animateMotionCount, 3);

  const badSmil = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" font-family="sans-serif">
    <defs><path id="abs" d="M 50 50 L 150 50"/></defs>
    <rect width="400" height="200" fill="#0F172A"/>
    <circle cx="50" cy="50" r="4"><animateMotion dur="1s" path="m 50 50 L 150 50"/></circle>
    <circle cx="50" cy="50" r="4"><animateMotion dur="1s" path="M50-50 L150-50"/></circle>
    <circle r="4"><animateMotion dur="1s"><mpath href="#abs"/></animateMotion></circle>
    <circle cx="80" cy="80" r="4"><animateMotion dur="1s"><mpath href="#abs"/></animateMotion></circle>
    <circle id="ext-ball" cx="80" cy="50" r="4"/>
    <animateMotion href="#ext-ball" dur="1s" path="M 80 50 L 120 50"/>
  </svg>`;
  const badRes = lintSvg(badSmil);
  assert.equal(badRes.ok, false);
  assert.equal(badRes.errors.length, 5, `expected 5 animateMotion errors, got: ${badRes.errors.join("; ")}`);
});

test("--motion checks renderedIdCount (excluding <defs>) and positive .anim-edge pathLength", () => {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" font-family="sans-serif">
    <defs>
      <marker id="m1" viewBox="0 0 10 10" markerWidth="6" markerHeight="6"><path d="M0 0L10 5L0 10z"/></marker>
      <marker id="m2" viewBox="0 0 10 10" markerWidth="6" markerHeight="6"><path d="M0 0L10 5L0 10z"/></marker>
      <marker id="m3" viewBox="0 0 10 10" markerWidth="6" markerHeight="6"><path d="M0 0L10 5L0 10z"/></marker>
      <marker id="m4" viewBox="0 0 10 10" markerWidth="6" markerHeight="6"><path d="M0 0L10 5L0 10z"/></marker>
    </defs>
    <g id="layer-bg"><rect width="400" height="200" fill="#0F172A"/></g>
    <g id="layer-nodes" data-step="1"><path class="anim-edge" pathLength="0" d="M 10 10 L 100 10" stroke="#22D3EE"/></g>
  </svg>`;
  const res = lintSvg(svg, { motion: true });
  assert.equal(res.info.renderedIdCount, 2);
  assert.ok(res.warnings.some((w) => w.includes("可视层语义 id 偏少")));
  assert.ok(res.warnings.some((w) => w.includes("正数 pathLength")));
});

test("lint-svg CLI argument handling and --inline behavior", () => {
  assert.throws(() => parseLintArgs(["--unknown-flag", "a.svg"]), /未知参数/);

  const noXmlns = `<svg viewBox="0 0 200 100" font-family="sans-serif"><defs></defs></svg>`;
  assert.equal(lintSvg(noXmlns, { inline: false }).ok, false);
  const inlineRes = lintSvg(noXmlns, { inline: true });
  assert.equal(inlineRes.ok, true);
  assert.ok(inlineRes.warnings.some((w) => w.includes("xmlns")));

  const out = execFileSync(process.execPath, [LINT_SCRIPT, EXAMPLE_SVG, "--motion", "--json"], {
    encoding: "utf8",
  });
  const parsed = JSON.parse(out);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.errors.length, 0);
});

test("render-preview helpers: CLI validation, buildPreviewHtml scoping, detectSvgSize, and findBrowser safety", () => {
  const parsed = parseRenderArgs(["demo.svg", "--freeze", "--scale", "1.5", "--bg", "#0F172A"]);
  assert.equal(parsed.freeze, true);
  assert.equal(parsed.noSandbox, false);
  assert.equal(parsed.timeMs, 200);

  assert.throws(() => parseRenderArgs(["demo.svg", "--out"]), /缺少取值/);
  assert.throws(() => parseRenderArgs(["demo.svg", "--scale", "abc"]), /--scale/);
  assert.throws(() => parseRenderArgs(["demo.svg", "--unknown"]), /未知参数/);
  assert.throws(() => parseRenderArgs(["demo.svg", "--standalone", "--freeze"]), /不支持 --freeze/);
  assert.throws(() => parseRenderArgs(["demo.svg", "--standalone", "--bg", "#0F172A"]), /不支持自定义 --bg/);
  assert.throws(() => validateBg("#fff; body{display:none}"), /非法 CSS 字符/);
  assert.throws(() => validateBg("red /* comment"), /非法 CSS 字符/);
  assert.throws(() => validateBg("red\nblue"), /非法 CSS 字符/);

  assert.deepEqual(
    detectSvgSize('<!-- <svg viewBox="0 0 1 1"></svg> --><svg viewBox="0 0 960 540"></svg>'),
    { width: 960, height: 540 }
  );
  assert.deepEqual(detectSvgSize('<svg width="100%" height="100%"></svg>'), { width: 1280, height: 720 });
  assert.deepEqual(detectSvgSize('<svg viewBox="Infinity 0 12 24"></svg>'), { width: 1280, height: 720 });
  assert.deepEqual(detectSvgSize('<svg stroke-width="2" width="640px" height="360px"></svg>'), {
    width: 640,
    height: 360,
  });

  const html = buildPreviewHtml(EXAMPLE_SVG, "<svg></svg>", 1280, 720, { bg: "transparent", freeze: true });
  assert.ok(html.includes("body > svg {"), "wrapper CSS must target only root body > svg");
  assert.ok(!html.includes("\n    svg {"), "wrapper CSS must not use global svg selector");
  assert.ok(html.includes("animation-play-state: paused"), "freeze mode must pause CSS animations instead of dropping keyframes");
  assert.ok(!html.includes("animation: none"), "freeze mode must not use animation: none");
  assert.ok(!html.includes("animation-delay: 0s"), "freeze mode must preserve original animation-delay at t=0");
  assert.ok(html.includes("document.getAnimations"), "freeze mode should seek Web Animations to t=0");

  assert.throws(() => findBrowser(SKILL_ROOT), /不是有效的可执行文件/);
  assert.throws(() => findBrowser(path.join(SKILL_ROOT, "SKILL.md")), /不是有效的可执行文件/);
  assert.deepEqual(
    sortChromiumRevisionDirs(["chromium-999", "chromium-1148", "chromium-1000"]),
    ["chromium-1148", "chromium-1000", "chromium-999"]
  );

  const defaultOut = buildDefaultOutPath(EXAMPLE_SVG);
  assert.ok(
    path.resolve(defaultOut).startsWith(path.resolve(os.tmpdir())),
    `default output must be inside os.tmpdir(), got ${defaultOut}`
  );
});

test("render-preview rejects same input/output path (including hardlinks), truncated PNGs, and invalid XML", () => {
  const samePathRun = spawnSync(process.execPath, [RENDER_SCRIPT, EXAMPLE_SVG, "--out", EXAMPLE_SVG, "--dry-run"], {
    encoding: "utf8",
  });
  assert.notEqual(samePathRun.status, 0);
  assert.match(samePathRun.stderr, /不能与输入 SVG 文件相同/);

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "svg-craft-test-"));
  const badPath = path.join(tmpDir, "broken.svg");
  const validPath = path.join(tmpDir, "src.svg");
  const hardlinkPath = path.join(tmpDir, "alias.svg");
  const truncPngPath = path.join(tmpDir, "trunc.png");
  try {
    fs.writeFileSync(
      badPath,
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100"><text x="10" y="20">A & B</text></svg>',
      "utf8"
    );
    const badRun = spawnSync(process.execPath, [RENDER_SCRIPT, badPath, "--dry-run"], { encoding: "utf8" });
    assert.notEqual(badRun.status, 0);
    assert.match(badRun.stderr, /XML 校验未通过/);

    // Hardlink alias to input SVG must be rejected before overwriting
    fs.copyFileSync(EXAMPLE_SVG, validPath);
    fs.linkSync(validPath, hardlinkPath);
    const hlRun = spawnSync(process.execPath, [RENDER_SCRIPT, validPath, "--out", hardlinkPath, "--dry-run"], {
      encoding: "utf8",
    });
    assert.notEqual(hlRun.status, 0);
    assert.match(hlRun.stderr, /不能与输入 SVG 文件相同/);

    // Truncated 24-byte buffer without valid IHDR/IEND must be rejected
    const fakeBuf = Buffer.alloc(24);
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(fakeBuf, 0);
    fakeBuf.writeUInt32BE(1, 16);
    fakeBuf.writeUInt32BE(1, 20);
    fs.writeFileSync(truncPngPath, fakeBuf);
    assert.equal(readPngDimensions(truncPngPath), null);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
});

test("CLI entry guards execute properly when invoked through a Junction or Symlink", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "svg-craft-link-"));
  const linkDir = path.join(tmpDir, "svg-craft-link");
  try {
    fs.symlinkSync(SKILL_ROOT, linkDir, process.platform === "win32" ? "junction" : "dir");
    const lintHelp = execFileSync(process.execPath, [path.join(linkDir, "scripts", "lint-svg.mjs"), "--help"], {
      encoding: "utf8",
    });
    assert.match(lintHelp, /Usage: node lint-svg\.mjs/);

    const renderHelp = execFileSync(process.execPath, [path.join(linkDir, "scripts", "render-preview.mjs"), "--help"], {
      encoding: "utf8",
    });
    assert.match(renderHelp, /Usage: node render-preview\.mjs/);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
});

test("render-preview end-to-end headless screenshot produces valid PNG (when browser available)", (t) => {
  const browser = findBrowser(null);
  if (!browser) {
    t.skip("No local Edge/Chrome/Chromium available for live screenshot test");
    return;
  }
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "svg-craft-e2e-"));
  const outPng = path.join(tmpDir, "example-1x.png");
  const renderArgs = [RENDER_SCRIPT, EXAMPLE_SVG, "--freeze", "--scale", "1", "--out", outPng];
  if (process.platform === "linux" && process.env.CI) {
    renderArgs.push("--no-sandbox");
  }
  try {
    const out = execFileSync(process.execPath, renderArgs, { encoding: "utf8" });
    assert.match(out, /\[svg-render\] OK/);
    const dims = readPngDimensions(outPng);
    assert.deepEqual(dims, { width: 1280, height: 720 });
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
});
