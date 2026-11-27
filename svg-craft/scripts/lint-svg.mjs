#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const NON_RENDERED_CONTAINERS = new Set([
  "defs",
  "symbol",
  "clippath",
  "mask",
  "pattern",
  "marker",
  "filter",
  "metadata",
  "title",
  "desc",
  "style",
]);

const POSITIONED_SHAPE_TAGS = new Set(["circle", "ellipse", "rect", "image", "text", "use"]);
const PURE_BLACK_VALUES = new Set(["#000", "#000000", "black", "rgb(0,0,0)"]);
const PURE_WHITE_VALUES = new Set(["#fff", "#ffffff", "white", "rgb(255,255,255)"]);
const EMOJI_RE = /\p{Emoji_Presentation}|\p{Extended_Pictographic}\uFE0F/gu;
const FULLWIDTH_CJK_RE = /[\u4E00-\u9FFF\u3000-\u303F\uFF00-\uFFEF“”‘’—…《》【】]/;

export function isCliEntry(importMetaUrl, argv1 = process.argv[1]) {
  if (!argv1) return false;
  const resolveReal = (p) => {
    try {
      return fs.realpathSync(p);
    } catch {
      return path.resolve(p);
    }
  };
  const entryPath = resolveReal(argv1);
  const selfPath = resolveReal(fileURLToPath(importMetaUrl));
  if (process.platform === "win32") {
    return entryPath.toLowerCase() === selfPath.toLowerCase();
  }
  return entryPath === selfPath;
}

