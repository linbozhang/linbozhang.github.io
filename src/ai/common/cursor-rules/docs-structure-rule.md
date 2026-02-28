# 文档库结构规则

本文保存本项目 **文档库结构约定** 这条 Cursor Rule 的完整内容，并附简要说明。实际生效的配置文件为 `.cursor/rules/docs-structure.mdc`。

---

## 说明

- **用途**：在编辑 `src/` 下 Markdown 时，提醒 AI 遵守文档库约定——正文在 `src/`、侧栏唯一来源是 `SUMMARY.md`、路径与命名规范、子分类下可有独立文档等。避免新增/移动文档后漏改 SUMMARY 或写错路径。
- **生效范围**：`alwaysApply: false`，`globs: src/**/*.md`。仅当**当前打开或聚焦的文件**是 `src/` 下任意 `.md` 时才会被加载。
- **延伸**：更完整的目录规范、模板与流程见 `.cursor/skills/doc-library/`（template.md、SKILL.md）。

---

## 规则配置（frontmatter）

```yaml
---
description: 个人文档库 src 下 Markdown 与 SUMMARY 的规范
globs: src/**/*.md
alwaysApply: false
---
```

---

## 规则正文

（以下为 `.cursor/rules/docs-structure.mdc` 的正文部分。）
```markdown
# 文档库结构约定

- 正文仅在 `src/` 下；侧栏目录唯一来源是 `src/SUMMARY.md`。
- 新增/移动/删除文档后必须同步修改 SUMMARY；路径相对于 `src/`，子项比父项多 2 空格缩进。
- 文件名：小写英文与连字符（如 `cursor-guide.md`）；分类入口用目录 + `README.md`。子分类目录下除 README 外可有独立 `.md` 文档。
- 详细模板与流程见项目 Skill：`.cursor/skills/doc-library/`（含 template.md 与 SKILL.md）。
```
