# Cursor 规则与 Skill 搭建过程

本文记录为本工程（mdBook 个人文档库）创建 **文档模板（template）**、**Skill（doc-library）** 与 **Cursor Rule（docs-structure）** 的完整过程，便于复现或调整。

---

## 1. 背景与目标

- **工程性质**：个人文档库，使用 mdBook 构建，`src/` 下为正文，`src/SUMMARY.md` 为侧栏目录唯一来源。
- **需求**：希望 AI 能**按统一规范**自动整理、新增文档，避免路径与 SUMMARY 不一致。
- **做法**：在项目内建立「模板 + Skill + Rule」组合，让 AI 在添加/整理文档时自动遵循约定。

---

## 2. 创建了哪些内容

| 类型 | 路径 | 作用 |
|------|------|------|
| **文档模板** | `.cursor/skills/doc-library/template.md` | 定义目录结构、路径规则、SUMMARY 写法、单页文档模板与新增文档的标准流程。 |
| **Skill** | `.cursor/skills/doc-library/SKILL.md` | 教 AI 何时、如何按模板添加/整理文档（归属判断、命名、更新 SUMMARY、自检）。 |
| **Cursor Rule** | `.cursor/rules/docs-structure.mdc` | 在编辑 `src/**/*.md` 时提醒：正文在 `src/`、侧栏只认 SUMMARY、路径与命名约定、子分类下可有独立文档。 |

---

## 3. 创建过程简述

### 3.1 文档模板（template.md）

1. **确定规范**：顶层分类（编程语言 / 游戏引擎 / AI / 站点）、子分类用「目录 + README.md」、单篇/独立文档用「小写英文-连字符.md」、SUMMARY 路径相对 `src/`、子项比父项多 2 空格缩进。
2. **写模板文件**：在 `.cursor/skills/doc-library/` 下新建 `template.md`，包含：
   - 目录与路径规范（含示例目录树）；
   - SUMMARY.md 的格式与示例；
   - 分类入口页、普通文档页的 Markdown 模板；
   - 「新增/整理文档」的标准流程（确定归属 → 定路径 → 写内容 → 更新 SUMMARY → 自检）；
   - 命名与风格约定。
3. **后续调整**：允许子分类下除 README 外存在独立 `.md` 文档，在 1.2 路径规则与示例中补充说明。

### 3.2 Skill（doc-library）

1. **Skill 结构**：同一目录下 `SKILL.md` + `template.md`（Skill 内引用模板）。
2. **SKILL.md 内容**：
   - **frontmatter**：`name: doc-library`，`description` 写明「按模板添加/整理文档」及触发场景（新增文档、整理、按模板归类等）。
   - **何时使用**：用户提出新增文档、新建子章节、按模板整理等时。
   - **标准流程**：确定归属与路径 → 命名与文件（分类用 README，独立文档用小写连字符 .md，可放在子分类下）→ 更新 SUMMARY → 自检。
   - **关键规则**：SUMMARY 为侧栏唯一来源、路径相对 `src/`、缩进与文件名约定。
3. **与模板关系**：Skill 中不重复写完整规范，只写流程与规则摘要，并指向 `template.md` 查阅细节。

### 3.3 Cursor Rule（docs-structure.mdc）

1. **规则位置**：`.cursor/rules/docs-structure.mdc`。
2. **frontmatter**：`globs: src/**/*.md`，`alwaysApply: false`，仅在对 `src/` 下 Markdown 进行编辑时应用。
3. **内容**：简短几条——正文仅在 `src/`、侧栏唯一来源是 SUMMARY、改文档需同步改 SUMMARY、路径与缩进、文件名与分类入口约定、子分类下可有独立文档；并注明详细模板与流程在 `.cursor/skills/doc-library/`。

---

## 4. 使用方式

- **让 AI 按模板整理**：直接说「按模板在某某分类下加一篇文档」「把某段内容按文档库整理进去」等，AI 会应用 doc-library Skill，按 template 执行。
- **编辑已有文档时**：打开 `src/` 下任意 `.md` 时，docs-structure 规则会生效，提醒同步更新 SUMMARY 和遵守命名/路径。
- **修改规范时**：改 `template.md` 即可；若流程或触发条件要变，再改 `SKILL.md` 与 `docs-structure.mdc`。

---

## 5. 可选扩展（MCP）

当前未实现 MCP 服务。若需要「通过 MCP 工具创建文档、校验 SUMMARY」等，可在此基础上增加 MCP 服务，对外提供如「根据模板创建文档」「检查 SUMMARY 与文件一致性」等能力；Skill 与 Rule 仍负责在对话中引导 AI 按模板操作。

---

## 6. 小结

通过「template（规范与示例）+ Skill（流程与触发）+ Rule（编辑时提醒）」的组合，本工程实现了 AI 可自动遵循的文档库规范；子分类下既可只有 README，也可包含若干独立 `.md` 文档，只需在 SUMMARY 中逐条列出即可。