export function parseArgs(argv) {
  const opts = { file: null, motion: false, inline: false, json: false, help: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--motion") {
      opts.motion = true;
    } else if (arg === "--inline") {
      opts.inline = true;
    } else if (arg === "--json") {
      opts.json = true;
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
  return opts;
}

function countNewlines(str, from, to) {
  let n = 0;
  for (let i = from; i < to; i += 1) {
    if (str.charCodeAt(i) === 10) n += 1;
  }
  return n;
}

function isValidXmlCodePoint(cp) {
  return (
    cp === 0x9 ||
    cp === 0xa ||
    cp === 0xd ||
    (cp >= 0x20 && cp <= 0xd7ff) ||
    (cp >= 0xe000 && cp <= 0xfffd) ||
    (cp >= 0x10000 && cp <= 0x10ffff)
  );
}

export function decodeXmlSinglePass(text, line, context, errors) {
  if (!text.includes("&")) return text;
  const entityRe = /&(amp|lt|gt|quot|apos|#(\d+)|#x([0-9a-fA-F]+));|&/g;
  return text.replace(entityRe, (match, named, dec, hex, offset) => {
    if (named === "amp") return "&";
    if (named === "lt") return "<";
    if (named === "gt") return ">";
    if (named === "quot") return '"';
    if (named === "apos") return "'";
    if (dec !== undefined || hex !== undefined) {
      const cp = dec !== undefined ? Number.parseInt(dec, 10) : Number.parseInt(hex, 16);
      if (!Number.isSafeInteger(cp) || !isValidXmlCodePoint(cp)) {
        errors.push(`第 ${line} 行：${context}包含非法或越界的 XML 数值字符引用 '${match}'。`);
        return "\uFFFD";
      }
      return String.fromCodePoint(cp);
    }
    const snippet = text.slice(Math.max(0, offset - 8), Math.min(text.length, offset + 14)).trim();
    errors.push(`第 ${line} 行：${context}包含未转义的 '&'（"${snippet}"），独立 SVG XML 解析会失败，请改为 '&amp;'。`);
    return match;
  });
}

export function parseXml(raw) {
  const src = raw.charCodeAt(0) === 0xfeff ? raw.slice(1) : raw;
  const errors = [];
  const rootNodes = [];
  const stack = [];
  let pos = 0;
  let line = 1;
  const len = src.length;

  const pushChild = (node) => {
    if (stack.length > 0) {
      const parent = stack[stack.length - 1];
      node.parent = parent;
      parent.children.push(node);
    } else {
      node.parent = null;
      rootNodes.push(node);
    }
  };

  while (pos < len) {
    const lt = src.indexOf("<", pos);
    if (lt === -1) {
      const tail = src.slice(pos);
      if (tail.length > 0) {
        if (stack.length === 0) {
          if (tail.trim()) {
            errors.push(`第 ${line} 行：根元素外存在非法非空白文本（"${tail.trim().slice(0, 24)}"）。`);
          }
        } else {
          if (tail.includes("]]>")) {
            errors.push(`第 ${line} 行：XML 文本内容中禁止出现字面量 ']]>'。`);
          }
          const decoded = decodeXmlSinglePass(tail, line, "文本内容", errors);
          pushChild({ type: "text", value: decoded, line });
        }
      }
      break;
    }

    if (lt > pos) {
      const text = src.slice(pos, lt);
      if (text.length > 0) {
        if (stack.length === 0) {
          if (text.trim()) {
            errors.push(`第 ${line} 行：根元素外存在非法非空白文本（"${text.trim().slice(0, 24)}"）。`);
          }
        } else {
          if (text.includes("]]>")) {
            errors.push(`第 ${line} 行：XML 文本内容中禁止出现字面量 ']]>'。`);
          }
          const decoded = decodeXmlSinglePass(text, line, "文本内容", errors);
          pushChild({ type: "text", value: decoded, line });
        }
      }
      line += countNewlines(src, pos, lt);
      pos = lt;
    }

    // Comment <!-- ... -->
    if (src.startsWith("<!--", pos)) {
      const end = src.indexOf("-->", pos + 4);
      if (end === -1) {
        errors.push(`第 ${line} 行：注释 <!-- 未闭合。`);
        break;
      }
      const commentBody = src.slice(pos + 4, end);
      if (commentBody.includes("--") || commentBody.endsWith("-")) {
        errors.push(`第 ${line} 行：XML 注释内部禁止出现 '--' 或以 '-' 紧接 '-->'。`);
      }
      line += countNewlines(src, pos, end + 3);
      pos = end + 3;
      continue;
    }

    // CDATA <![CDATA[ ... ]]>
    if (src.startsWith("<![CDATA[", pos)) {
      const end = src.indexOf("]]>", pos + 9);
      if (end === -1) {
        errors.push(`第 ${line} 行：CDATA 区块未闭合。`);
        break;
      }
      if (stack.length === 0) {
        errors.push(`第 ${line} 行：根元素外禁止出现 CDATA 区块。`);
      } else {
        const value = src.slice(pos + 9, end);
        pushChild({ type: "cdata", value, line });
      }
      line += countNewlines(src, pos, end + 3);
      pos = end + 3;
      continue;
    }

    // Processing instruction <? ... ?>
    if (src.startsWith("<?", pos)) {
      const end = src.indexOf("?>", pos + 2);
      if (end === -1) {
        errors.push(`第 ${line} 行：XML 声明/处理指令 <? 未闭合。`);
        break;
      }
      line += countNewlines(src, pos, end + 2);
      pos = end + 2;
      continue;
    }

    // DOCTYPE <!DOCTYPE ...>
    if (src.slice(pos, pos + 9).toUpperCase() === "<!DOCTYPE") {
      let i = pos + 9;
      let bracketDepth = 0;
      let quote = null;
      while (i < len) {
        const ch = src[i];
        if (quote) {
          if (ch === quote) quote = null;
        } else if (ch === '"' || ch === "'") {
          quote = ch;
        } else if (ch === "[") {
          bracketDepth += 1;
        } else if (ch === "]") {
          bracketDepth = Math.max(0, bracketDepth - 1);
        } else if (ch === ">" && bracketDepth === 0) {
          break;
        }
        i += 1;
      }
      if (i >= len) {
        errors.push(`第 ${line} 行：<!DOCTYPE 未闭合。`);
        break;
      }
      line += countNewlines(src, pos, i + 1);
      pos = i + 1;
      continue;
    }

    // Closing tag </tag>
    if (src.startsWith("</", pos)) {
      const end = src.indexOf(">", pos + 2);
      if (end === -1) {
        errors.push(`第 ${line} 行：闭合标签未找到 '>'。`);
        break;
      }
      const rawClose = src.slice(pos + 2, end);
      if (/^\s/.test(rawClose)) {
        errors.push(`第 ${line} 行：闭合标签 '</' 后禁止出现前导空白（</${rawClose}>）。`);
      }
      const tagName = rawClose.trim();
      if (!/^[A-Za-z_][\w:.-]*$/.test(tagName)) {
        errors.push(`第 ${line} 行：非法闭合标签 </${tagName}>。`);
      } else if (stack.length === 0) {
        errors.push(`第 ${line} 行：发现多余的闭合标签 </${tagName}>。`);
      } else {
        const top = stack.pop();
        if (top.tag !== tagName) {
          errors.push(`第 ${line} 行：标签嵌套不匹配，期望 </${top.tag}>（开启于第 ${top.line} 行），实际遇到 </${tagName}>。`);
        }
      }
      line += countNewlines(src, pos, end + 1);
      pos = end + 1;
      continue;
    }

    // Start tag <tag ...>
    const tagStartLine = line;
    let i = pos + 1;
    const nameStart = i;
    while (i < len && /[\w:.-]/.test(src[i])) i += 1;
    const tagName = src.slice(nameStart, i);
    if (!tagName || !/^[A-Za-z_][\w:.-]*$/.test(tagName)) {
      errors.push(`第 ${tagStartLine} 行：发现非法的 '<' 起始字符（文本中的 '<' 需转义为 '&lt;'）。`);
      pos += 1;
      continue;
    }

    const attrs = {};
    let selfClose = false;
    let tagClosed = false;
    let needSpaceBeforeAttr = false;

    while (i < len) {
      let skippedWs = 0;
      while (i < len && /\s/.test(src[i])) {
        if (src.charCodeAt(i) === 10) line += 1;
        skippedWs += 1;
        i += 1;
      }
      if (i >= len) break;

      if (src[i] === ">") {
        i += 1;
        tagClosed = true;
        break;
      }
      if (src[i] === "/" && src[i + 1] === ">") {
        selfClose = true;
        i += 2;
        tagClosed = true;
        break;
      }

      if (needSpaceBeforeAttr && skippedWs === 0) {
        errors.push(`第 ${line} 行：<${tagName}> 相邻属性之间缺少空白分隔。`);
      }

      const attrStart = i;
      while (i < len && /[\w:.-]/.test(src[i])) i += 1;
      const attrName = src.slice(attrStart, i);
      if (!attrName || !/^[A-Za-z_][\w:.-]*$/.test(attrName)) {
        errors.push(`第 ${line} 行：<${tagName}> 存在非法属性名 '${attrName || src[i]}'。`);
        const nextGt = src.indexOf(">", i);
        if (nextGt === -1) {
          i = len;
        } else {
          line += countNewlines(src, i, nextGt + 1);
          i = nextGt + 1;
          tagClosed = true;
        }
        break;
      }

      while (i < len && /\s/.test(src[i])) {
        if (src.charCodeAt(i) === 10) line += 1;
        i += 1;
      }
      if (src[i] !== "=") {
        errors.push(`第 ${line} 行：<${tagName}> 属性 '${attrName}' 缺少 '=' 赋值（XML 不允许无值属性）。`);
        needSpaceBeforeAttr = true;
        continue;
      }
      i += 1;
      while (i < len && /\s/.test(src[i])) {
        if (src.charCodeAt(i) === 10) line += 1;
        i += 1;
      }

      const quote = src[i];
      if (quote !== '"' && quote !== "'") {
        errors.push(`第 ${line} 行：<${tagName}> 属性 '${attrName}' 的值必须使用双引号或单引号包裹。`);
        while (i < len && !/[\s/>]/.test(src[i])) i += 1;
        needSpaceBeforeAttr = true;
        continue;
      }

      const valLine = line;
      i += 1;
      const valStart = i;
      while (i < len && src[i] !== quote) {
        if (src.charCodeAt(i) === 10) line += 1;
        i += 1;
      }
      if (i >= len) {
        errors.push(`第 ${valLine} 行：<${tagName}> 属性 '${attrName}' 的引号未闭合。`);
        break;
      }
      const rawAttrVal = src.slice(valStart, i);
      i += 1;
      needSpaceBeforeAttr = true;

      if (rawAttrVal.includes("<")) {
        errors.push(`第 ${valLine} 行：<${tagName}> 属性 '${attrName}' 包含未转义的 '<'。`);
      }
      const decodedVal = decodeXmlSinglePass(rawAttrVal, valLine, `<${tagName}> 属性 '${attrName}'`, errors);

      if (Object.prototype.hasOwnProperty.call(attrs, attrName)) {
        errors.push(`第 ${valLine} 行：<${tagName}> 存在重复属性 '${attrName}'。`);
      }
      attrs[attrName] = decodedVal;
    }

    if (!tagClosed) {
      errors.push(`第 ${tagStartLine} 行：<${tagName}> 开始标签未闭合。`);
      break;
    }

    const elem = {
      type: "element",
      tag: tagName,
      attrs,
      children: [],
      line: tagStartLine,
      parent: null,
    };
    pushChild(elem);
    if (!selfClose) {
      stack.push(elem);
    }
    pos = i;
  }

  if (stack.length > 0) {
    const unclosed = stack
      .slice(-5)
      .map((el) => `<${el.tag}>(L${el.line})`)
      .join(", ");
    errors.push(`存在未闭合标签：${unclosed}`);
  }

  const rootElements = rootNodes.filter((n) => n.type === "element");
  if (rootElements.length > 1) {
    const extra = rootElements
      .slice(1)
      .map((el) => `<${el.tag}>(L${el.line})`)
      .join(", ");
    errors.push(`XML 仅允许一个根元素，检测到多余的顶层元素：${extra}。`);
  }
  return { rootElements, errors };
}

function stripCssComments(cssText) {
  return cssText.replace(/\/\*[\s\S]*?\*\//g, "");
}

function stripNestedAtRules(cssText) {
  let out = "";
  let i = 0;
  const len = cssText.length;
  while (i < len) {
    if (cssText[i] === "@") {
      const semi = cssText.indexOf(";", i);
      const brace = cssText.indexOf("{", i);
      if (semi !== -1 && (brace === -1 || semi < brace)) {
        i = semi + 1;
        continue;
      }
      if (brace !== -1) {
        let depth = 0;
        let j = brace;
        while (j < len) {
          if (cssText[j] === "{") depth += 1;
          else if (cssText[j] === "}") {
            depth -= 1;
            if (depth === 0) {
              j += 1;
              break;
            }
          }
          j += 1;
        }
        i = j;
        continue;
      }
    }
    out += cssText[i];
    i += 1;
  }
  return out;
}

function parseStyleDeclarations(styleStr, orderCounter = { n: 0 }) {
  const map = {};
  if (!styleStr) return map;
  for (const part of stripCssComments(styleStr).split(";")) {
    const colon = part.indexOf(":");
    if (colon === -1) continue;
    const prop = part.slice(0, colon).trim().toLowerCase();
    let val = part.slice(colon + 1).trim();
    let important = false;
    if (/\s*!important\s*$/i.test(val)) {
      important = true;
      val = val.replace(/\s*!important\s*$/i, "").trim();
    }
    if (prop && val) {
      orderCounter.n += 1;
      const decl = { value: val, important, order: orderCounter.n };
      if (!map[prop] || important || !map[prop].important) {
        map[prop] = decl;
      }
    }
  }
  return map;
}

function parseCssRules(cssText) {
  const rules = { byClass: {}, byId: {}, byTag: {} };
  if (!cssText) return rules;
  const cleaned = stripNestedAtRules(stripCssComments(cssText));
  const blockRe = /([^{}]+)\{([^{}]+)\}/g;
  const orderCounter = { n: 0 };
  let m;
  while ((m = blockRe.exec(cleaned)) !== null) {
    const selectors = m[1].split(",").map((s) => s.trim()).filter(Boolean);
    const decls = parseStyleDeclarations(m[2], orderCounter);
    for (const sel of selectors) {
      let target = null;
      if (/^\.([A-Za-z_-][\w-]*)$/.test(sel)) {
        const cls = sel.slice(1);
        target = rules.byClass[cls] || (rules.byClass[cls] = {});
      } else if (/^#([A-Za-z_-][\w-]*)$/.test(sel)) {
        const id = sel.slice(1);
        target = rules.byId[id] || (rules.byId[id] = {});
      } else if (/^[A-Za-z_][\w-]*$/.test(sel)) {
        const tag = sel.toLowerCase();
        target = rules.byTag[tag] || (rules.byTag[tag] = {});
      }
      if (target) {
        for (const [k, d] of Object.entries(decls)) {
          if (!target[k] || d.important || !target[k].important) {
            target[k] = d;
          }
        }
      }
    }
  }
  return rules;
}

function resolveProp(elem, propName, cssRules) {
  const lower = propName.toLowerCase();
  const inlineStyle = parseStyleDeclarations(elem.attrs.style);
  const idDecl = elem.attrs.id ? cssRules.byId[elem.attrs.id]?.[lower] : null;
  let classDecl = null;
  if (elem.attrs.class) {
    for (const cls of elem.attrs.class.trim().split(/\s+/)) {
      const candidate = cssRules.byClass[cls]?.[lower];
      if (!candidate) continue;
      if (!classDecl) {
        classDecl = candidate;
      } else if (candidate.important !== classDecl.important) {
        if (candidate.important) classDecl = candidate;
      } else if (candidate.order >= classDecl.order) {
        classDecl = candidate;
      }
    }
  }
  const tagDecl = cssRules.byTag[elem.tag.toLowerCase()]?.[lower] || null;

  // CSS Cascade: !important (inline > #id > .class > tag) > normal (inline > #id > .class > tag) > presentation attr
  const ordered = [inlineStyle[lower], idDecl, classDecl, tagDecl].filter(Boolean);
  const imp = ordered.find((d) => d.important);
  if (imp) return imp.value;
  if (ordered.length > 0) return ordered[0].value;

  for (const [k, v] of Object.entries(elem.attrs)) {
    if (k.toLowerCase() === lower) return v;
  }
  return null;
}

function normalizeColor(val) {
  if (!val) return "";
  return val.trim().toLowerCase().replace(/\s+/g, "");
}

function parsePxNumber(rawVal) {
  if (rawVal === undefined || rawVal === null) return NaN;
  const trimmed = String(rawVal).trim();
  const m = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))(?:px)?$/i);
  return m ? Number(m[1]) : NaN;
}

