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

## 第 11 页 · 刻画世界：贴花系统 (Detailing the World – Decals)

**贴花与几何光栅化一体**；**实时替代 Mega-Texture「盖章」**——更快工作流、更少磁盘占用。  
**Just Works™**：法线贴图混合、全通道线性正确混合、Mipmapping/各向异性*、透明、排序、**0 drawcall**。  
**8k×8k 贴花图集**，**BC7** 压缩。右侧为 Decal Atlas 示意图：大量小块贴花（含蓝紫色法线）打包进图集。

![第11页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0011.jpg)

---

## 第 12 页 · 刻画世界：盒投影 (Box Projected)

**e₀, e₁, e₂** 为 OBB 归一化半轴，**p** 为位置。  
**MdecalProj = Mscale · Mdecal⁻¹**；Mscale 为 0.5/sizeX(Y,Z) 与 0.5 平移；Mdecal 由 e₀,e₁,e₂ 与 p 构成 4×4 矩阵。  
**贴花图集索引**：每贴花有 scale & bias；例：`tex2Dgrad(decalsAtlas, uv.xy * scaleBias.xy + scaleBias.zw, uvDDX, uvDDY)`。  
右图：OBB 线框与 p、e₀(红)、e₁(蓝)、e₂(绿) 示意。

![第12页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0012.jpg)

---

## 第 13 页 · 刻画世界：放置与限制 (Detailing the World)

**由美术手动放置**（含混合设置）；可视为「混合层 Blend Layers」的推广。  
**每视锥限 4k**（通常可见约 1k 或更少）。  
**LOD**：美术设最大视距；玩家画质设置也影响视距。  
**适用于动态、非变形几何**：对贴花应用物体变换。  
右侧：灰球体等 3D 资源示例。

![第13页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0013.jpg)

---

## 第 14 页 · 刻画世界（场景示例）

第一人称视角：工业/科幻室内、黄褐金属墙与污渍、管道、地面反光与血泊、左侧屏幕与圆柱结构、右侧大窗望向外景、玩家武器与 HUD。展示**刻画世界**的视觉保真度与氛围。

![第14页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0014.jpg)

---

## 第 15 页 · 刻画世界（场景示例）

第一人称：灰黄走廊、地面血泊与残骸、左侧红色警告屏与发光圆柱机械、右侧大窗与橙光、武器与 HUD。强调**环境叙事**与**细节**（血迹、磨损纹理）。

![第15页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0015.jpg)

---

## 第 16 页 · 刻画世界：IdStudio MegaTexture 编辑器

**IdStudio - Megatexture** 界面：左侧 Folders/materials、Stamp 菜单与参数（Depth, Scale, Scatter, Angle, Rotation, Blend Mode, Normal Blending 等）；主视口为地形/表面；**MegaEditor Decal** 窗口（PBR：opacity 是否影响 albedo）；World Camera 与 Console。底部：Engine/surface01.mtf。展示**贴花与材质**在 megatexture 上的编辑流程。

![第16页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0016.jpg)

---

## 第 17 页 · 刻画世界：地形贴花编辑

中央视口：橙褐色荒漠/火星风地形与白色线框立方体；左侧 Folders 与 flat_sand、rubble_rock、sharp_sand 等材质缩略图；Stamp/Tools 菜单与 Depth、Scale、Angle、Normal Blending 等；Console 显示 Channel: Albedo 等。底部 Brushes/Entities、decal/ground/foot_tracks_01。展示**地表贴花与细节**的编辑。

![第17页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0017.jpg)

---

## 第 18 页 · 刻画世界：血迹贴花 (blood_splats)

主视口：金属地面与大面积血迹、蓝色/白色高光。左侧 Asset Browser：wet_sand_wip、rubble_rock、blood_splat_01–05、blood_stains、blood_runes 等；当前选中 blood_splat_03。megatexture_maps/surface1 路径。展示**血迹与环境贴花**在引擎中的选用与效果。

![第18页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0018.jpg)

---

## 第 19 页 · 刻画世界（战斗场景）

第一人称：多管武器、弹药 350、左侧脏窗与绿色反光、右侧门道大量血迹与准星、远处楼梯与橙光管道。生命/护甲 107、三角警告图标。展示**贴花（血迹）、反射、光照与武器模型**的高保真表现。

