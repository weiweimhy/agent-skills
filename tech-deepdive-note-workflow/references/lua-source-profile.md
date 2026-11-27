# 《Lua 源码解析》系列即插即用适配档案

本文档把 `tech-deepdive-note-workflow` 的通用写作与审阅标准落到 **《Lua 源码解析》** 系列，开写前直接按本档案执行工具链侦察、版本锁定、制图设计、防伪闭环审计与全库 QA。

---

## 一、工具链侦察基线与构建隔离

开写任何一章前，必须在本机先实测以下工具清单与路径（缺失工具严禁伪造输出，未实拍 IDE 调试步骤必须注明）：

| 工具角色 | 实测确认项 | 隔离与用法纪律 |
| :--- | :--- | :--- |
| **C 编译器** | `clang` / `gcc`（例如 LLVM-MinGW `clang`/`gcc`） | 探针用 `-std=c99 -O0 -g3 -fno-builtin` + `-Wall -Wextra -Werror` 严格编译（Lua 源码自身构建按官方 `Makefile` 或独立隔离构建区）。 |
| **Lua 源码树与构建产物** | 锁定本地源码目录与纯净官方发布包 SHA-256 | 禁止修改并污染干净上游源码；C 探针编译与临时构建目录一律放 `$env:TEMP\lua_probe_<rand>`（或独立隔离 `.tmp` 并在结束时清零）。 |
| **字节码反汇编器** | `luac -l -l <script.lua>` | 用 `-l -l` 输出完整常量表、LocVar 表与 Upvalue 映射表，对照 `lparser.c` / `lcode.c` / `ldebug.c`。 |
| **源码级调试器** | `lldb`（命令行批处理 `--batch`）与 CLion（GUI 同屏） | 调试器里必须核对断点触发时的调用栈、`CallInfo` 指针、`L->top`、`marked` 位与队列指针；CLion 操作须写清四要素并标注未实拍截图边界。 |

---

## 二、版本与源码行号锁定纪律

Lua 不同小版本（5.1 / 5.3 / 5.4.3 / 5.4.6+）在 `TValue` 标签、`Table` 边界字段、`UpVal` 链表和分代 GC 状态机上存在实质差异：

1. **必须锁死单一基准版本**：在系列总导航和每篇实验前提中明写锁定的准确版本号（例如 `Lua 5.4.3` 及官方 `lua-5.4.3.tar.gz` SHA-256 `f8612276169e3bfcbcfb8f226195bfc6e466fe13042f1076cbde92b7ec96bbfb`），禁止把 5.1/5.3 的旧宏名或字节码编号混入 5.4 正文。
2. **源码引用精确到“文件 + 结构体/函数名 + 行号”**（基于锁定源码树核实后填写，如 Lua 5.4.3 基准）：
   - `src/lobject.h`：`TValue`（L65）、`TString`（L373）、`Proto`（L539）、`UpVal`（L616）、`LClosure`（L641）、`Table`（L724）
   - `src/lstate.h`：`CallInfo`（L172）、`global_State`（L249，含 `gray` / `grayagain` / `weak` / `ephemeron` / `allweak`）、`lua_State`（L304，含 `twups`）
   - `src/lgc.h`：`G_OLD0`/`G_OLD1`/`G_OLD`（L108–110）、`luaC_barrier_` / `luaC_barrierback_`（L183–184）
3. **跨小版本或移植对照**：仅在独立对比节显式标注差异（如 Lua 5.4.3 vs 5.4.6 或 LuaJIT / xLua），不得混写在同一套内存偏移里。

---

## 三、五大核心数据结构深色 SVG 动图范式

编写《Lua 源码解析》时，至少以下 5 类最抽象机制必须配齐遵循 [深色 SVG 动图规范卡](svg-dark-theme-spec.md) 的深色 SVG 动图：