function parseFontSize(rawVal, inherited) {
  if (!rawVal) return inherited;
  const trimmed = String(rawVal).trim();
  const px = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))(?:px)?$/i);
  if (px) {
    const v = Number(px[1]);
    return v > 0 ? v : inherited;
  }
  const em = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))r?em$/i);
  if (em) {
    const v = Number(em[1]) * inherited;
    return v > 0 ? v : inherited;
  }
  const pct = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))%$/);
  if (pct) {
    const v = (Number(pct[1]) / 100) * inherited;
    return v > 0 ? v : inherited;
  }
  return inherited;
}

function parseDeltaLength(rawVal, fontSize) {
  if (rawVal === undefined || rawVal === null) return 0;
  const trimmed = String(rawVal).trim();
  const px = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))(?:px)?$/i);
  if (px) return Number(px[1]);
  const em = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))r?em$/i);
  if (em) return Number(em[1]) * fontSize;
  return 0;
}

function parseTransform(transformStr) {
  if (!transformStr || !transformStr.trim() || transformStr.trim().toLowerCase() === "none") {
    return { tx: 0, ty: 0, complex: false };
  }
  let tx = 0;
  let ty = 0;
  let complex = false;
  const fnRe = /([A-Za-z0-9]+)\s*\(([^)]*)\)/g;
  let m;
  let matched = false;
  while ((m = fnRe.exec(transformStr)) !== null) {
    matched = true;
    const fn = m[1].toLowerCase();
    const parts = m[2].trim().split(/[\s,]+/).filter(Boolean);
    if (fn === "translate") {
      const nx = parsePxNumber(parts[0]);
      const ny = parts.length >= 2 ? parsePxNumber(parts[1]) : 0;
      if (Number.isFinite(nx) && Number.isFinite(ny)) {
        tx += nx;
        ty += ny;
      } else {
        complex = true;
      }
    } else if (fn === "translatex") {
      const nx = parsePxNumber(parts[0]);
      if (Number.isFinite(nx)) tx += nx;
      else complex = true;
    } else if (fn === "translatey") {
      const ny = parsePxNumber(parts[0]);
      if (Number.isFinite(ny)) ty += ny;
      else complex = true;
    } else {
      complex = true;
    }
  }
  if (!matched) complex = true;
  return { tx, ty, complex };
}

