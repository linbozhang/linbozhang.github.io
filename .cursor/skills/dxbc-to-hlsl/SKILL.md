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

### 3. 明确是 RGBToHSV / HSVToRGB 的代码用函数表示

- 若某段汇编明显是在做 **RGB→HSV** 或 **HSV→RGB**（排序、chroma、hue、六段重建等），在 HLSL 中直接用 **`RGBToHSV`**、**`HSVToRGB`** 等函数表示，不必保留一长段内联实现，便于阅读

### 4. 明确是 Reoriented Normal Mapping（RNM）的代码用 BlendNormalRNM 表示

- 若汇编出现以下模式，对应 **Reoriented Normal Mapping**，应使用 **`BlendNormalRNM(n1, n2)`** 并对外部结果做 **normalize**：
  - 已有两个已解包、归一化或可用的切线空间法线 n1、n2（例如分别来自两张 normal map 采样）；
  - 随后：`t = n1 + (0, 0, 1)`；`u = n2 * (-1, -1, 1)`；`r = (t / t.z) * dot(t, u) - u`；最后对 `r` 做 normalize 写入目标。
- 直译时用：`result = normalize(BlendNormalRNM(n1, n2));`，其中 n1、n2 为上述两个法线（传入时**不要**先加 (0,0,1) 或乘 (-1,-1,1)，BlendNormalRNM 内部会做）。
- 实现从 **lib/CommonMaterial.hlsl** 的 `BlendNormalRNM` 复制即可（可把 `real3` 改为 `float3`）。

## 可用辅助函数

直译时如需 RGBToHSV、HSVToRGB、UnpackNormal 等Unity SRP Core的基础库函数，从本 Skill 的 **lib/*.hlsl** 中复制对应实现到生成的 HLSL 中（放在 PS 或主函数之前即可）。函数较多时可拆成多个文件放在 `lib/` 下（如 `lib/common.hlsl`、`lib/unpack.hlsl`），按需复制。

- **lib/common.hlsl**：当前包含 `RGBToHSV`、`HSVToRGB`；可继续追加其它常用直译辅助函数。
- **lib/CommonMaterial.hlsl**：包含 `BlendNormalRNM`（Reoriented Normal Mapping），对应汇编中「t=n1+(0,0,1), u=n2*(-1,-1,1), r=(t/t.z)*dot(t,u)-u, normalize(r)」的 68-75 类模式。

## 输出形式

- 按汇编指令区间加简短行号注释（如 `// 0-1`、`// 8-39`）
- 不添加功能说明类注释（如「这里是阴影」），除非用户要求
- 可注明「纹理采样得到的向量分量用 .rgba 表示」等约定

## 参考

- 项目内示例：`src/engine/unity/shader/gbuffer-pixel-reconstructed.hlsl`（直译 + RGBToHSV/HSVToRGB + .rgba）