![第19页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0019.jpg)

---

## 第 20 页 · 光照 (Lighting)

**单一/统一光照代码路径**：用于不透明 pass、延迟、透明与解耦粒子光照（见幻灯片 23–27）。  
**无 shader 排列噩梦**：静态/相干分支已足够好用；静态几何共用同一 shader；更少 context switch。  
**组成**：**漫反射间接**——静态用 lightmap、动态用 irradiance volumes；**高光间接**——反射（环境探针、SSR、高光遮蔽）；**动态**——光源与阴影。

![第20页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0020.jpg)

---

## 第 21 页 · 光照：ComputeLighting 伪代码

```text
ComputeLighting(inputs, outputs) {
  Read & Pack base textures
  for each decal in cell {
    early out fragment check
    Read textures
    Blend results
  }
  for each light in cell {
    early out fragment check
    Compute BRDF / Apply Shadows
    Accumulate lighting
  }
}
```

按 cell 遍历贴花与光源；先贴花混合再光照与阴影累积。

![第21页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0021.jpg)

---

## 第 22 页 · 光照：阴影缓存与 Atlas

**阴影缓存/打包进 Atlas**：PC 8k×8k（高规格）、32 bit；主机 8k×4k、16 bit。  
**依距离可变分辨率**；**时间切片也依距离**。**静态几何用优化 mesh**。  
**光源不动？** 缓存静态几何阴影图；视锥内无更新则直接沿用；有更新则用动态几何与缓存结果合成；仍可做动画（如闪烁）。  
**美术设置/画质影响以上全部**。右侧：Shadow Atlas 示意图（多块阴影图打包）。

![第22页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0022.jpg)

---

## 第 23 页 · 光照：阴影索引与 PCF

**索引到阴影视锥投影矩阵**。**所有光源类型共用同一 PCF 查找代码**——更低 VGPR 压力。  
**含定向光级联**：级联间用 dither；单次级联查找。  
**尝试过 VSM 及变体**——均有若干伪影；概念上对 Forward 有潜力（如将滤波频率与光栅化解耦）。  
右侧：Shadow Atlas 网格示意图。

![第23页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0023.jpg)

---

## 第 24 页 · 光照：第一人称手臂自阴影 (First person arms self-shadows)

**第一人称手臂自阴影**：用 Atlas 的专用区域；**主机上关闭以节省 atlas 空间**。  
左右对比图：左图自阴影开启（武器与手臂缝隙、背光处正确变暗）；右图关闭（**漏光** light leaking，本应阴影处过亮、偏平）。

![第24页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0024.jpg)

---

## 第 25 页 · 光照：VGPR 压力与平台建议

**留意 VGPR 压力**：长生命周期数据打包（如 HDR 颜色 float4 ↔ RGBE 编码的 uint）；缩短寄存器生命周期；减少嵌套循环/最坏路径；减少分支。主机（PS4）约 **56 VGPR**；PC 上因编译器效率更高、浪费性能。**未来：半精度支持会有帮助**。  
**Nvidia**：用 UBO/Constant Buffer（需分区 = 更多/难看代码）。**AMD**：优先 SSBO/UAV。

![第25页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0025.jpg)

---

## 第 26 页 · 透明 (Transparents)

**粗糙玻璃近似**：顶 mip 为半分辨率、共 4 级 mip；高斯核（近似 GGX lobe）；按表面 smoothness 混合 mip；折射传递每帧限 2 次以保性能。**表面参数化/变化**通过贴花。  
下图「Glass Roughness Variation」：四张不同粗糙度玻璃的折射对比；右侧大图为带冷凝/水雾的透明面板。

![第26页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0026.jpg)

---

## 第 27 页 · 粒子光照 (Particle Lighting)

**Per-vertex？** 无更高频细节（如阴影）。**Per-vertex + tessellation** [Jansen11]：需大细分级别，对 GCN/主机不友好。**Per-pixel？** 像素量多、成本高。**混合分辨率渲染？** [Nguyen04] 排序有问题；MSAA target 锯齿与平台相关。  
右图：Per Vertex（粗网格）、Tessellation（细网格）、Per-Pixel（放大像素块）对比。

