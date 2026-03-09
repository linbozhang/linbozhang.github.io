# 细节决定成败：id Tech 6 (THE DEVIL IS IN THE DETAILS · IDTECH 666)

**SIGGRAPH 2016 · Render the Possibilities**

- **Tiago Sousa** — Lead Renderer Programmer  
- **Jean Geffroy** — Senior Engine Programmer  

Bethesda · id Software（DOOM 所用引擎）

---

## 第 1 页 · 标题页

主标题：**THE DEVIL IS IN THE DETAILS**（细节决定成败）；副标题：**IDTECH 666**（即 id Tech 6）。背景为 DOOM 风格：上半星空、下半地狱火焰与烟雾，中央为半透明 DOOM 标志。

![第1页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0001.jpg)

---

## 第 2 页 · 初始需求 (Initial Requirements)

**要点**：**性能**：1080p @ 60 Hz；**加速美术工作流**；**多平台可扩展性**；**KISS**（保持简单）— 极简代码，无着色器排列噩梦（约 100 个 shader、约 350 个管线状态）；**下一代视觉效果** — HDR、PBR，动态且统一的光照/阴影/反射，良好抗锯齿与 VFX。右侧为 DOOM 游戏宣传图。

![第2页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0002.jpg)

---

## 第 3 页 · 单帧解剖 (Anatomy of a Frame)

| 阶段 Frame | 成本 Cost |
|------------|-----------|
| Shadow Caching | ~3.0 ms |
| Pre-Z | ~0.5 ms |
| Opaque Forward Passes | ~6.5 ms（Prepare cluster data；Textures composite, compute lighting；Output: L-Buffer, thin G-Buffer, feedback UAV） |
| Deferred Passes | ~2.0 ms（Reflections, AO, fog, final composite） |
| Transparency | ~1.5 ms（Particles light caching, particles/VFX, glass） |
| Post-Process (Async) | ~2.5 ms |

![第3页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0003.jpg)

---

## 第 4 页 · 光照与着色的数据结构 (Data Structure for Lighting & Shading)

**来源**：由 [Olson12] Clustered Deferred and Forward Shading、[Person13] Practical Clustered Shading 衍生。  
**Just works™**：透明表面、无需额外 pass 或工作、与深度缓冲无关、在深度突变处无假阳性；更多「Just Works™」见后续幻灯片。  
右侧示意图：室内柱廊与拱门，紫色/蓝色体积光呈**离散化块状/簇状**锥形，对应聚类光照的空间划分（Olson12）。

![第4页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0004.jpg)

---

## 第 5 页 · 准备集群结构 (Preparing Clustered Structure)

**视锥体形体素化/光栅化**：在 CPU 上完成，每深度切片一个任务。  
**对数深度分布**：扩展近/远平面；\( \text{ZSlice} = \text{Nearz} \times (\text{Farz}/\text{Nearz})^{\text{slice}/\text{num\_slices}} \)。  
**体素化每个项**：项可以是光源、环境探针 (environment probe) 或贴花 (decal)；形状为 OBB 或视锥体 (projector)；光栅化受屏幕空间 minxy/maxxy 与深度边界限制。  
右侧：游戏场景叠加红色网格（深度切片）与蓝色半透明视锥/射线（光源/探针等项的体素化）。

![第5页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0005.jpg)

---

## 第 6 页 · 准备集群结构（细化与伪代码）

**裁剪空间 (clip space) 中细化**：裁剪空间中一个 cell 即一个 AABB；N 个平面与 cell AABB 求交；OBB 为 6 个平面、视锥体为 5 个平面；所有体积共用同一套代码；SIMD。  
伪代码（每深度切片一任务，若有项）：

```text
for (y = MinY; y < MaxY; ++y)
  for (x = MinX; x < MaxX; ++x) {
    intersects = N planes vs cell AABB
    if (intersects) Register item
  }
```

右侧：工业/科幻室内场景 + 红色网格与蓝色视锥/射线调试可视化。

![第6页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0006.jpg)

---

## 第 7 页 · 准备集群结构（数据结构与分辨率）

**结构**：**Offset list** — 64 bit × GridDimX × GridDimY × GridDimZ；**Item list** — 32 bit × 256 × 最坏情况 (GridDimX × Avg GridDimY × GridDimZ)。  
**Offset list 每元素**：指向 item list 的偏移 + 光源/贴花/探针计数。  
**Item list 每元素**：12 bit 光源列表索引、12 bit 贴花列表索引、8 bit 探针列表索引。  
**网格分辨率**：较低，16×8×24。**假阳性**：early out 缓解 + item list 读取在 GCN 上较均匀。

![第7页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0007.jpg)

---

## 第 8 页 · 准备集群结构（热点示例）

游戏内第一人称场景：工业/地狱风场景，右下为玩家武器与 HUD。  
**热点 (Hotspot)** 标注：约 **300 个光源**、约 **1.2k 贴花**，说明集群结构在极端密度下的应用。

![第8页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0008.jpg)

---

## 第 9 页 · 准备集群结构（光照 overdraw 调试）

