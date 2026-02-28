# doc-library Skill 完整示例

本文保存本项目 **doc-library** Skill 的完整代码，作为 Cursor Skill 的实际示例。实际生效的 Skill 位于 `.cursor/skills/doc-library/`。

---

## 说明

- **用途**：教 Agent 按项目模板在 mdBook 文档库中新增或整理文档，并同步更新 SUMMARY。
- **触发场景**：用户提出「新增文档」「按模板整理」「更新 SUMMARY」等请求时，Agent 会根据 `description` 自动启用。
- **结构**：目录形式，包含 `SKILL.md`（主文件）与 `template.md`（详细模板，供 SKILL 引用）。

---

## 目录结构

```
.cursor/skills/doc-library/
├── SKILL.md          # 主文件：frontmatter + 流程与规则
└── template.md       # 详细模板：路径规范、SUMMARY 写法、单页模板
```

---

## SKILL.md 完整代码

```markdown
---
name: doc-library
description: Adds or organizes documents in this mdBook personal doc library according to the project template. Use when the user asks to add a new doc, create a new section, move or reorganize docs, or "按模板整理文档".
---

# 个人文档库 — 按模板整理文档

本仓库是 mdBook 个人文档库（`src/` 为正文，`src/SUMMARY.md` 为侧栏目录）。添加或整理文档时必须遵守 [template.md](template.md)，并同步更新 SUMMARY。

## 何时使用本 Skill

- 用户要求「新增一篇文档」「加一个分类/子章节」「把某内容整理进文档库」
- 用户要求「按模板整理」「按目录结构归类」「更新 SUMMARY」
- 在 `src/` 下新增或移动 `.md` 文件、新建目录时

## 标准流程（必须按顺序执行）

### 1. 确定归属与路径

- **顶层只能属于其一**：编程语言 → `src/lang/`；游戏引擎 → `src/engine/`；AI → `src/ai/`；站点 → `src/site/`（本站搭建、mdBook 扩展与配置等）。
- 若归属已有子目录（如 `lang/rust/`、`engine/unity/shader/`），新文档放在对应目录下。
- 若需**新建子分类**：新建目录并在其下建 `README.md` 作为入口。

### 2. 命名与文件

- **分类入口**：目录名 + 其下 `README.md`（如 `unity/README.md`）。
- **单篇/独立文档**：`小写英文-连字符.md`（如 `cursor-guide.md`），可放在**分类目录下**或**子分类目录下**（与 README 同级）；子分类下允许既有 README 又有若干独立 `.md`。
- 先读 [template.md](template.md) 中「单页文档模板」，再写或改写内容。

### 3. 更新 SUMMARY.md

- 打开 `src/SUMMARY.md`。
- 在正确层级插入：`* [显示标题](相对路径)`。
- **相对路径**：相对于 `src/`，不含 `src/` 前缀；子项比父项多 2 空格缩进。
- 示例：在「代码生成」下加新页 → 在 `* [代码生成](ai/coding/README.md)` 下一行加 `  * [新标题](ai/coding/新文件名.md)`。

### 4. 自检

- 确认新文件路径、SUMMARY 条目与 template 一致。
- 建议用户本地运行 `mdbook serve` 检查侧栏与链接是否正常。

## 关键规则（不可违反）

- 侧栏目录**唯一来源**是 `src/SUMMARY.md`；新增/移动/删除文档后必须同步改 SUMMARY。
- 路径一律相对于 `src/`，SUMMARY 中写 `lang/rust/README.md`，不写 `src/lang/rust/README.md`。
- 同一层级缩进一致；子项比父项多 2 空格。
- 文件名只用小写字母、数字、连字符。

## 参考

- 完整路径规范、SUMMARY 示例、单页模板见 [template.md](template.md)。
- 当前目录结构以 `src/` 与 `src/SUMMARY.md` 为准，新增时保持与现有风格一致。
```

---

## template.md 完整代码

在 Markdown 中展示「代码里还有代码块」时，外层需用**更多反引号**做围栏（如 4 个），内层用 3 个，这样内层的 ``` 不会提前结束外层块。下面用 ````markdown` 与 ```` 包裹整段 template 内容。

````markdown
# 个人文档库 — 文档模板与规范

本仓库为 mdBook 个人文档库，所有正文在 `src/` 下，目录由 `src/SUMMARY.md` 定义。

---

## 1. 目录与路径规范

### 1.1 顶层分类

- **编程语言** → `src/lang/`（Rust / C++ / C# 等各占子目录）
- **游戏引擎** → `src/engine/`（Unity / Unreal / Bevy 等各占子目录）
- **AI** → `src/ai/`（代码生成、内容生成等）
- **站点** → `src/site/`（本站搭建、mdBook 扩展、主题与配置等；可按需新增顶层分类）

### 1.2 路径规则

- 每个**分类/子分类**用**目录**表示，入口页固定为 **`README.md`**。
- **子分类目录下**除 `README.md` 外，**允许有独立文档**：使用 **`小写英文-连字符.md`**（如 `basic-setup.md`），与 README 同级放在该子分类目录下即可；SUMMARY 中为该文档单独加一条。
- 子分类再分子目录时，同样用目录 + 其内 `README.md` 作为入口；该子目录下也可再放独立 `.md` 文档。