function parsePathStart(dStr) {
  if (!dStr) return null;
  const m = dStr
    .trim()
    .match(/^([Mm])\s*([+-]?(?:\d+\.?\d*|\.\d+))(?:\s*,\s*|\s+|(?=[+-]))([+-]?(?:\d+\.?\d*|\.\d+))/);
  if (!m) return null;
  return { cmd: m[1], x: Number(m[2]), y: Number(m[3]) };
}

function estimateTextWidth(text, fontSize) {
  let width = 0;
  for (const ch of text) {
    if (FULLWIDTH_CJK_RE.test(ch)) {
      width += fontSize * 1.0;
    } else if (/[A-Z]/.test(ch)) {
      width += fontSize * 0.68;
    } else if (ch === " ") {
      width += fontSize * 0.32;
    } else {
      width += fontSize * 0.58;
    }
  }
  return width;
}

function hasPartialOverlap(a, b) {
  const ix1 = Math.max(a.x, b.x);
  const iy1 = Math.max(a.y, b.y);
  const ix2 = Math.min(a.x + a.w, b.x + b.w);
  const iy2 = Math.min(a.y + a.h, b.y + b.h);
  if (ix2 - ix1 <= 4 || iy2 - iy1 <= 4) return false;

  const interArea = (ix2 - ix1) * (iy2 - iy1);
  const areaA = a.w * a.h;
  const areaB = b.w * b.h;
  const minArea = Math.min(areaA, areaB);
  if (interArea / minArea >= 0.88) return false;
  return true;
}

function collectElementText(elem) {
  let out = "";
  for (const child of elem.children) {
    if (child.type === "text" || child.type === "cdata") {
      out += child.value;
    } else if (child.type === "element") {
      const lower = child.tag.toLowerCase();
      if (lower !== "title" && lower !== "desc") {
        out += collectElementText(child);
      }
    }
  }
  return out;
}

function extractLocalRefIds(elem) {
  const refs = [];
  for (const [k, v] of Object.entries(elem.attrs)) {
    const kl = k.toLowerCase();
    if (kl === "href" || kl === "xlink:href") {
      const trimmed = v.trim();
      if (trimmed.startsWith("#") && trimmed.length > 1) {
        refs.push({ id: trimmed.slice(1), attr: k, line: elem.line });
      }
    }
    const scanVal = kl === "style" ? stripCssComments(v) : v;
    const urlRe = /url\(\s*['"]?#([^'")\s]+)['"]?\s*\)/gi;
    let um;
    while ((um = urlRe.exec(scanVal)) !== null) {
      refs.push({ id: um[1], attr: k, line: elem.line });
    }
  }
  return refs;
}

