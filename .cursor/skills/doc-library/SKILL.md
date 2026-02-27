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