**Lighting Debug View: Lighting overdraw**  
- **红**：超过 10 个体积重叠 — 建议减小（如体积半径、视距）。  
- **绿**：约 5 个体积 — 需留意。  
- **蓝**：良好。  
图中热点处再次标注约 300 光源、约 1.2k 贴花；红/绿/青色彩分布表示体积重叠复杂度。

![第9页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0009.jpg)

---

## 第 10 页 · 刻画世界 (Detailing the World)

**Virtual-Texturing [10] 更新**；**Albedo, Specular, Smoothness, Normals, HDR Lightmap** — 硬件 sRGB 支持；将 Baked Toksvig [11–14] 烘焙进 smoothness 以做高光抗锯齿。**Feedback buffer UAV** 直接输出到最终分辨率；**Async compute transcoding**（成本可忽略）。**设计缺陷仍存在**：如 Reactive texture streaming 导致贴图弹出 (texture popping)。  
右侧：游戏截图 + 虚拟纹理/瓦片调试网格；下方五张图为 Albedo/Specular/Smoothness/Normals/HDR Lightmap 等 pass。

![第10页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0010.jpg)

---

## 第 11 页

（本页内容见下图。）

![第11页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0011.jpg)

---

## 第 12 页

（本页内容见下图。）

![第12页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0012.jpg)

---

## 第 13 页

（本页内容见下图。）

![第13页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0013.jpg)

---

## 第 14 页

（本页内容见下图。）

![第14页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0014.jpg)

---

## 第 15 页

（本页内容见下图。）

![第15页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0015.jpg)

---

## 第 16 页

（本页内容见下图。）

![第16页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0016.jpg)

---

## 第 17 页

（本页内容见下图。）

![第17页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0017.jpg)

---

## 第 18 页

（本页内容见下图。）

![第18页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0018.jpg)

---

## 第 19 页

（本页内容见下图。）

![第19页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0019.jpg)

---

## 第 20 页

（本页内容见下图。）

![第20页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0020.jpg)

---

## 第 21 页

（本页内容见下图。）

![第21页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0021.jpg)

---

## 第 22 页

（本页内容见下图。）

![第22页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0022.jpg)

---

## 第 23 页

（本页内容见下图。）

![第23页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0023.jpg)

---

## 第 24 页

（本页内容见下图。）

![第24页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0024.jpg)

---

## 第 25 页

（本页内容见下图。）

![第25页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0025.jpg)

---

## 第 26 页

（本页内容见下图。）

![第26页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0026.jpg)

---

## 第 27 页

（本页内容见下图。）

![第27页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0027.jpg)

---

## 第 28 页

（本页内容见下图。）

![第28页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0028.jpg)

---

## 第 29 页

（本页内容见下图。）

![第29页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0029.jpg)

---

## 第 30 页

（本页内容见下图。）

![第30页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0030.jpg)

---

## 第 31 页

（本页内容见下图。）

![第31页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0031.jpg)

---

## 第 32 页

（本页内容见下图。）

![第32页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0032.jpg)

---

## 第 33 页

（本页内容见下图。）

![第33页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0033.jpg)

---

## 第 34 页

（本页内容见下图。）

![第34页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0034.jpg)

---

## 第 35 页

（本页内容见下图。）

![第35页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0035.jpg)

---

## 第 36 页

（本页内容见下图。）

![第36页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0036.jpg)

---

## 第 37 页

（本页内容见下图。）

![第37页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0037.jpg)

---

## 第 38 页

（本页内容见下图。）

![第38页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0038.jpg)

---

## 第 39 页

（本页内容见下图。）

![第39页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0039.jpg)

---

## 第 40 页

（本页内容见下图。）

![第40页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0040.jpg)

---

## 第 41 页

（本页内容见下图。）

![第41页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0041.jpg)

---

## 第 42 页

（本页内容见下图。）

![第42页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0042.jpg)

---

## 第 43 页

（本页内容见下图。）

![第43页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0043.jpg)

---

## 第 44 页

（本页内容见下图。）

![第44页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0044.jpg)

---

## 第 45 页

（本页内容见下图。）

![第45页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0045.jpg)

---

## 第 46 页

（本页内容见下图。）

![第46页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0046.jpg)

---

## 第 47 页

（本页内容见下图。）

![第47页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0047.jpg)

---

## 第 48 页

（本页内容见下图。）

![第48页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0048.jpg)

---

## 第 49 页

（本页内容见下图。）

![第49页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0049.jpg)

---

## 第 50 页

（本页内容见下图。）

![第50页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0050.jpg)

---

## 第 51 页

（本页内容见下图。）

![第51页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0051.jpg)

---

## 第 52 页

（本页内容见下图。）

![第52页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0052.jpg)

---

## 第 53 页

（本页内容见下图。）

![第53页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0053.jpg)

---

## 第 54 页

（本页内容见下图。）

![第54页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0054.jpg)

---

## 第 55 页

（本页内容见下图。）

![第55页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0055.jpg)

---

## 第 56 页

（本页内容见下图。）

![第56页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0056.jpg)

---

## 第 57 页

（本页内容见下图。）

![第57页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0057.jpg)

---

## 第 58 页

（本页内容见下图。）

![第58页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0058.jpg)