function getElementAncestorTranslate(elem, cssRules) {
  let tx = 0;
  let ty = 0;
  let curr = elem?.parent || null;
  while (curr && curr.type === "element") {
    const tf = parseTransform(resolveProp(curr, "transform", cssRules));
    tx += tf.tx;
    ty += tf.ty;
    curr = curr.parent;
  }
  return { tx, ty };
}

function hasNamespaceDeclaration(elem, prefix) {
  const attrName = `xmlns:${prefix}`;
  let curr = elem;
  while (curr && curr.type === "element") {
    if (curr.attrs[attrName]) return true;
    curr = curr.parent;
  }
  return false;
}

function collectTextLines(textNode, ctx, cssRules, vb) {
  const baseX = textNode.attrs.x !== undefined ? parsePxNumber(textNode.attrs.x) : 0;
  const baseY = textNode.attrs.y !== undefined ? parsePxNumber(textNode.attrs.y) : 0;
  if (!Number.isFinite(baseX) || !Number.isFinite(baseY)) return [];

  const lines = [];
  let currentLine = null;
  let currY = baseY;

  const parseOffsetLength = (rawVal, fontSize, axisSize) => {
    if (rawVal === undefined || rawVal === null) return 0;
    const trimmed = String(rawVal).trim();
    const pct = trimmed.match(/^([+-]?(?:\d+\.?\d*|\.\d+))%$/);
    if (pct && axisSize > 0) return (Number(pct[1]) / 100) * axisSize;
    return parseDeltaLength(rawVal, fontSize);
  };

  const startLine = (x, y, anchor, lineNo) => {
    currentLine = { x, y, width: 0, text: "", anchor, line: lineNo };
    lines.push(currentLine);
  };

  const appendSegment = (rawText, fontSize, anchor, lineNo, explicitX, dx, explicitY, dy) => {
    const text = rawText.replace(/\s+/g, " ");
    const hasExplicitLineBreak =
      explicitX !== undefined || explicitY !== undefined || (dy !== 0 && currentLine !== null);

    if (explicitY !== undefined) currY = explicitY;
    else if (dy !== 0) currY += dy;

    if (!currentLine || hasExplicitLineBreak) {
      const lineX = (explicitX !== undefined ? explicitX : baseX) + dx;
      startLine(lineX, currY, anchor, lineNo);
    } else if (dx !== 0) {
      currentLine.width += dx;
    }

    const trimmed = currentLine.text === "" ? text.trimStart() : text;
    if (!trimmed) return;
    currentLine.text += trimmed;
    currentLine.width += estimateTextWidth(trimmed, fontSize);
  };

  const walkTextChildren = (parent, curFontSize, curAnchor, pendingPos = null) => {
    let pos = pendingPos;
    for (const child of parent.children) {
      if (child.type === "text" || child.type === "cdata") {
        if (!child.value.trim()) continue;
        appendSegment(
          child.value,
          curFontSize,
          curAnchor,
          child.line,
          pos?.ex,
          pos?.dx || 0,
          pos?.ey,
          pos?.dy || 0
        );
        pos = null;
      } else if (child.type === "element") {
        const lower = child.tag.toLowerCase();
        if (lower === "title" || lower === "desc") continue;
        if (lower === "tspan") {
          const tsFs = parseFontSize(resolveProp(child, "font-size", cssRules), curFontSize);
          const tsAnchor = (resolveProp(child, "text-anchor", cssRules) || curAnchor).toLowerCase();
          const ex = child.attrs.x !== undefined ? parsePxNumber(child.attrs.x) : undefined;
          const ey = child.attrs.y !== undefined ? parsePxNumber(child.attrs.y) : undefined;
          const dx = parseOffsetLength(child.attrs.dx, tsFs, vb ? vb.w : 0);
          const dy = parseOffsetLength(child.attrs.dy, tsFs, vb ? vb.h : 0);
          const childPos = {
            ex: Number.isFinite(ex) ? ex : pos?.ex,
            ey: Number.isFinite(ey) ? ey : pos?.ey,
            dx: dx + (pos?.dx || 0),
            dy: dy + (pos?.dy || 0),
          };
          pos = null;
          if (!collectElementText(child).trim()) {
            if (childPos.ey !== undefined) currY = childPos.ey;
            else if (childPos.dy !== 0) currY += childPos.dy;
            continue;
          }
          walkTextChildren(child, tsFs, tsAnchor, childPos);
        } else {
          walkTextChildren(child, curFontSize, curAnchor, pos);
          pos = null;
        }
      }
    }
  };

  walkTextChildren(textNode, ctx.fontSize, ctx.textAnchor);
  return lines
    .map((l) => ({ ...l, text: l.text.trim(), x: l.x + ctx.tx, y: l.y + ctx.ty }))
    .filter((l) => l.text.length > 0);
}

