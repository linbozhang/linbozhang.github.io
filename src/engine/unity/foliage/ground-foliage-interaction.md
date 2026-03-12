# 人与地面落叶/植被交互动画 — 技术方案整理

本文整理**角色与地面落叶、碎屑、低矮植被**（草、落叶层等）交互动画的技术实现思路，重点包括：**流体模拟 + 风场** 驱动落叶与植被、以及**其他常见方案**（RT 压痕、距离位移、物理/拟真模拟等），便于在 Unity 或其它引擎中选型与落地。

---

## 1. 使用流体模拟 + 风场的方案

### 1.1 思路概述

用** 3D 风场/流体模拟**驱动场景中的风矢量，再让**地面落叶、草、低矮植被**根据风场采样结果做摆动、飘散或沉降，角色动作（挥击、冲刺、技能）可**影响风场**，从而间接驱动落叶与植被，形成“人—风—落叶”的连贯反馈。

- **优点**：风向与强度在空间上一致、可随角色与事件变化，适合大范围、多物体协同表现。  
- **常见形态**：风场在 GPU 上以体纹理或网格存储并更新；植被/落叶在顶点 Shader 中采样风场做位移或旋转。

### 1.2 风场/流体模拟

- **全 3D 流体风场（God of War）**  
  Santa Monica 在 GDC 分享的 [Interactive Wind and Vegetation in 'God of War'](https://www.gdcvault.com/play/1026036/Interactive-Wind-and-Vegetation-in) 与 [Wind Simulation in 'God of War'](https://www.gdcvault.com/play/1026404/Wind-Simulation-in-God-of) 中，使用 **GPU 上的 3D 流体模拟** 得到空间变化的风矢量，并配合：
  - **Wind motors / receivers**：在场景中放置风源与接收体，驱动局部风场；
  - **角色碰撞与动作**：角色运动与攻击可向流体网格注入速度或力，使玩家“看到自己的动作影响风”；
  - **LOD 与碰撞**：不同精度的植被与风场采样，保证性能。

  地面植被与“踢草”（kickin' grass）效果即由该风场 + 地面植被的 sway 逻辑共同实现，落叶层若参与同一风场采样，可与草、树叶保持一致的动力学感受。

- **可控风动力学（CWD-Sim 等）**  
  [CWD-Sim: Real-Time Simulation on Grass Swaying with Controllable Wind Dynamics](https://www.mdpi.com/2076-3417/14/2/548) 针对**草场摇摆**做了分层：近处用刚度、重力等物理式变形，远处用程序化/简化模型，并支持**可变风场**（方向、强度随空间与时间变化）。思路可推广到地面落叶：落叶片在 Shader 中按世界位置采样同一风场，做平移或旋转，实现与草一致的“被风吹动”效果。

### 1.3 与地面落叶的结合方式

- **落叶作为“风场接收体”**  
  - 落叶 mesh 或粒子在顶点/实例阶段采样 **3D 风场纹理**（或 2D 平面简化），用风速、风向做顶点偏移或实例旋转；  
  - 角色影响风场后，落叶无需单独写逻辑，仅依赖同一风场即可与草、树叶同步反应。

- **沉降与“踢起”**  
  - 风场减弱或为零时，可通过简单阻尼或重力项让落叶逐渐“落回”地面；  
  - 角色脚部或技能在风场中注入向上/向外速度时，可配合局部力或噪声，让落叶产生被踢起、飘散的感觉，仍由同一套风场驱动，保持风格统一。

- **实现要点**  
  - 风场分辨率与覆盖范围需兼顾性能与观感；  
  - 落叶的采样点（如实例中心、顶点）需对应到风场 UVW；  
  - 若落叶为 GPU 实例化或粒子，需在实例/顶点 Shader 中传入世界坐标并采样风场。

### 1.4 参考资源（流体/风场 + 植被）

| 类型 | 资源 | 说明 |
|------|------|------|
| GDC | [Interactive Wind and Vegetation in 'God of War'](https://www.gdcvault.com/play/1026036/Interactive-Wind-and-Vegetation-in) | 交互式风与植被系统，含地面植被与“踢草” |
| GDC | [Wind Simulation in 'God of War'](https://www.gdcvault.com/play/1026404/Wind-Simulation-in-God-of) | 3D GPU 流体风场模拟 |
| 文章 | [80.lv - God of War Wind and Vegetation](https://80.lv/articles/santa-monica-studio-showed-how-interactive-wind-and-vegetation-were-made-for-god-of-war/) | 战神风与植被实现要点摘要 |
| 论文 | [CWD-Sim: Grass Swaying with Controllable Wind Dynamics](https://www.mdpi.com/2076-3417/14/2/548) | 可控风动力学下的草场实时模拟，思路可迁移到落叶 |

---

## 2. 其他人与地面落叶/植被交互方案

### 2.1 基于 Render Texture / 世界位置贴图的压痕

- **思路**：用一张（或多张）**RenderTexture** 表示“地面被踩压/落叶被拨开”的强度，UV 对应世界 XZ（或地形局部）。角色移动时，用脚底位置、半径、力度在 RT 上绘制圆形或脚印形状；落叶/草 Shader 用**世界坐标采样该 RT**，根据强度做顶点偏移、alpha 或法线变化，形成被踩扁、拨开的效果。
- **优点**：实现简单、可控性强、易于和地形贴花、草系统共存；适合“压痕、踩踏”类交互。
- **与落叶**：落叶层若用同一张 RT，可表现落叶被踩实或拨开；也可单独一张 RT 只驱动落叶，避免与草混用分辨率。
- **参考**：不少交互草教程（如 [gamedev.center 交互草](https://gamedev.center/tutorial-how-to-make-an-interactive-grass-shader-in-unity)、[Creating Interactive Grass with Shader Graph](https://www.youtube.com/watch?v=WRheuGiVB0I)）使用“角色位置 + 半径”或 RT 压痕；[TRAIL](https://link.springer.com/article/10.1007/s00371-024-03506-z) 等学术工作也输出图像数据以接入纹理管线。

### 2.2 基于距离的 Shader 位移（无 RT）

- **思路**：在 CPU 或 Compute 中每帧传入**角色位置（及可选速度、半径）**到 Shader；顶点 Shader 中计算到角色距离，用 `smoothstep` 等得到权重，沿“远离角色”或“被推开”方向做顶点偏移。无需 RT，适合少量角色、简单需求。
- **优点**：零额外贴图、逻辑直观；可与风场叠加（风场负责摆动，距离负责局部推开）。
- **缺点**：多角色、多脚时需要多组参数或数组；难以表达“持久压痕”，多为瞬时推开。

### 2.3 物理/拟真类：足压、植被变形、地形塑性

- **TRAIL（2024）**  
  [TRAIL: Simulating the impact of human locomotion on natural landscapes](https://link.springer.com/article/10.1007/s00371-024-03506-z) 模拟**步行对自然地表的影响**：  
  - **足压分布**：根据步态与质量计算脚跟、前掌压力；  
  - **植被变形**：可变形植被模型（弯曲、压损、恢复）；  
  - **地形塑性**：土壤压缩、堆积与稳定；  
  - 结果可输出为图像并接入纹理管线，适合需要“踩出小径、压坏植被”的写实项目。  
  - 代码：[TRAIL-Natural-Impact](https://github.com/edualvarado/TRAIL-Natural-Impact)

- **Soft Walks（2021/2022）**  
  [Soft Walks: Real-Time, Two-Ways Interaction between a Character and Loose Grounds](https://diglib.eg.org/items/ac82a7c3-a3f3-4dc7-a5c6-5ee2bb8a6c41) 做**角色与松散地面的双向交互**：地面与植被在脚接触处程序化变形，角色步态通过**逆运动学**适配变形后的地面，实现沙地、雪地、覆草坡上的连贯行走。  
  - Unity 相关实现：[unity-soft-walks](https://github.com/edualvarado/unity-soft-walks)、[unity-footprints](https://github.com/edualvarado/unity-footprints)

- **适用**：偏写实、需要足迹与植被长期变化时；实现与调参成本较高，可与简化版 RT 压痕结合（远距离用 RT，近处用物理/拟真）。

### 2.4 粒子/实例化落叶 + 力场或简单碰撞

- **思路**：落叶用 **GPU 粒子或 Instancing** 渲染，每粒子带位置、速度；用**力场**（如角色周围的径向力、风场采样）或**简单 SDF/球体碰撞**更新速度，再积分位置，实现落叶被“吹开”或“踩飞”。
- **优点**：适合明显飘起、飞散的效果；可与风场结合（风场提供主风力，角色提供局部扰动）。
- **参考**：Unity 下落叶的 GPU 实例化可参考 [WoBok/Fallen_Leaves](https://github.com/wobok/fallen_leaves)（URP + Compute + Instancing）；交互部分需自行加力场或碰撞逻辑。

### 2.5 方案对比小结

| 方案 | 典型用途 | 性能/复杂度 | 与“流体+风场”的关系 |
|------|----------|-------------|----------------------|
| 流体模拟 + 风场 | 大范围一致的风与落叶/草摆动，角色影响风 | 中高（需风场体纹理与采样） | 核心方案，落叶作为风场接收体 |
| RT / 世界位置压痕 | 踩踏、压痕、落叶被拨开 | 低中（一张或多张 RT） | 可叠加：风场管摆动，RT 管局部压痕 |
| 距离位移（无 RT） | 瞬时推开、简单交互 | 低 | 可叠加风场 |
| TRAIL / Soft Walks | 写实足迹、植被变形、地形塑性 | 高 | 可单独或与风场、RT 组合 |
| 粒子 + 力场/碰撞 | 落叶飘起、飞散 | 中 | 风场可作全局力，角色作局部力 |

---

## 3. Unity 相关资源与落地建议

### 3.1 落叶渲染与基础交互

- **[WoBok/Fallen_Leaves](https://github.com/wobok/fallen_leaves)**  
  Unity URP 下基于 **GPU Instancing + Compute Shader** 的高效落叶渲染，可作为“落叶层”基础，再在其上叠加：  
  - 风场采样（若引入 3D 风场纹理或 2D 风图）；  
  - 角色位置/RT 压痕采样，做位移或 alpha。

- **交互草/植被 Shader**  
  - [Creating Interactive Grass with Unity's Shader Graph](https://www.youtube.com/watch?v=WRheuGiVB0I)  
  - [Interactive Wind Shader for Foliage](https://www.youtube.com/watch?v=Ctbqax1XRiE)  
  - [gamedev.center - Interactive Grass Shader](https://gamedev.center/tutorial-how-to-make-an-interactive-grass-shader-in-unity)  
  上述多为“角色位置 + 半径”或 RT 压痕驱动顶点位移，落叶层可采用同一套“世界坐标 → 采样 RT/风场 → 顶点偏移”的管线。

### 3.2 拟真足迹与地表变形（Unity）

- **[edualvarado/unity-soft-walks](https://github.com/edualvarado/unity-soft-walks)** — Soft Walks 双向交互  
- **[edualvarado/unity-footprints](https://github.com/edualvarado/unity-footprints)** — 实时软地面足迹  
- **[edualvarado/TRAIL-Natural-Impact](https://github.com/edualvarado/TRAIL-Natural-Impact)** — TRAIL 自然地表影响  

可用于需要“脚印 + 植被/落叶变形”的写实向项目，再与风场或 RT 方案组合。

### 3.3 落地建议（简要）

- **以“流体 + 风场”为主时**：先实现 3D 或 2D 风场（体纹理/网格 + 简单扩散或流体步），再让草、落叶、树叶统一采样；角色通过注入速度/力影响风场，即可间接驱动地面落叶与植被。  
- **以“踩踏/压痕”为主时**：用 RT 或距离位移做局部变形，再视需求叠加风场做摆动。  
- **落叶既要有“被风吹”又要有“被踩开”**：风场负责摆动与飘动，RT（或距离）负责脚部周围的位移与压痕，两者在 Shader 中叠加。

---

## 4. 参考链接汇总

### 风场 / 流体与植被

- [GDC Vault - Interactive Wind and Vegetation in 'God of War'](https://www.gdcvault.com/play/1026036/Interactive-Wind-and-Vegetation-in)
- [GDC Vault - Wind Simulation in 'God of War'](https://www.gdcvault.com/play/1026404/Wind-Simulation-in-God-of)
- [80.lv - God of War Wind and Vegetation](https://80.lv/articles/santa-monica-studio-showed-how-interactive-wind-and-vegetation-were-made-for-god-of-war/)
- [CWD-Sim: Real-Time Simulation on Grass Swaying with Controllable Wind Dynamics (MDPI)](https://www.mdpi.com/2076-3417/14/2/548)

### 人与地表/植被拟真交互

- [TRAIL: Simulating the impact of human locomotion on natural landscapes (Springer)](https://link.springer.com/article/10.1007/s00371-024-03506-z)
- [TRAIL-Natural-Impact (GitHub)](https://github.com/edualvarado/TRAIL-Natural-Impact)
- [Soft Walks (Eurographics / diglib.eg.org)](https://diglib.eg.org/items/ac82a7c3-a3f3-4dc7-a5c6-5ee2bb8a6c41)
- [Soft Walks - Real-Time Locomotion on Soft Grounds (HAL/arXiv)](https://arxiv.org/abs/2104.10898)
- [unity-soft-walks (GitHub)](https://github.com/edualvarado/unity-soft-walks)
- [unity-footprints (GitHub)](https://github.com/edualvarado/unity-footprints)

### Unity 落叶与交互植被

- [WoBok/Fallen_Leaves - URP 落叶 GPU Instancing + Compute](https://github.com/wobok/fallen_leaves)
- [Terrain trails / foliage trampling (Aaron Neal)](https://aaronneal.online/docs/m4/terrain-trails-foliage-trampling/using-custom-foliage-with-fake-physics-effects)
- [gamedev.center - Interactive Grass Shader in Unity](https://gamedev.center/tutorial-how-to-make-an-interactive-grass-shader-in-unity)
- [Creating Interactive Grass with Unity's Shader Graph (YouTube)](https://www.youtube.com/watch?v=WRheuGiVB0I)
- [Interactive Wind Shader for Foliage (YouTube)](https://www.youtube.com/watch?v=Ctbqax1XRiE)
