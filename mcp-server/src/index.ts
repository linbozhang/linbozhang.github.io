/**
 * 最小可运行的 MCP Server (TypeScript + stdio)
 * 暴露两个工具：get_current_time、add
 * 用于 Cursor / Claude Desktop 等 MCP 客户端连接
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "minimal-mcp-server",
  version: "1.0.0",
});

// 工具：返回当前时间
server.registerTool(
  "get_current_time",
  {
    description: "返回当前系统时间（ISO 格式）",
    inputSchema: {},
  },
  async () => {
    const text = new Date().toISOString();
    return { content: [{ type: "text", text }] };
  }
);

// 工具：两数相加
server.registerTool(
  "add",
  {
    description: "计算两个数字的和",
    inputSchema: {
      a: z.number().describe("第一个数"),
      b: z.number().describe("第二个数"),
    },
  },
  async ({ a, b }) => {
    const text = String(a + b);
    return { content: [{ type: "text", text }] };
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stdio 模式下只能写 stderr，不能 console.log
  console.error("Minimal MCP Server running on stdio");
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
