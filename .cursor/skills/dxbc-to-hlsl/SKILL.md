---
name: dxbc-to-hlsl
description: Translates DXBC (DirectX bytecode) or shader assembly into readable HLSL as a literal translation. Use when the user asks to convert DXBC to HLSL, reverse-engineer shader assembly to HLSL, or "转成 hlsl"/"反推 shader".
---

# DXBC → 可读 HLSL 直译

将 DXBC（ps_5_0 / vs_5_0 等）或 shader 汇编**直译**为可读 HLSL，不猜测语义，仅做「汇编→HLSL」的逐段对应。

## 何时使用本 Skill

- 用户提供一段 DXBC / shader 汇编，要求「转成 HLSL」「反推成可读代码」
- 用户要求「按汇编直译，不要猜功能」

## 必须遵守的约定

### 1. 中性命名，不猜测功能

- 常量缓冲：`cb0[i]`、`cb1[i]`（与汇编下标一致）
- 纹理 / 采样器：`T0`–`T5`、`S0`–`S5`
- 输入：`v1.xy`、`v2.xyz`、`v3.xyzw`、`v4.xyz`、`v5.x` 等，可命名为 `v1_xy`、`v2_xyz` 等
- 输出：`o0`–`o3`
- 中间寄存器：`r0`、`r1`、…（与汇编一致）
- 不引入「这是 base color / shadow / normal」等语义命名，除非用户后续要求

### 2. 纹理采样得到的向量用 .rgba

- 从 `Texture.Sample` / `SampleBias` / `SampleCmpLevelZero` 等得到的向量，访问分量时用 **`.r`、`.g`、`.b`、`.a`**，不用 `.x`、`.y`、`.z`、`.w`

### 3. 遍历**lib/*.hlsl**中的所有函数，找到能替代对应汇编代码的部分的时候，不必保留一长段内联实现，用响应的库函数替换，便于阅读


## 输出形式

- 按汇编指令区间加简短行号注释（如 `// 0-1`、`// 8-39`）
- 不添加功能说明类注释（如「这里是阴影」），除非用户要求
- 可注明「纹理采样得到的向量分量用 .rgba 表示」等约定

## 参考

- 项目内示例：`src/engine/unity/shader/gbuffer-pixel-reconstructed.hlsl`（直译 + RGBToHSV/HSVToRGB + .rgba）
