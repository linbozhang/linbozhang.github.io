# Unity GPU 植被（草）典型实现

本文整理 Unity 下**基于 GPU 的草/植被渲染**的常见做法与典型实现流程，并汇总社区参考项目与文档，便于在项目中选择或实现一套 GPU 草系统。

---

## 为什么用 GPU 草

- **数量**：场景中草叶/植被往往成千上万甚至百万级，若用传统每株一个 GameObject + MeshRenderer，CPU 剔除与 Draw Call 会成为瓶颈。
- **一致性**：草的位置、朝向、风动等可完全由**地形/遮罩 + 参数**决定，适合在 **Compute Shader** 中并行生成与剔除，再由 **GPU 间接绘制** 一次提交。
- **扩展性**：配合视锥剔除、距离/遮挡剔除（含 Hi-Z）、LOD，可在保持观感的前提下显著减少实际绘制的实例数。

因此，典型方案是：**CPU 只做粗粒度管理（如地形分块）→ Compute Shader 生成/剔除可见实例并写入 GPU 缓冲 → DrawMeshInstancedIndirect / DrawProceduralIndirect 一次绘制**。

---

## 典型管线概览

```
地形/Detail Map 等数据
        ↓
[可选] CPU 粗剔除（可见 Cell / CullingGroup）
        ↓
Compute Shader：按 Cell 采样草位置与类型 → 写入实例缓冲
        ↓
Compute Shader：视锥剔除 + [可选] Hi-Z/遮挡剔除 + [可选] 距离 LOD
        ↓
可见实例写入 AppendStructuredBuffer 或 Compact 到 RWStructuredBuffer
        ↓
CopyCount 到间接参数缓冲（若用 AppendBuffer）
        ↓
Graphics.DrawMeshInstancedIndirect / DrawProceduralIndirect
        ↓
顶点/片元 Shader：按 instance 取缓冲数据，风动、光照、着色
```

---

## 核心 API 与流程

### 1. 间接绘制

