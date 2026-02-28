# 最小可运行的 MCP Server (TypeScript)

通过 stdio 暴露两个工具，供 Cursor、Claude Desktop 等 MCP 客户端调用。

## 工具

| 名称 | 说明 |
|------|------|
| `get_current_time` | 返回当前系统时间（ISO 格式） |
| `add` | 两数相加，参数 `a`, `b` |

## 安装与构建

```bash
cd mcp-server
npm install
npm run build
```

## 本地运行（测试）

```bash
npm run start
```

运行后进程会等待 stdin 的 JSON-RPC 消息；用 Cursor 等客户端连接时由客户端负责启动本进程。

## 在 Cursor 中配置

1. 打开 Cursor **Settings → MCP**（或编辑 `~/.cursor/mcp.json` / 项目 `.cursor/mcp.json`）。
2. 添加一个 stdio 类型的 server，例如：

```json
{
  "mcpServers": {
    "minimal-mcp-server": {
      "command": "node",
      "args": ["H:/workspace/github/linbozhang.github.io/mcp-server/build/index.js"]
    }
  }
}
```

请将 `args` 中的路径改为你本机 `mcp-server/build/index.js` 的**绝对路径**。Windows 下可用正斜杠或双反斜杠。

3. 保存后重启 Cursor 或重新加载 MCP，在 Composer 中即可让 Agent 调用 `get_current_time` 与 `add`。

## 依赖

- Node.js 16+
- `@modelcontextprotocol/sdk`、`zod`

## 扩展

在 `src/index.ts` 中按相同方式调用 `server.registerTool(name, options, handler)` 即可增加新工具；`inputSchema` 使用 zod 定义参数，handler 返回 `{ content: [{ type: "text", text: "..." }] }`。