export function lintSvg(raw, opts = {}) {
  const errors = [];
  const warnings = [];
  const info = {
    bytes: Buffer.byteLength(raw, "utf8"),
    viewBox: null,
    idCount: 0,
    renderedIdCount: 0,
    dataStepCount: 0,
    animateMotionCount: 0,
    skippedComplexTransformCount: 0,
  };

  const { rootElements, errors: xmlErrors } = parseXml(raw);
  errors.push(...xmlErrors);

  const svgRoot = rootElements[0] || null;
  if (!svgRoot) {
    errors.push("未找到根元素 <svg>。");
  } else if (svgRoot.tag !== "svg") {
    errors.push(`根元素必须为小写 <svg>，当前为 <${svgRoot.tag}>。`);
  }

  let vb = null;
  if (svgRoot && svgRoot.tag === "svg") {
    const xmlns = (svgRoot.attrs.xmlns || "").trim();
    if (xmlns !== "http://www.w3.org/2000/svg") {
      const msg = '根 <svg> 缺少精确的 xmlns="http://www.w3.org/2000/svg"（独立打开或嵌入 Markdown 时可能无法渲染）。';
      if (opts.inline) {
        warnings.push(msg);
      } else {
        errors.push(msg);
      }
    }

    const vbStr = svgRoot.attrs.viewBox;
    if (!vbStr) {
      errors.push("根 <svg> 缺少 viewBox 属性。");
    } else {
      const nums = vbStr.trim().split(/[\s,]+/).map(Number);
      if (nums.length !== 4 || nums.some((n) => !Number.isFinite(n)) || nums[2] <= 0 || nums[3] <= 0) {
        errors.push(`viewBox 格式非法：${vbStr}`);
      } else {
        vb = { x: nums[0], y: nums[1], w: nums[2], h: nums[3] };
        info.viewBox = `${vb.x} ${vb.y} ${vb.w} ${vb.h}`;
      }
    }
  }

  // First pass: collect styles, defs, ids, elementById, refs, font-family, data-step, anim-edge
  let hasDefs = false;
  let hasFontFamily = false;
  let cssBundle = "";
  const idMap = new Map();
  const elementById = new Map();
  const localRefs = [];
  const emojiHits = [];
  const animEdgesInvalidPathLength = [];

  const firstPass = (node, insideNonRendered) => {
    if (node.type === "text") {
      if (!insideNonRendered) {
        EMOJI_RE.lastIndex = 0;
        const matches = node.value.match(EMOJI_RE);
        if (matches) emojiHits.push(...matches);
      }
      return;
    }
    if (node.type !== "element") return;

    const lower = node.tag.toLowerCase();
    if (lower === "defs") hasDefs = true;
    if (lower === "style") {
      const cssNoComments = stripCssComments(collectElementText(node));
      cssBundle += `\n${cssNoComments}`;
      if (/font-family\s*:/i.test(cssNoComments)) hasFontFamily = true;
      const urlRe = /url\(\s*['"]?#([^'")\s]+)['"]?\s*\)/gi;
      let um;
      while ((um = urlRe.exec(cssNoComments)) !== null) {
        localRefs.push({ id: um[1], attr: "<style>", line: node.line });
      }
    }

    if (node.attrs["font-family"] || (node.attrs.style && /font-family\s*:/i.test(node.attrs.style))) {
      hasFontFamily = true;
    }

    if (node.attrs.id) {
      const id = node.attrs.id;
      info.idCount += 1;
      if (!insideNonRendered && !NON_RENDERED_CONTAINERS.has(lower)) {
        info.renderedIdCount += 1;
      }
      if (idMap.has(id)) {
        errors.push(`第 ${node.line} 行：检测到重复 id="${id}"（首次定义于第 ${idMap.get(id)} 行）。`);
      } else {
        idMap.set(id, node.line);
        elementById.set(id, node);
      }
    }

    if (node.attrs["data-step"] !== undefined) {
      info.dataStepCount += 1;
    }

    if (opts.motion && node.attrs.class && /\banim-edge\b/.test(node.attrs.class)) {
      const pl = Number(node.attrs.pathLength);
      if (node.attrs.pathLength === undefined || !Number.isFinite(pl) || pl <= 0) {
        animEdgesInvalidPathLength.push(node.line);
      }
    }

    for (const attrKey of Object.keys(node.attrs)) {
      if (attrKey.includes(":") && !attrKey.startsWith("xmlns:")) {
        const prefix = attrKey.slice(0, attrKey.indexOf(":"));
        if (prefix !== "xml" && !hasNamespaceDeclaration(node, prefix)) {
          errors.push(`第 ${node.line} 行：属性 '${attrKey}' 使用了未声明的 XML 命名空间前缀 '${prefix}:'（请声明 xmlns:${prefix}）。`);
        }
      }
    }

    localRefs.push(...extractLocalRefIds(node));

    const nextNonRendered = insideNonRendered || NON_RENDERED_CONTAINERS.has(lower);
    for (const child of node.children) {
      firstPass(child, nextNonRendered);
    }
  };

  if (svgRoot) firstPass(svgRoot, false);

  const cssRules = parseCssRules(cssBundle);

  if (svgRoot && !hasDefs) {
    warnings.push("未发现 <defs> 区块，建议在顶部统一定义箭头 marker、背景网格 pattern 与渐变/阴影资产。");
  }
  if (svgRoot && !hasFontFamily) {
    warnings.push("未显式声明 font-family，不同系统下中文与等宽代码字体容易回退变形。");
  }

  for (const ref of localRefs) {
    if (!idMap.has(ref.id)) {
      errors.push(`第 ${ref.line} 行：${ref.attr} 引用了不存在的本地锚点 '#${ref.id}'。`);
    }
  }

  if (emojiHits.length > 0) {
    const unique = [...new Set(emojiHits)].slice(0, 8).join(" ");
    warnings.push(`检测到 ${emojiHits.length} 处彩色 Emoji（${unique}），工程/架构 SVG 建议替换为标准 24x24 矢量图标。`);
  }

  // Second pass: geometry, background colors, card containment, and animateMotion checks
  const overlapCandidates = [];
  const allRenderedCards = [];
  const textItems = [];

  const secondPass = (node, ctx) => {
    if (node.type !== "element") return;
    const lower = node.tag.toLowerCase();
    if (NON_RENDERED_CONTAINERS.has(lower)) return;

    const ownTf = parseTransform(resolveProp(node, "transform", cssRules));
    if (ownTf.complex) info.skippedComplexTransformCount += 1;

    const nextCtx = {
      tx: ctx.tx + ownTf.tx,
      ty: ctx.ty + ownTf.ty,
      complex: ctx.complex || ownTf.complex,
      fontSize: parseFontSize(resolveProp(node, "font-size", cssRules), ctx.fontSize),
      textAnchor: (resolveProp(node, "text-anchor", cssRules) || ctx.textAnchor).toLowerCase(),
    };

    if (lower === "animatemotion") {
      info.animateMotionCount += 1;
      const targetHref = (node.attrs.href || node.attrs["xlink:href"] || "").trim();
      let host = node.parent;
      let hostAncestorTx = ctx.tx;
      let hostAncestorTy = ctx.ty;
      if (targetHref.startsWith("#") && targetHref.length > 1) {
        const resolvedHost = elementById.get(targetHref.slice(1));
        if (resolvedHost && resolvedHost.type === "element") {
          host = resolvedHost;
          const anc = getElementAncestorTranslate(host, cssRules);
          const hostOwnTf = parseTransform(resolveProp(host, "transform", cssRules));
          hostAncestorTx = anc.tx + hostOwnTf.tx;
          hostAncestorTy = anc.ty + hostOwnTf.ty;
        }
      }
      if (host && host.type === "element") {
        const hostLower = host.tag.toLowerCase();
        const localX = parsePxNumber(host.attrs.cx ?? host.attrs.x ?? 0);
        const localY = parsePxNumber(host.attrs.cy ?? host.attrs.y ?? 0);
        const safeLocalX = Number.isFinite(localX) ? localX : 0;
        const safeLocalY = Number.isFinite(localY) ? localY : 0;
        const effX = safeLocalX + hostAncestorTx;
        const effY = safeLocalY + hostAncestorTy;

        const mpathChild = node.children.find((c) => c.type === "element" && c.tag.toLowerCase() === "mpath");
        let motionPathD = node.attrs.path || null;
        if (mpathChild) {
          const href = (mpathChild.attrs.href || mpathChild.attrs["xlink:href"] || "").trim();
          if (href.startsWith("#")) {
            const refPath = elementById.get(href.slice(1));
            if (refPath && refPath.attrs.d) {
              motionPathD = refPath.attrs.d;
            }
          }
        }

        const startPt = parsePathStart(motionPathD);
        const isZeroStaticAnchor =
          POSITIONED_SHAPE_TAGS.has(hostLower) && safeLocalX === 0 && safeLocalY === 0 && hostAncestorTx === 0 && hostAncestorTy === 0;

        if (isZeroStaticAnchor && (mpathChild || (startPt && (startPt.x !== 0 || startPt.y !== 0)))) {
          errors.push(
            `第 ${node.line} 行：<animateMotion> 宿主 <${host.tag}> 静态坐标位于 (0, 0) 且无外层 translate()，会破坏静态首帧落点。`
          );
        }

        if (effX !== 0 || effY !== 0) {
          if (mpathChild && !motionPathD) {
            errors.push(
              `第 ${node.line} 行：<animateMotion> 使用 <mpath> 且宿主有效偏移为 (${effX}, ${effY})，无法确认引用路径从 M 0 0 起算。`
            );
          } else if (motionPathD) {
            if (startPt) {
              if (startPt.x !== 0 || startPt.y !== 0) {
                errors.push(
                  `第 ${node.line} 行：<animateMotion> 路径起点 (${startPt.x}, ${startPt.y}) 叠加在宿主偏移 (${effX}, ${effY}) 上会触发 W3C 双重偏移，相对路径必须从 M 0 0 起算。`
                );
              }
            } else {
              warnings.push(`第 ${node.line} 行：<animateMotion> 路径 "${motionPathD.slice(0, 32)}" 未能识别 M 0 0 起点，请核对坐标系。`);
            }
          }
        }
      }
    }

    if (lower === "rect" && !nextCtx.complex) {
      const rawX = node.attrs.x !== undefined ? parsePxNumber(node.attrs.x) : 0;
      const rawY = node.attrs.y !== undefined ? parsePxNumber(node.attrs.y) : 0;
      const x = (Number.isFinite(rawX) ? rawX : 0) + nextCtx.tx;
      const y = (Number.isFinite(rawY) ? rawY : 0) + nextCtx.ty;
      const wStr = (node.attrs.width || "").trim();
      const hStr = (node.attrs.height || "").trim();
      const fill = normalizeColor(resolveProp(node, "fill", cssRules));
      const rx = parsePxNumber(node.attrs.rx ?? node.attrs.ry ?? 0) || 0;
      const w = parsePxNumber(wStr);
      const h = parsePxNumber(hStr);

      const isCanvasBg =
        vb &&
        (wStr === "100%" || (Number.isFinite(w) && w >= vb.w * 0.9)) &&
        (hStr === "100%" || (Number.isFinite(h) && h >= vb.h * 0.9));

      if (isCanvasBg) {
        if (PURE_BLACK_VALUES.has(fill)) {
          warnings.push(`第 ${node.line} 行：画布背景使用了纯黑（${fill}），建议改为深岩蓝 #0F172A 或 #0B0F19。`);
        } else if (PURE_WHITE_VALUES.has(fill)) {
          warnings.push(`第 ${node.line} 行：画布背景使用了刺眼纯白（${fill}），浅色主题建议改为 #F8FAFC 或暖纸色 #F5F2EC。`);
        }
      } else if (Number.isFinite(w) && Number.isFinite(h) && w >= 40 && h >= 18) {
        const box = { x, y, w, h, rx, fill, id: node.attrs.id || "", line: node.line, parent: node.parent };
        if (fill !== "none") {
          allRenderedCards.push(box);
        }

        if (vb && w >= 48 && h >= 28) {
          if (w < vb.w * 0.75 && h < vb.h * 0.75 && (rx >= 4 || fill !== "none")) {
            overlapCandidates.push(box);
          }
          if (x < vb.x - 2 || y < vb.y - 2 || x + w > vb.x + vb.w + 2 || y + h > vb.y + vb.h + 2) {
            warnings.push(`第 ${node.line} 行：矩形 (${Math.round(x)}, ${Math.round(y)}, ${w}×${h}) 超出 viewBox 边界。`);
          }
        }
      }
    }

    if (lower === "text" && vb && !nextCtx.complex) {
      textItems.push(...collectTextLines(node, nextCtx, cssRules, vb));
    }

    for (const child of node.children) {
      secondPass(child, nextCtx);
    }
  };

  if (svgRoot) {
    secondPass(svgRoot, { tx: 0, ty: 0, complex: false, fontSize: 14, textAnchor: "start" });
  }

  // Overlap check among candidate boxes
  let overlapCount = 0;
  for (let i = 0; i < overlapCandidates.length; i += 1) {
    for (let j = i + 1; j < overlapCandidates.length; j += 1) {
      if (hasPartialOverlap(overlapCandidates[i], overlapCandidates[j])) {
        overlapCount += 1;
        if (overlapCount <= 5) {
          const a = overlapCandidates[i];
          const b = overlapCandidates[j];
          warnings.push(
            `检测到节点矩形疑似部分重叠：L${a.line}(${Math.round(a.x)},${Math.round(a.y)} ${a.w}×${a.h}) 与 L${b.line}(${Math.round(b.x)},${Math.round(b.y)} ${b.w}×${b.h})，请渲染看图确认。`
          );
        }
      }
    }
  }
  if (overlapCount > 5) {
    warnings.push(`其余还有 ${overlapCount - 5} 处矩形疑似部分重叠。`);
  }

  // Text canvas-overflow & enclosing-card overflow check
  if (vb) {
    let canvasOverflowHints = 0;
    let cardOverflowHints = 0;

    for (const item of textItems) {
      const estW = item.width;
      let left = item.x;
      let right = item.x + estW;
      if (item.anchor === "middle") {
        left = item.x - estW / 2;
        right = item.x + estW / 2;
      } else if (item.anchor === "end") {
        left = item.x - estW;
        right = item.x;
      }

      if (left < vb.x + 2 || right > vb.x + vb.w - 2 || item.y < vb.y + 8 || item.y > vb.y + vb.h - 2) {
        canvasOverflowHints += 1;
        if (canvasOverflowHints <= 5) {
          warnings.push(
            `第 ${item.line} 行：文本 "${item.text.slice(0, 24)}" 估算边界 [${Math.round(left)}, ${Math.round(right)}] 贴近或超出画布。`
          );
        }
        continue;
      }

      const enclosing = allRenderedCards
        .filter(
          (c) =>
            c.w * c.h < vb.w * vb.h * 0.65 &&
            item.x >= c.x &&
            item.x <= c.x + c.w &&
            item.y >= c.y &&
            item.y <= c.y + c.h
        )
        .sort((a, b) => a.w * a.h - b.w * b.h);

      if (enclosing.length > 0) {
        const card = enclosing[0];
        if (left < card.x - 2 || right > card.x + card.w + 2) {
          cardOverflowHints += 1;
          if (cardOverflowHints <= 5) {
            warnings.push(
              `第 ${item.line} 行：文本 "${item.text.slice(0, 24)}" 估算宽度 ${Math.round(estW)}px（[${Math.round(left)}, ${Math.round(right)}]）可能撑爆所在卡片 L${card.line}（[${Math.round(card.x)}, ${Math.round(card.x + card.w)}]）。`
            );
          }
        }
      }
    }
  }

  // Motion-mode checks
  if (opts.motion) {
    for (const lid of ["layer-bg", "layer-nodes"]) {
      if (!idMap.has(lid)) {
        warnings.push(`--motion 模式建议包含语义分组 <g id="${lid}">。`);
      }
    }
    if (info.renderedIdCount < 4) {
      warnings.push(
        `--motion 模式下可视层语义 id 偏少（仅 ${info.renderedIdCount} 个，不含 <defs>），请为需要独立高亮/进场的元素添加语义 id。`
      );
    }
    if (info.dataStepCount === 0) {
      warnings.push('--motion 模式未发现 data-step 属性，建议标注每个元素所属演示节拍（如 data-step="1"）。');
    }
    if (animEdgesInvalidPathLength.length > 0) {
      warnings.push(
        `--motion 模式下第 ${animEdgesInvalidPathLength.slice(0, 5).join(", ")} 行的 .anim-edge 缺少有效的正数 pathLength（建议 pathLength="1"）。`
      );
    }
  }

  info.errors = errors.length;
  info.warnings = warnings.length;
  return { ok: errors.length === 0, info, errors, warnings };
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
      "Usage: node lint-svg.mjs <file.svg> [--motion] [--inline] [--json]\n" +
        "  --motion  Enforce semantic layer IDs, data-step hooks, and positive anim-edge pathLength\n" +
        "  --inline  Treat missing xmlns as warning (for HTML inline SVG fragments)\n" +
        "  --json    Print structured JSON report"
    );
    process.exit(0);
  }

  if (!opts.file) {
    console.error("错误：请指定要检查的 SVG 文件路径。");
    process.exit(1);
  }

  const filePath = path.resolve(opts.file);
  if (!fs.existsSync(filePath)) {
    console.error(`错误：文件不存在 -> ${filePath}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(filePath, "utf8");
  const result = lintSvg(raw, opts);
  result.info.file = filePath;

  if (opts.json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(
      `[svg-lint] 文件: ${path.basename(filePath)} (${result.info.bytes} bytes, viewBox: ${result.info.viewBox || "N/A"})`
    );
    if (result.errors.length === 0 && result.warnings.length === 0) {
      console.log("[svg-lint] PASS：未发现语法或规范问题。");
    } else {
      for (const e of result.errors) console.log(`  [ERROR] ${e}`);
      for (const w of result.warnings) console.log(`  [WARN]  ${w}`);
      console.log(`[svg-lint] 汇总：${result.errors.length} error(s), ${result.warnings.length} warning(s)`);
    }
  }

  process.exit(result.ok ? 0 : 1);
}

if (isCliEntry(import.meta.url)) {
  main();
}