**示例：**

```
src/
├── lang/
│   ├── README.md        # 编程语言入口（可简短说明）
│   ├── rust/
│   │   └── README.md    # Rust 入口
│   ├── cpp/
│   │   └── README.md
│   └── csharp/
│       └── README.md
├── engine/
│   ├── README.md
│   ├── unity/
│   │   ├── README.md
│   │   ├── shader/
│   │   │   ├── README.md
│   │   │   ├── toon/
│   │   │   │   ├── README.md
│   │   │   │   └── basic-setup.md   # 子分类下的独立文档（可选）
│   │   │   └── pbr/
│   │   │       └── README.md
│   │   └── editor-tools/
│   │       └── README.md
│   ├── unreal/
│   │   └── README.md
│   └── bevy/
│       └── README.md
├── ai/
│   ├── README.md
│   ├── coding/
│   │   ├── README.md
│   │   └── cursor-guide.md
│   └── content/
│       └── README.md
├── site/
│   ├── README.md        # 站点入口（搭建、扩展、配置等）
│   └── doc-setup/
│       ├── README.md
│       └── custom-sidebar.md
├── README.md            # 站点首页（简介）
└── SUMMARY.md           # 侧栏目录，唯一来源
```

---

## 2. SUMMARY.md 写法（侧栏目录）

- 第一行为：`# Summary`
- 第二行为：`[简介](README.md)`
- 之后用 `---` 分隔，再按层级写目录项。
- 每条格式：`* [显示标题](相对路径)`，路径相对于 `src/`，**不要**带 `src/` 前缀。
- 子项比父项多 **2 个空格** 缩进；同一层级对齐。

**示例：**

```markdown
# Summary

[简介](README.md)

---

* [编程语言](lang/README.md)
  * [Rust](lang/rust/README.md)
  * [C++](lang/cpp/README.md)
* [游戏引擎](engine/README.md)
  * [Unity](engine/unity/README.md)
    * [Shader](engine/unity/shader/README.md)
      * [卡通着色](engine/unity/shader/toon/README.md)
      * [基础设置](engine/unity/shader/toon/basic-setup.md)   <!-- 子分类下的独立文档 -->
      * [PBR](engine/unity/shader/pbr/README.md)
    * [编辑器工具](engine/unity/editor-tools/README.md)
* [AI](ai/README.md)
  * [代码生成](ai/coding/README.md)
  * [内容生成](ai/content/README.md)
* [站点](site/README.md)
  * [文档库配置](site/doc-setup/README.md)
```

---

## 3. 单页文档模板

### 3.1 分类入口页（README.md）

用于「编程语言」「Unity」「Shader」等分类的入口，简短说明 + 子章节提示：

```markdown
# [分类名]

*（待补充）*

[一句话说明本分类内容]。子章节包括 [A]、[B] 等，后续会持续补充。
```

### 3.2 普通文档页（具体主题）

用于教程、笔记等单篇文档：

```markdown
# [文档标题]

*（待补充）*（可选，后续可删）

[正文：说明、步骤、示例等。使用常见 Markdown：标题、列表、代码块、表格。]
```

- 首行为一级标题 `# 标题`，与侧栏显示一致。
- 正文用中文；代码、命令、专有名词可保留英文。

---

## 4. 新增/整理文档的标准流程

1. **确定归属**：属于「编程语言 / 游戏引擎 / AI」下哪一类、哪一层（是否要新建子分类）。
2. **定路径**：
   - 新建子分类 → 新建目录 + 该目录下 `README.md`。
   - 单篇文档 → 放在对应分类目录下，文件名 `xxx.md`（小写+连字符）。
3. **写/改正文**：按上面 3.1 或 3.2 模板写或补全内容。
4. **更新 SUMMARY**：在 `src/SUMMARY.md` 中在正确层级插入一行（或一段）：
   - `* [显示标题](相对路径)`
   - 相对路径与文件实际路径一致（如 `ai/coding/新文件名.md`）。
5. **自检**：本地运行 `mdbook serve`，确认侧栏与页面能正确打开、无 404。

---

## 5. 命名与风格约定

- **文件名**：仅用小写字母、数字、连字符（`-`），如 `cursor-guide.md`、`shader-toon.md`。
- **标题**：可与文件名不同，用中文或英文，在 SUMMARY 和页面 `# 标题` 中保持一致。
- **正文**：默认中文；技术术语、代码、命令不翻译。
- 不在 `src/` 下放与 mdBook 无关的二进制或脚本；资源可放 `src/` 下子目录或项目根下单独目录（若需再约定）。
````

---

## 使用说明

- **实际生效位置**：`.cursor/skills/doc-library/`（项目 Skill，随仓库共享）。
- **如何触发**：用户说「按模板在文档库加一篇文档」「整理文档库」等时，Agent 匹配 `description` 后自动启用。
- **配合使用**：与 `.cursor/rules/docs-structure.mdc` 配合——Skill 提供「如何做」的流程，Rule 在编辑 `src/**/*.md` 时提醒「必须同步 SUMMARY」等约束。
