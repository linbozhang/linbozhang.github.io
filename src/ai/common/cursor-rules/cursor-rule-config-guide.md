# Cursor Rule 配置指南

本文说明如何在 Cursor 中**新增一条 Rule**，以及常用配置项的含义，便于按项目或文件类型定制 AI 行为。

---

## 1. Rule 是什么、放在哪

- **Rule**：一段持久化的说明，会作为上下文注入到与 Cursor AI 的对话中，用来约束或引导回答（如代码风格、项目约定、必须执行的流程等）。
- **位置**：项目根目录下的 **`.cursor/rules/`**，每条 Rule 一个文件。
- **格式**：**`.mdc`** 文件（Markdown + 顶部 YAML frontmatter），Cursor 会自动读取该目录下所有 `.mdc`。

```
项目根/
└── .cursor/
    └── rules/
        ├── docs-structure.mdc    # 文档库结构约定
        ├── ask-chain.mdc         # 每轮必须以提问结束
        └── my-new-rule.mdc       # 你新建的规则
```

---

## 2. 新增一条 Rule 的步骤

### Step 1：在 `.cursor/rules/` 下新建 `.mdc` 文件

- 文件名建议小写、连字符，如 `typescript-standards.mdc`、`api-conventions.mdc`。
- 文件名会出现在 Cursor 的规则列表中，便于识别。

### Step 2：写 YAML frontmatter（配置项）

在文件**最顶部**写三横线包裹的 YAML 块，至少包含 `description`，并按需设置 `globs`、`alwaysApply`：

```yaml
---
description: 一句话说明这条规则做什么（会显示在规则列表里）
globs: "**/*.ts"        # 可选，见下文
alwaysApply: false      # 可选，默认 false，见下文
---

```

- **description**：必填，简短说明规则用途。
- **globs**：可选，文件路径匹配模式，决定「在什么文件被打开时启用这条规则」。
- **alwaysApply**：可选，为 `true` 时每条对话都会带上这条规则，与当前打开文件无关。

### Step 3：写规则正文

frontmatter 下方用 Markdown 写具体内容：要求、示例、禁止项等。AI 会把这些内容当作必须遵守的上下文。

```markdown
---
description: TypeScript 错误处理约定
globs: "**/*.ts"
alwaysApply: false
---

# TypeScript 错误处理

- 禁止空的 catch 块，必须记录或再抛出。
- 使用 `logger.error` 并带上上下文。
```

保存后，Cursor 会自动加载，无需重启（若未生效可重开对话或编辑器）。

---

## 3. 配置项说明

### 3.1 `description`（必填）

| 含义 | 说明 |
|------|------|
| **作用** | 规则的一句话简介，会在 Cursor 的规则列表/选择器中显示。 |
| **建议** | 简短、能看出规则主题即可，例如：「个人文档库 src 下 Markdown 与 SUMMARY 的规范」。 |

### 3.2 `alwaysApply`（可选，默认 `false`）

| 取值 | 含义 |
|------|------|
| **`true`** | 这条规则**每次对话都会**被注入上下文，与当前打开哪个文件无关。适合全局约定（如「每轮必须以提问结束」、全项目代码风格）。 |
| **`false`** | 是否启用由 **`globs`** 决定：只有当前打开/聚焦的文件路径匹配 `globs` 时，这条规则才会被加入。 |

当同一条规则既想「全局生效」又想「只在某类文件生效」时，二选一：要么 `alwaysApply: true`（全局），要么用 `globs` 限定范围。

### 3.3 `globs`（可选，仅当 `alwaysApply: false` 时有效）

| 含义 | 说明 |
|------|------|
| **作用** | 文件路径匹配模式。**当前编辑器里打开或聚焦的文件**的路径若匹配该模式，这条规则就会被加入本次对话的上下文。 |
| **格式** | 与常见 glob 一致，相对于项目根。可写一条，也可多行/数组（视 Cursor 版本而定）。 |
| **常见写法** | 见下表。 |

| 模式示例 | 匹配范围 |
|----------|----------|
| `**/*.ts` | 任意目录下的 `.ts` 文件 |
| `**/*.tsx` | 任意目录下的 `.tsx` 文件 |
| `src/**/*.md` | `src/` 下所有 `.md` |
| `backend/**/*.py` | `backend/` 下所有 `.py` |
| `**/package.json` | 任意层级的 `package.json` |

未写 `globs` 且 `alwaysApply: false` 时，规则通常**不会自动生效**，只可能在手动选择规则时被选中（视 Cursor 版本而定）。

---

## 4. Cursor 如何决定用哪几条规则

- **不是「多选一」**：所有满足条件的规则会**一起**被注入，同时生效。
- **条件**：
  1. **`alwaysApply: true`** 的规则 → 始终带上。
  2. **`alwaysApply: false`** 且配置了 **`globs`** 的规则 → 仅当**当前打开/聚焦的文件路径**匹配其 `globs` 时带上。

因此可能出现：同时打开多个文件时，以**当前聚焦**的那个文件为准，决定哪些「按 globs 生效」的规则被加载；而 `alwaysApply: true` 的规则始终在。

---

## 5. 配置示例

### 示例 A：仅在某类文件生效

```yaml
---
description: 个人文档库 src 下 Markdown 与 SUMMARY 的规范
globs: src/**/*.md
alwaysApply: false
---
```

→ 只有当你打开或聚焦 `src/` 下某个 `.md` 时，这条规则才会参与对话。

### 示例 B：全局生效

```yaml
---
description: Hard contract - every round must end with AskQuestion
alwaysApply: true
---
```

→ 每次对话都会带上这条规则，与打开什么文件无关。

### 示例 C：只对根目录某文件生效

```yaml
---
description: 本项目的 book.toml 修改约定
globs: book.toml
alwaysApply: false
---
```

→ 只有当前聚焦 `book.toml` 时才会启用。

---

## 6. 使用建议

- **一条规则只做一件事**：便于维护和排查；多件事拆成多个 `.mdc`。
- **控制篇幅**：单条规则尽量简短（例如几十行以内），核心要求写清楚即可。
- **写清可执行要求**：多写「要怎么做」「不要怎么做」，少写泛泛说明。
- **需要时再 `alwaysApply: true`**：全局规则会占用上下文，只把真正全局需要的设为 `true`。

---

## 7. 小结

| 步骤 | 操作 |
|------|------|
| 1 | 在 `.cursor/rules/` 下新建 `xxx.mdc` |
| 2 | 顶部写 YAML frontmatter：`description` 必填，`globs` / `alwaysApply` 按需 |
| 3 | 下面写 Markdown 正文，描述规则内容 |
| 4 | 保存后 Cursor 自动加载；`alwaysApply: true` 则每次对话生效，否则由当前打开文件是否匹配 `globs` 决定 |

通过上述方式即可为项目或某类文件配置新的 Cursor Rule，并理解各配置项的含义与生效范围。
