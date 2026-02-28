# Cursor Skill 配置指南

本文说明如何在 Cursor 中**创建并配置一个 Skill**，以及常用字段与编写建议，便于为 Agent 增加专用工作流或领域能力。

---

## 1. Skill 是什么、放在哪

- **Skill**：一份（或多份）Markdown 文档，用于**教 Agent 如何完成某类任务**，如按规范整理文档、生成固定格式的 commit message、按步骤执行某工作流等。Agent 会根据对话内容与 `description` **自动判断是否启用**该 Skill。
- **位置**：以**目录**为单位，目录内必须包含 **`SKILL.md`**；可另加 `reference.md`、`examples.md`、`scripts/` 等。
- **两种存放方式**：
  - **项目 Skill**：放在项目根目录 **`.cursor/skills/<skill-name>/`**，随仓库共享。
  - **个人 Skill**：放在 **`~/.cursor/skills/<skill-name>/`**，对本机所有项目可用。

**注意**：不要往 `~/.cursor/skills-cursor/` 里放自定义 Skill，该目录为 Cursor 内置 Skill 保留。

```
# 项目 Skill 示例
项目根/
└── .cursor/
    └── skills/
        └── doc-library/
            ├── SKILL.md
            └── template.md

# 个人 Skill 示例（用户目录下）
~/.cursor/skills/
└── my-workflow/
    ├── SKILL.md
    └── reference.md
```

---

## 2. 新增一个 Skill 的步骤

### Step 1：确定用途与存放位置

- **用途**：要教 Agent 做什么？（例如：按模板在文档库里新增/整理文档。）
- **范围**：仅当前项目用 → 放在 **`.cursor/skills/<skill-name>/`**；多项目通用 → 放在 **`~/.cursor/skills/<skill-name>/`**。
- **技能名**：小写字母、数字、连字符，如 `doc-library`、`commit-helper`，最多 64 字符。

### Step 2：创建目录与 SKILL.md

- 在选定位置新建目录 `<skill-name>/`，在其下新建 **`SKILL.md`**。
- `SKILL.md` 顶部写 **YAML frontmatter**，至少包含 `name` 和 `description`；下方写 Markdown 正文（步骤、示例、约束等）。

### Step 3：写 frontmatter 与正文

- **name**：与目录名一致即可，如 `doc-library`。
- **description**：一句话说明「做什么 + 何时用」，用第三人称；Agent 靠它决定是否启用该 Skill。
- **正文**：写清步骤、输入输出、示例、禁止项；可引用同目录下的 `reference.md`、`examples.md` 做渐进披露。

保存后 Cursor 会自动加载；新对话中当用户请求匹配 description 时，Agent 会应用该 Skill。

---

## 3. 配置项说明（frontmatter）

### 3.1 `name`（必填）

| 含义 | 说明 |
|------|------|
| **作用** | Skill 的唯一标识，用于内部引用与目录对应。 |
| **规则** | 最多 64 字符；仅小写字母、数字、连字符（`a-z0-9-`）。 |
| **示例** | `doc-library`、`commit-helper`、`code-review`。 |

### 3.2 `description`（必填）

| 含义 | 说明 |
|------|------|
| **作用** | 供 Agent 判断「是否在该对话中启用此 Skill」；会注入到系统上下文中。 |
| **要求** | 非空，建议不超过 1024 字符。 |
| **建议** | **第三人称**；同时写清 **WHAT**（做什么）和 **WHEN**（何时用、触发场景）。 |

**示例：**

```yaml
# 好的 description：具体 + 触发场景
description: 按项目模板在文档库中新增或整理文档，并同步更新 SUMMARY。在用户提出「新增文档」「按模板整理」「更新 SUMMARY」时使用。

# 避免：过于笼统
description: 帮助处理文档
```

---

## 4. Cursor 如何决定用哪个 Skill

- **不是「多选一」**：可同时加载多条 Skill；Agent 根据**当前用户消息与上下文**判断哪些 Skill 相关。
- **主要依据**：各 Skill 的 **description**。若用户请求或对话主题与某条 description 中的「做什么、何时用」匹配，该 Skill 更可能被应用。
- **建议**：在 description 里写上**关键词与典型说法**（如「按模板」「PDF」「commit message」），便于触发。

---

## 5. 编写建议

- **SKILL.md 保持精简**：核心步骤与规则放在 SKILL.md，详细说明放到 `reference.md` 等，正文中用链接引用（渐进披露）。
- **description 要可触发**：包含「做什么」和「在什么情况下用」，并带一两个典型关键词。
- **正文简洁**：只写 Agent 真正需要、且不易从通用知识推断的内容；可多用列表、模板、检查清单。
- **路径**：正文与脚本路径用**正斜杠**（如 `scripts/helper.py`），避免反斜杠。
- **单条 Skill 聚焦一事**：一个工作流或一类任务一个 Skill，便于维护与触发。

---

## 6. 目录结构示例

```
.cursor/skills/doc-library/
├── SKILL.md          # 必选：frontmatter + 流程与规则摘要
├── template.md       # 可选：详细模板，供 SKILL 内链接引用
└── examples.md       # 可选：示例
```

SKILL.md 最小示例：

```markdown
---
name: doc-library
description: 按项目模板在文档库中新增或整理文档，并同步更新 SUMMARY。在用户提出新增文档、按模板整理、更新 SUMMARY 时使用。
---

# 文档库整理

## 流程
1. 确定归属（编程语言 / 游戏引擎 / AI / 站点）。
2. 按 template 定路径与命名，创建或移动文件。
3. 更新 src/SUMMARY.md，子项比父项多 2 空格缩进。
4. 建议用户运行 mdbook serve 自检。

## 规则
- 侧栏唯一来源是 SUMMARY.md；路径相对 src/。
- 详见 [template.md](template.md)。
```

---

## 7. 小结

| 步骤 | 操作 |
|------|------|
| 1 | 确定 Skill 用途与存放位置（项目 `.cursor/skills/` 或个人 `~/.cursor/skills/`） |
| 2 | 新建目录 `<skill-name>/`，在其中创建 `SKILL.md` |
| 3 | 写 frontmatter：`name`（小写连字符）、`description`（第三人称，WHAT + WHEN） |
| 4 | 写正文：步骤、规则、示例或链接到 reference.md；保持简洁 |
| 5 | 需要时在同目录下增加 template.md、reference.md、scripts/ 等 |

通过上述方式即可为 Cursor 增加可被 Agent 自动选用的 Skill，并理解各配置项的含义与编写要点。