![第27页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0027.jpg)

---

## 第 28 页 · 解耦粒子光照 (Decoupled Particle Lighting)

**观察**：粒子多为低频/低分辨率；可每粒子渲染一个 quad 并缓存光照结果。  
**将光照频率与屏幕分辨率解耦 = 收益**：光照性能与屏幕分辨率无关；依屏幕大小/距离的自适应分辨率启发（如 32×32、16×16、8×8）。**与主光照完全相同的代码路径**；**最终粒子仍为全分辨率**，用双三次核读取光照结果。  
右图：Adaptive resolution 示意。

![第28页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0028.jpg)

---

## 第 29 页 · 粒子光照管线

本页为粒子光照管线流程图：从粒子系统到光照缓存、再到最终全分辨率合成，见下图。

![第29页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0029.jpg)

---

## 第 30 页 · 粒子光照 Atlas (4k×4k)

**Particle Light Atlas**：4k×4k RGBA16F；每粒子一个 quad；**与主光照完全相同的代码路径**（ComputeLighting、阴影、贴花等）；双三次采样；**无 LOD**（粒子本身已 LOD）。  
右图：Particle Light Atlas 示意（网格状光照块）。

![第30页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0030.jpg)

---

## 第 31 页 · 粒子光照结果

本页为粒子光照效果对比或示例图（解耦光照前后/不同分辨率），见下图。

![第31页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0031.jpg)

---

## 第 32 页 · 后处理 (Post-Process)

**后处理管线**：TAA、Bloom、DOF、Motion Blur、Color Grading、LUT、Film Grain 等；与体积光/雾、反射等集成。本页为后处理流程图或效果示意，见下图。

![第32页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0032.jpg)

---

## 第 33 页 · 优化数据获取 (GCN)

**Optimizing Data Fetching (GCN)**：**GCN 标量单元**用于非发散操作；**利于加速数据获取**（节省 VGPR、coherent 分支、更少指令：SMEM 64 B、VMEM 16 B）。**簇状着色用例**：每像素从其所属 cell 获取光源/贴花；虽天然发散，仍值得分析。见下图。

![第33页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0033.jpg)

---

## 第 34 页 · 簇光照访问模式（场景示意）

**Clustered Lighting Access Patterns**：本页为工业/科幻室内场景截图，展示多光源、金属反射与黄黑警示结构的复杂光照与阴影，对应簇状光照在实际场景中的表现。见下图。

![第34页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0034.jpg)

---

## 第 35 页 · 簇光照访问模式 (Clustered Lighting Access Patterns)

**访问模式**：按簇索引光照列表；coherent 访问、cache 友好；支持大量光源。本页为簇与光源列表的访问示意图或伪代码，见下图。

![第35页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0035.jpg)

---

## 第 36 页 · 簇光照访问模式（网格与访问点）

**Clustered Lighting Access Patterns**：场景上叠加红色网格将空间划分为不规则单元格，红色点表示光照/数据访问发生的位置；用于说明簇状着色中按 cell 组织与访问光照数据的方式。见下图。

![第36页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0036.jpg)

---

## 第 37 页 · 簇光照访问模式（热力图）

**Clustered Lighting Access Patterns**：本页为数据访问热力图可视化（蓝/青/绿/黄/红表示访问强度），展示簇状光照计算时 GPU 的数据访问分布与热点。见下图。

![第37页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0037.jpg)

---

## 第 38 页 · 分析数据 (Analyzing the Data)

**要点**：大多数波前只访问一个单元格；相邻单元格共享大部分内容；线程大多获取相同数据。**每线程按单元格取数并非最优**：未利用这种数据收敛性。**可对合并后的单元格内容做标量迭代**：不要让所有线程各自独立取完全相同的数据。见下图。

![第38页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0038.jpg)

---

## 第 39 页 · 利用访问模式 (Leveraging Access Patterns)

**数据**：每单元格为光源/贴花 ID 的排序数组；光照与贴花共用同一结构；每线程可能访问不同节点、各自迭代。**标量加载 / 序列化迭代**：用 `ds_swizzle_b32` / `minInvocationsNonUniformAMD` 等在所有线程中取最小 ID；对匹配该索引的线程处理该项（统一索引 → 标量指令）；匹配的线程再移到下一索引。图：由 Divergent（各线程不同 ID 列表）转为 Serial（标量按 A/B/C/D/E 顺序处理）。见下图。

