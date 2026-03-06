# Bart Wronski 体积雾：Siggraph 2014 与 C# 框架博文整理

本文档整理自 Bart Wronski 的 Siggraph 2014 体积雾演讲资料及其配套博客与评论，按 translate-graphicbook 约定：术语保留英文括号、代码与链接不译、原文不清处用注释标出。

---

## 一、原始资料链接

- **Siggraph 2014 演讲 PDF（幻灯片）**  
  <https://bartwronski.com/wp-content/uploads/2014/08/bwronski_volumetric_fog_siggraph2014.pdf>  
  > 说明：PDF 内容未在本文档中逐页提取，完整算法与图示请直接查阅上述链接。

- **博客：C#/.NET 图形框架更新与体积雾示例代码**  
  <https://bartwronski.com/2014/08/20/major-c-net-graphics-framework-update-volumetric-fog-code/>  
  代码仓库：<https://github.com/>（博客中称 “all code available on GitHub”，具体 repo 以博客正文及作者页面为准）。

---

## 二、Siggraph 2014 体积雾技术要点（据公开资料与博客归纳）

- **思路**：在视锥内用**视锥对齐的 3D 纹理**（froxel）存体积属性，多 Pass 在 GPU 上完成：初始化体积 → 光照注入 (Light Injection) → 散射 (Scattering) → 沿视线积分 (Integration)。
- **博客中的定位**：博文附带的体积雾代码是**为演讲写的演示用 demo**，并非实际发货游戏使用的实现；发货版有 NDA 及主机相关优化，代码质量上作者自述“并非完美”，适合作为原型和迭代参考。
- **与业界关系**：该方案被多款引擎借鉴，如 Frostbite（Sebastien Hillaire）、育碧 Scimitar、Far Cry: Primal、Unity（Robert Cupisz 移植）、近期 Call of Duty、Eidos Montreal 等均有类似实现；UE 是否内置需向 Epic 确认。

---

## 三、博客正文整理（中文）

### 标题与背景

- **标题**：Major C#/.NET graphics framework update + volumetric fog code!（C#/.NET 图形框架大更新与体积雾代码）
- **目标**：框架仍以**快速迭代、原型试验**为主，而非追求极致美观或性能；迭代时间接近 0 的“游乐场”式用法。

### 与体积雾相关的更新

1. **体积雾示例**  
   作为 Siggraph 演讲的配套示例，演示视锥 3D 纹理体积雾管线；代码为快速写成的 demo，质量上未做打磨，且非发货用版本。

2. **“全局” Shader 定义从代码可见**  
   在 shader 里把常量标成 “GlobalDefine”，可在 C# 侧通过反射读取，避免重复写死分辨率等参数。  
   示例（原文代码，不译）：
   ```hlsl
   // shader side
   #define GI_VOLUME_RESOLUTION_X 64.0 // GlobalDefine
   ```
   ```csharp
   // C# side
   m_VolumeSizeX = (int)ShaderManager.GetUIntShaderDefine("GI_VOLUME_RESOLUTION_X");
   ```

3. **导数图 (Derivative maps)**  
   参考 Rory Driscoll 的旧文；框架中未做 mesh 预处理切线架，用**法线贴图近似导数图**，在 demo 场景下足够。

4. **“改进” Perlin 噪声纹理与生成**  
   基于 GPU Pro 中 Simon Green 的现代表述实现，用于体积雾的**程序化、动画化**效果（如飘动、密度变化）。

5. **基础 BRDF**  
   GGX 高光参考 John Hable 的优化博文实现；光照相关代码当时较乱，作者计划后续整理。

### 其他改动摘要

- UI 清理与 constant buffer / shader 重载后的动态重建。
- 常量与命名清理、structured buffer 修正。
- 简单几何算法、context 操作（blend state、depth state 等）、constant buffer 反射支持整数。
- 另一种时间性抗锯齿（accumulation 类，略有拖尾），后续拟参考 Epic UE4 AA 演讲改进。
- 基于 time-delta 的相机移动、FPS 限制（避免 GPU 过载）。
- LUA constant buffer 脚本、基于 vertex shader 与 GPU buffer 的简单“粒子”渲染、动画点光源。
- 来自 Black Ops 2 Dimitar Lazarov 的简单环境 BRDF 近似。

### 计划中的工作（当时）

- 重写后处理、色调映射等。
- GPU 调试支持。
- 改进时间性技术。
- 简单屏幕空间反射 (screen-space reflections) 与环境立方体贴图。
- 正确的面光源 (area light) 支持（与体积雾结合效果佳）。
- 局部光源阴影。

---

## 四、评论与问答摘录（中文整理）

以下为博客评论区与体积雾/图形框架相关的代表性问答，已压缩与翻译，链接保持原样。

- **仅输出 SSAO 结果**  
  有读者希望只看到 SSAO 输出。作者建议：临时把最终 resolve 的 `source = currentFrameMainBuffer` 改为 `source = ssaoRT` 做调试；或使用 [RenderDoc](https://github.com/baldurk/renderdoc)。后续会做正式 debug 模式（当时 ETA 1–3 周）。

- **SAO 在 DX9 上的移植（深度、法线、bias）**  
  有读者在用注入方式给 DX9 游戏加 SSAO，无法拿到游戏原始矩阵。作者指出：法线应在算法使用的空间（如相机空间）下正确，若“偏蓝”或边缘 Z 分量不对，多半是重建或传入矩阵有误。  
  关于 SSAO 过暗：多为 **self-occlusion**，需用 **bias** 忽略小深度差（如 Scalable AO 中的 `static const float bias = 0.02f`）。  
  多边形感来自深度缓冲与面法线，难以完全消除；第二种伪影多为 ringing/欠采样或 Z 重建问题。Mipmap 在 SAO 里主要是性能优化，会加重伪影而非消除；若只有相机运动、无 motion vectors，时间性超采样容易产生明显 ghosting。

- **体积雾中 Perlin 效果不明显**  
  作者说明：demo 里 Perlin 故意调得较 subtle，更像雾而非浓烟；若要更强效果，可手动改 shader 文件 `volumetric_fog.fx` 并加大相关参数。

- **UE4 是否有体积雾**  
  作者表示不清楚 UE 情况，建议问 Epic；并列举已采用类似技术的引擎与游戏（见第二节），说明业界已普遍使用。

- **10-bit 渲染目标与色调映射**  
  读者想在 HDR 管线末端输出 10-bit 以配合 10-bit 显示器。作者表示在 Windows 上无经验（仅在 PS4 做过），建议查 Nvidia 的 HDR 显示开发文档与示例：<https://developer.nvidia.com/high-dynamic-range-display-development>。

---

## 五、与本站体积雾文档的关系

- 实现思路与管线阶段（视锥 3D 纹理、初始化 → 光照注入 → 散射 → 积分）与 [体积雾（视锥 3D 纹理）](fog.md) 中的描述一致，可对照阅读。
- 若在 Unity 中实现，可结合 fog.md 的通道布局、分辨率与参考链接，再以本博文中的“demo 定位”和评论中的实践注意点（bias、法线空间、temporal 与 motion 等）做调优。

---

*本文档为对 Bart Wronski 博客与评论的整理与翻译，非官方译本；技术细节以原 PDF 与博客为准。*