| 主题章节 | 推荐动图范式 | 图面核心元素与动效导引路径 |
| :--- | :--- | :--- |
| **1. `TValue` 与值槽布局** | 全景嵌套解剖 + 位段标注 | 左画 `TValue` 16B（`Value` 8B 联合体 + `lu_byte tt_` 标签 + 对齐填充），右画整数 `LUA_VNUMINT` / 浮点 `LUA_VNUMFLT` / `GCObject *gc` 指向堆对象链。光点从 `tt_` 分叉指向对应解码说明。 |
| **2. `Table` 数组/哈希混合区** | 双栏映射 + 碰撞重链 | 上栏 `array` 连续下标区（`alimit` 边界与 `realasize`），下栏 `node` 哈希桶与 `lastfree` 从尾部向前的碰撞探测链（`next` 偏移跳转）。光点演示插入碰撞与触发 `rehash` 迁移轨迹。 |
| **3. `Proto` / `UpVal` / `LClosure`** | 三幕剧状态演化 + 双链表 | 对比函数未返回时 **Open `UpVal`**（`v` 指向栈槽、`u.open` 挂在 `L->twups` / `L->openupval` 链表）与外层函数退出 `luaF_close` 后的 **Closed `UpVal`**（`v` 重指内部 `u.value`）。光点演示指针脱离 Lua 栈帧并就地迁移。 |
| **4. 虚拟机寄存器窗口与 `CallInfo`** | 跨层泳道 + 滑动窗口 | 左栏画 `L->stack` 连续 `StackValue` 槽位（`R(0)..R(n)` 相对 `ci->func` 移动），右栏画双向链表 `CallInfo`（`previous`/`next`、`func`、`top`、`u.l.savedpc`），对照普通 `OP_CALL` 压新 `CallInfo` vs `OP_TAILCALL` 原地复用帧。 |
| **5. 增量 / 分代 GC 三色标记与屏障** | 四态状态机 + 跳板回挂闭环 | 展示 `White` → `Gray` → `Black` 推进中遇到“黑对象新指向白对象”的违规边：上方分支画前向屏障 `luaC_barrier_` 直接将子对象标灰/标老（`G_OLD0`）；下方分支画表写入后向屏障 `luaC_barrierback_` 将黑表退回灰并挂入 `g->grayagain`（`G_TOUCHED1`）。 |

---

## 四、Lua 源码解析特化的“防伪闭环”红线

除通用 4 类伪闭环外，针对源码解析系列额外增加 **4 条硬性审阅红线**：

1. **禁止“纯 Lua 输出冒充 C 内部状态实证”**：仅凭 Lua 脚本里 `print(collectgarbage("count"))` 或对象最终存活，不能宣称证明了三色转换、写屏障路径或 `lastfree` 碰撞链；必须用 C 探针读取只读内部结构或调试器源码级断点实锤才算打穿。
2. **禁止把单次实验计数写成通用规律**：如构造某次增量步进 `step == 300` 触发特定 GC 状态，必须显式写明这是“当前输入与步长下的实验干预点，换条件需重新确认”，严禁当成 API 恒定规律。
3. **严格切割三层事实边界（防误判规范）**：每篇核心章节必须明确划分 **① Lua 语言层保证的语义**（如 `7 == 7.0`、表键等价） vs **② 公开 C API 契约**（如 `lua_isinteger`、`lua_tointegerx`） vs **③ 当前版本私有实现细节**（如 `TValue` 大小、短串长度上限 `LUAI_MAXSHORTLEN`、表扩张阈值），提醒读者勿在生产宿主代码里硬编码私有内存偏移。
4. **禁止靠 C 探针篡改内部队列制造假现场**：C 探针只能通过公开 Lua/C API（如 `lua_rawseti`、`lua_setupvalue`、`lua_gc`）触发正常状态转换后**只读观察**内部字段，严禁手动写 `marked` 位或伪造 `grayagain` 链表来制造“伪触发”。

---

## 五、全库 QA 脚本即插即用示例

在审阅提笔书的《Lua 源码》系列目录时，直接运行以下命令执行无修改只读体检（排除旧稿参考、检查跨版本混词与实验目录残留）：

```powershell
pwsh "<skill-dir>/scripts/Invoke-DeepdiveNoteQA.ps1" `
  -Root "<TIBISHU_NOTES_PATH>\技术学习与实验\Lua 源码" `
  -ExcludeDirRegex '\\(archive|early-notes)\\' `
  -ForbiddenTerms @('LUA_TNUMINT', 'LUAC_FORMAT_OLD') `
  -LabDirRegex '(^|\\)(probe|.*-lab)(\\|$)' `
  -FailOnError
```

> 说明：Lua 5.4 中数字整数变体名为 `LUA_VNUMINT`（5.3 为 `LUA_TNUMINT`），可根据具体锁定的版本自定义 `-ForbiddenTerms` 抓出跨版本笔误。