![第39页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0039.jpg)

---

## 第 40 页 · 特殊路径 / Fast path

**Special Paths**：对常见/简单情况做 fast path（如无贴花、单光源、无阴影），减少分支与 GPR 压力，提升主机与低端 PC 性能。本页为 fast path 决策树或性能对比，见下图。

![第40页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0040.jpg)

---

## 第 41 页 · 动态分辨率缩放 (Dynamic Resolution Scaling)

**根据 GPU 负载调整分辨率**：PS4 上多为 100%，Xbox 上可更激进。**同一渲染目标、调整视口大小**：有侵入性（需额外 shader 代码）；OpenGL 上为唯一选项。**未来**：主机与 Vulkan 上可对多渲染目标做别名。**TAA** 可累积不同分辨率的样本。**在异步计算中做上采样**。见下图。

![第41页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0041.jpg)

---

## 第 42 页 · 异步后处理 (Async Post Processing)

**阴影与深度 pass 几乎不用计算单元**（固定图形管线为主）；**不透明 pass 也非满负载**。**与后处理重叠**：在 GFX 队列用预乘 alpha 缓冲渲染 GUI；在计算队列做后处理/抗锯齿/上采样/合成 UI；与下一帧的阴影/深度/不透明重叠；若可行从计算队列 present，可降低延迟。见下图。

![第42页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0042.jpg)

---

## 第 43 页 · GCN 波前限制调优 (GCN Wave Limits Tuning)

**为各 pass 设不同限制**：高像素/三角形比时关闭 late alloc。**限制异步计算的分配**：避免占满所有计算单元、减轻 cache 抖动。**发布前值得细调**：在 DOOM 部分场景中可节省约 1.5 ms。见下图。

![第43页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0043.jpg)

---

## 第 44 页 · GCN 寄存器使用 (GCN Register Usage)

**全局考虑寄存器与 LDS 分配**；**不必总追求 256 的约数**；**注意并发的顶点着色器与异步计算着色器**；**细调以找到最佳点**。**DOOM 不透明 pass 示例**：GFX 队列 PS 56 VGPR、VS 24 VGPR；计算队列上采样 CS 32 VGPR；可达成 4PS+1CS/VS 或 3PS+2CS+1VS，相较 64 VGPR 版本节省约 0.7 ms。见下图。

![第44页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0044.jpg)

---

## 第 45 页 · 透明与粗糙玻璃（场景截图）

黑暗科幻走廊：右侧脏污、模糊的粗糙玻璃面板（反射/透射），中央强光入口，地面血泊与反射，展示透明物体、粗糙玻璃与贴花的综合效果。见下图。

![第45页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0045.jpg)

---

## 第 46 页 · 角色与体积雾（场景截图）

多角色特写：前景怪物细节与发光模块，背景虚化角色与薄雾，展示体积雾、景深与角色光照。见下图。

![第46页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0046.jpg)

---

## 第 47 页 · 战斗场景（血迹与反射）

血腥走廊：地面血浆反射、残骸与敌人，展示贴花、反射与光照在战斗场景中的表现。见下图。

![第47页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0047.jpg)

---

## 第 48 页 · 透明体（全息人影）

怪物与背景蓝色半透明全息人影，展示透明体渲染与体积雾。见下图。

![第48页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0048.jpg)

---

## 第 49 页 · 场景截图（LAZARUS 走廊）

科幻走廊：左侧整洁结构、右侧血肉覆盖、地面血泊与武器，反射与贴花。见下图。

![第49页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0049.jpg)

---

## 第 50 页 · 角色特写与景深

怪物特写、胸部发光核心与背景景深光点，展示角色渲染、动态光照与后处理景深。见下图。

![第50页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0050.jpg)

---

## 第 51 页 · 接下来？(What's next?)

**What's next?**：**解耦成本频率 = 收益**（Decoupling frequency of costs = Profit）。**改进方向**：纹理质量、全局光照、整体细节、工作流程等。见下图。

