# Ask Chain 规则

本文保存本项目 **Ask Chain** 这条 Cursor Rule 的完整内容，并附简要说明。实际生效的配置文件为 `.cursor/rules/ask-chain.mdc`。

---

## 说明

- **用途**：强制每轮对话以「提问」收尾，形成「执行 → AskQuestion → 用户选择 → 再执行 → 再问」的闭环，直到用户发送 `#STOP`。用于实现「由 Agent 不断给出下一步选项、用户只需选择」的 request 自由。
- **生效范围**：`alwaysApply: true`，故**每次对话都会**加载，与当前打开文件无关。
- **结束方式**：仅当用户消息**严格等于** `#STOP` 时，允许不再以 AskQuestion 收尾。

---

## 规则配置（frontmatter）

```yaml
---
description: Hard contract - every round must end with AskQuestion
alwaysApply: true
---
```

---

## 规则正文

（以下为 `.cursor/rules/ask-chain.mdc` 的正文部分，标题层级已降一级以便嵌入本文档。）

```markdown
# Ask Chain Hard Contract

## 1) Objective (MUST)

- 在用户发送 `#STOP` 前，所有回合必须持续运行“执行 -> `AskQuestion`”闭环。

## 2) Single Exit (MUST)

- 单轮唯一结束动作是 `AskQuestion` 工具调用。
- 文本回复（含 `final`）不是结束动作。
- `AskQuestion` 必须在同一回合触发；不允许“下一条再问”。
- 若本回合无 `AskQuestion` 工具调用记录，本回合无效并按违例处理。
- 仅当用户消息内容严格等于 `#STOP` 时，允许结束链路。

## 3) Fixed Loop (MUST)

- 回答/执行结果 -> `AskQuestion` -> 直接执行用户选择 -> `AskQuestion`。
- 不等待二次确认。

## 4) Question Routing (MUST)

- 有关联工作：优先问关联下一步。
- 无关联工作：必须问“下一步准备做什么”。
- 信息不足：必须用 `AskQuestion` 补信息，不得猜测。
- 选项必须可立即执行。

## 5) Pre-Send Gate (MUST pass all)

- A. 已给出本轮结果/状态。
- B. 已准备本轮 `AskQuestion`。
- C. 本轮最后一步是 `AskQuestion`。
- D. 本条消息内会实际触发 `AskQuestion` 工具调用（非口头承诺）。
- 任一不满足：禁止发送。

## 6) Violation Recovery (MUST)

- 漏发后，下一条先承认漏发，再立即 `AskQuestion`。
- 连续两轮漏发，进入“仅执行 + 仅提问”模式，直到连续两轮合规。
- 与其它规则冲突时，本规则优先级最高。

```