- **Graphics.DrawMeshInstancedIndirect**  
  需传入 **Mesh**、**SubMesh 索引**、**Material**、**Bounds**、**ComputeBuffer 形式的间接参数**（即 `DrawArguments`：instance count、vertex count 等）。  
  GPU 从该 buffer 中读取本帧要绘制的实例数量，因此可由 Compute Shader 在 GPU 上写回实例数，实现 **GPU-Driven** 的草渲染。  
  参考：[Unity - Graphics.DrawMeshInstancedIndirect](https://docs.unity3d.com/ScriptReference/Graphics.DrawMeshInstancedIndirect.html)

- **Graphics.DrawProceduralIndirect**  
  不依赖预制 Mesh，而是按 **顶点数/图元数** 由 Shader 程序化生成几何（例如每实例 N 个顶点的一条草）。  
  同样通过间接参数 Buffer 指定实例数；实例数据来自另一 StructuredBuffer，在顶点 Shader 中用 `unity_InstanceID` 或自定义 instance 索引读取。

- **限制与注意**  
  - 普通 GPU Instancing 每批最多 1023 实例，Indirect 可突破该限制，单次调用绘制数万甚至更多实例。  
  - 若使用 **AppendStructuredBuffer** 做剔除后收集，需用 **ComputeBuffer.CopyCount** 将 AppendBuffer 的计数拷贝到间接参数 Buffer 的对应偏移，再调用上述 Draw。

### 2. Compute Shader 职责

- **实例数据生成**  
  根据地形 detail map、splatmap、或程序化噪声，在每线程中计算一株草的世界位置、朝向、类型、随机参数等，并写入 `RWStructuredBuffer<GrassInstance>` 或 **AppendStructuredBuffer**。

- **剔除**  
  - **视锥剔除**：相机视锥六面体与草包围（通常用点或小 AABB）相交测试，未通过则不写入可见列表。  
  - **距离剔除 / LOD**：按到相机距离决定是否丢弃或写入不同 LOD 档位（可配合蓝噪声等做密度渐变）。  
  - **遮挡剔除（可选）**：如基于 **Hi-Z** 的遮挡测试，只保留通过深度测试的实例，进一步减少 overdraw。  
  剔除结果通常写入 **AppendStructuredBuffer**，这样每帧可见数量动态变化，无需固定最大实例数；再通过 **CopyCount** 驱动间接绘制。

- **可选：Compact 代替 Append**  
  先对“是否可见”做 vote，再 prefix sum 得到 scatter 地址，最后把可见实例 compact 到一块连续 **RWStructuredBuffer**，可更好地控制内存布局与缓存；实现复杂度略高。

### 3. 顶点 / 片元 Shader

- **实例数据**  
  通过 `UNITY_INSTANCING_BUFFER` 或显式 `StructuredBuffer<GrassBlade>` + `unity_InstanceID` 取当前草的参数（位置、旋转、高度、弯曲、颜色等）。

- **程序化形状**  
  常见做法是用 **三次贝塞尔曲线** 定义单株草的轮廓，在顶点 Shader 中按顶点 ID 或 UV 沿曲线插值得到世界位置与法线，便于风动只作用在叶片上部、底部贴地。

- **风动**  
  使用 **Perlin/Simplex 噪声**（2D 或 3D）采样，以 `_Time` 与世界 XZ 为输入，得到随时间滚动的噪声；再根据顶点在草上的高度（如 uv.y）混合，使叶尖摆动大、叶根基本不动，形成“鞭梢”效果。  
  可与贝塞尔控制点偏移结合，实现整株草的弯曲与朝向变化。

- **光照与阴影**  
  - 光照：Phong/Blinn-Phong 或 PBR，按需求；可加 **fake AO**（如基于草叶长度的暗化）增强体积感。  
  - 阴影：接收阴影通常采样 Shadow Map；是否让草参与 Shadow Casting 视性能与美术需求而定，可对远距离草关闭 cast 以省 draw。

- **LOD / 距离**  
  - 距离渐隐：用 `smoothstep` 按距离淡化 alpha 或缩小高度，避免硬切。  
  - 远距离可将法线 lerp 向地形法线、减弱高光与 AO，减少闪烁与噪点（类似《对马岛之魂》分享的做法）。

---

## 常见实现形态对比

| 形态 | 说明 | 适用 |
|------|------|------|
| **Mesh + DrawMeshInstancedIndirect** | 预制草 Mesh，每实例只传 transform/参数，顶点阶段做风动与缩放 | 地形草、大量同模型实例 |
| **Procedural + DrawProceduralIndirect** | 无预制 Mesh，顶点由 Shader 按贝塞尔等程序化生成 | 完全程序化草、对马岛风格 |
| **Geometry Shader 草** | 在地形顶点上由 GS 生成草叶几何 | 小范围、需每三角定制时；GS 在移动端支持差 |
| **Tessellation + Geometry Shader** | 地形细分后在 GS 里生草 | 可精细控制密度与形状，性能成本高 |
| **简单 Mesh 批量** | 每株一个 Mesh，依赖 SRP Batcher/Static Batching | 草量少、需要每株独立交互时 |

更系统的六种做法对比（含 Mesh 草、几何/曲面细分、Instancing、Indirect 等）可参考：[Six Grass Rendering Techniques in Unity](https://danielilett.com/2022-12-05-tut6-2-six-grass-techniques/)（含 [GitHub 示例](https://github.com/daniel-ilett/shaders-6grass)）。

---

## 进阶优化点

- **分块（Cell）**  
  将地形或世界按格子划分，先对 **Cell** 做视锥/遮挡剔除，只对可见 Cell 内的草做 Compute 采样与实例化，可显著降低 VRAM 与 Compute 消耗。

- **蓝噪声分布**  
  草的位置用蓝噪声采样，在 LOD 减少密度时取子集仍能保持视觉上均匀、不扎堆，避免规则感。

- **Voronoi 簇（Clump）**  
  将草按 Voronoi 单元分组，每组共享一套参数（高度、弯曲、颜色等），可做出“一丛一丛”的自然分布，参考 [Unity-Grass](https://cainrademan.github.io/Unity-Grass/)。

- **交互**  
  角色/物体对草的影响可写入一张 **RenderTexture**（如世界 XZ 为 UV、压痕强度为 R），草 Shader 用世界坐标采样该图做弯曲或压低，无需每株做物理。

- **Alpha 与性能**  
  Alpha Test（clip）对移动端负担较大；若可接受，用 **Alpha Blend + 距离渐隐** 或 **dither** 代替硬 clip 有时能明显提升帧率。

---

## 参考实现与文档

### 开源项目（GitHub）

| 项目 | 说明 |
|------|------|
| [EricHu33/UnityGrassIndirectRenderingExample](https://github.com/EricHu33/UnityGrassIndirectRenderingExample) | 地形草 + **DrawMeshInstancedIndirect** + Compute；Hi-Z 遮挡剔除、地形 detail 采样、多草类型、交互 RT；含 Shader Graph 兼容 Indirect 的用法。 |
| [z4gon/grass-compute-shader-unity](https://github.com/z4gon/grass-compute-shader-unity) | Compute Shader 程序化草，风动与剔除。 |
| [MangoButtermilch/Unity-Grass-Instancer](https://github.com/MangoButtermilch/Unity-Grass-Instancer) | 多种 GPU 实例化草方案对比，含视锥/遮挡剔除与 LOD。 |
| [ellioman/Indirect-Rendering-With-Compute-Shaders](https://github.com/ellioman/Indirect-Rendering-With-Compute-Shaders) | 通用 Indirect 绘制 + Compute 视锥/遮挡剔除 + LOD，可与草管线结合。 |
| [cainrademan/Unity-Grass](https://github.com/cainrademan/Unity-Grass)（[说明页](https://cainrademan.github.io/Unity-Grass/)） | 对马岛风格程序化草：**DrawProceduralIndirect**、贝塞尔叶片、Voronoi 簇、风动、距离剔除；实现思路与 GDC 分享一致。 |
| [naming1086/UnityGrassShader](https://github.com/naming1086/UnityGrassShader) | URP 草 Shader：曲面细分、地形绘制、阴影、风与位移。 |
| [ColinLeung-NiloCat/UnityURP-MobileDrawMeshInstancedIndirectExample](https://github.com/ColinLeung-NiloCat/UnityURP-MobileDrawMeshInstancedIndirectExample) | 移动端 URP DrawMeshInstancedIndirect 入门示例。 |

### 视频与演讲

- [Procedural Grass in 'Ghost of Tsushima'](https://www.youtube.com/watch?v=Ibe1JBF5i5Y)（GDC）— 对马岛程序化草管线的主要参考。
- [モバイル向け大量描画テクニック](https://www.youtube.com/watch?v=mmxpPDVskg0) — 大量实例绘制与 Indirect 思路。
- [Acerola - How Do Games Render So Much Grass?](https://www.youtube.com/watch?v=Y0Ko0kvwfgA) — 草渲染思路概览。

### Unity 官方与社区

- [Graphics.DrawMeshInstancedIndirect](https://docs.unity3d.com/ScriptReference/Graphics.DrawMeshInstancedIndirect.html)
- [CullingGroup API](https://docs.unity3d.com/Manual/CullingGroupAPI.html)（CPU 侧球形/包围剔除，可与 Cell 结合）
- [Cyanilux - GrassInstanced.hlsl](https://gist.github.com/Cyanilux/4046e7bf3725b8f64761bf6cf54a16eb) — 实例化草 Shader 片段
- Shader Graph 与 **InstanceIndirect** 兼容：见 [论坛讨论](https://forum.unity.com/threads/hd-render-pipeline-and-instancedindirect.523105/) 与 [Cyanilux 推文](https://twitter.com/Cyanilux/status/1396848736022802435)

---

## 小结

- **典型 GPU 草管线**：地形/遮罩 → CPU 可见块粗剔 → Compute 生成实例并做视锥/距离/可选 Hi-Z 剔除 → Append 或 Compact 到实例缓冲 → **DrawMeshInstancedIndirect** 或 **DrawProceduralIndirect** → 顶点 Shader 中贝塞尔 + 风动 + 实例参数，片元中光照与阴影。
- **选型**：需要最大可控性与对马岛风格时，倾向 **DrawProceduralIndirect + 贝塞尔 + Voronoi 簇**；需要快速落地、多草型与地形集成时，倾向 **DrawMeshInstancedIndirect + 预制 Mesh + Detail Map**。
- 上述参考项目与文档覆盖从入门到带 Hi-Z、LOD、交互的完整实现，可按项目需求选取并组合使用。