![第51页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0051.jpg)

---

## 第 52 页 · 特别鸣谢 (Special Thanks)

**Code**：Robert Duffy, Billy Khan, Jim Kejllin, Allen Bogue, Sean Flemming, Darin Mcneil, Axel Gneiting, Michael Kopietz, Magnus Högdahl, Bogdan Coroi, Ivo Zoltan Frey, Johnmichael Quinlan, Greg Hodges。**Art**：Tony Garza, Lear Darocy, Timothee Yeremian, Jason Martin, Efgeni Bischoff, Felix Leyendecker, Philip Bailey, Gregor Kopka, Pontus Wahlin, Brett Paton。**Entire id Software team**；**Natalya Tatarchuk**。见下图。

![第52页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0052.jpg)

---

## 第 53 页 · 我们正在招聘 (We are Hiring!)

**We are Hiring!** ZeniMax 旗下各工作室有多个职位空缺；请访问 https://jobs.zenimax.com。右侧为 id 标志。见下图。

![第53页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0053.jpg)

---

## 第 54 页 · 感谢 (Thank you)

**Thank you**。**Tiago Sousa**：tiago.sousa@idsoftware.com，@idSoftwareTiago。**Jean Geffroy**：Jean.geffroy@idsoftware.com。见下图。

![第54页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0054.jpg)

---

## 第 55 页 · 参考文献 (References)

[1] Clustered Deferred and Forward Shading, Ola Olson et al., HPG 2012  
[2] Practical Clustered Shading, Emil Person, Siggraph 2013  
[3] CryENGINE 3 Graphics Gems, Tiago Sousa, Siggraph 2013  
[4] Fast Rendering of Opacity Mapped Particles using DirectX11, Jon Jansen, Louis Bavoil, Nvidia Whitepaper 2011  
[5] Fire in the Vulkan Demo, H Nguyen, GPU Gems, 2004  
[6] Lost Planet Tech Overview, http://game.watch.impress.co.jp/docs/20070131/3dlp.htm  
[7] GPU Best Practices (Part 2), Martin Fuller, Xfest 2015  
[8] Southern Island Series Instruction Set Architecture, Reference Guide, 2012  
[9] GCN Shader Extensions for Direct3D and Vulkan, Matthaeus Chajdas, GPUOpen.com, 2016  
[10] id Tech 5 Challenges, J.M.P. van Waveren, Siggraph, 2009  
[11] Mipmapping Normal Maps, Toksvig M, 2004  
[12] Real-Time Rendering, 3rd Edition, Moller et al., 2008  
[13] Physically-based lighting in Call of Duty: Black Ops, Dimitar Lazarov, Siggraph 2011  
[14] Specular Showdown in the Wild West, Stephen Hill, 2011  

见下图。

![第55页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0055.jpg)

---

## 第 56 页 · 附加幻灯片 (Bonus Slides)

本页为章节分隔页，标题为「Bonus Slides」（附加幻灯片），引出后续补充内容。见下图。

![第56页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0056.jpg)

---

## 第 57 页 · 光照 (Lighting)（附加）

**光照类型**：点光、投影器、方向光（无显式太阳）、区域光（四边形/圆盘/球体）、IBL（环境探针）。**光照形状**：多数光源为 OBB，作为隐式「裁剪体积」防漏光；投影器为锥体。**衰减/投影器**：美术驱动纹理，存于图集、索引同贴花，有时用于假阴影，BC4。**环境探针**：立方体贴图数组、按探针 ID 索引，固定 128×128，BC6H。右侧为 Projector Atlas 示意。见下图。

![第57页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0057.jpg)

---

## 第 58 页 · 延迟通道 (Deferred Passes)

**Deferred Passes**：需要**动态且高性能的 AO 与反射**；解耦各 pass 有助于减轻 VGPR 压力。**前向不透明通道中的 2 个额外目标**：镜面/光滑度 RGBA8；法线 R16G16F。支持将**探头与实时反射合成**。**最终合成**：SSR、环境探头、AO/镜面遮蔽、雾。右侧为室内场景最终效果与 AO/深度类通道示意。见下图。

![第58页](./Siggraph2016_idTech6/Siggraph2016_idTech6_page-0058.jpg)
