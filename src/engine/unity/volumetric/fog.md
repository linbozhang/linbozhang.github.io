# 视锥空间 3D 纹理：大气雾 + 场景投影参数

实现思路与参考（Unity / 通用管线）。

---

## 一、目标与用途

- **视锥空间 3D 纹理**：在相机视锥内划分体素网格（frustum-aligned voxel / froxel），用 3D 纹理存储每个体素的数据。
- **给雾片用**：雾片（全屏或局部 quad）在着色时沿视线 raymarch，对这张 3D 纹理采样，得到：
  - **预计算的大气雾参数**：密度、消光、散射、透射等；
  - **场景/投影参数**：深度、遮挡、或与场景几何的投影关系（用于雾与场景融合、遮挡等）。

这样雾片不需要每像素重新算一遍大气和投影，只需查预填好的体积数据，性能更好、也便于和粒子/体积雾统一。

---

## 二、整体思路（参考成熟管线）

业界常见做法是：**视锥对齐的 3D 体素网格 + 多 Pass GPU 计算**，典型流程如下。

### 1. 坐标系与体素布局

- **View 空间**：X/Y 对应屏幕平面，Z 为视线深度；体素网格与视锥对齐，近裁面到远裁面沿 Z 划分。
- **深度分布**：Z 方向常用**指数分布**（近处密、远处疏），既保证近处雾的细节，又控制体素总数。
- **命名**：这种「视锥对齐体素」常叫 **froxel**（frustum + voxel），Frostbite、UE、Flax 等都用类似思路。

### 2. 管线阶段（四段式）

| 阶段 | 作用 | 输出/写入 |
|------|------|-----------|
| ① 初始化体积属性 | 为每个体素写入基础雾属性 | 3D 纹理：密度、消光、散射系数、高度雾等 |
| ② 光照注入 (Light Injection) | 把光源（方向光/点光/聚光）贡献写入体积 | 同一或另一 3D 纹理：每体素累积光照 × 可见性 |
| ③ 散射/传播 (Scattering) | 在体积内做散射或传播（可选） | 更新 3D 纹理：最终每体素「发光」或散射结果 |
| ④ 沿视线积分 (Integration) | 雾片 shader 沿 view ray 采样 3D 纹理并积分 | 屏幕空间：雾颜色 + 透射（或只输出到雾片用） |

你要的「预计算大气雾参数」主要在 ① 和 ③；「场景投影参数」可以在 ① 里从深度/GBuffer 写入（例如每个体素对应深度、或是否被遮挡），也可在 ④ 里和场景深度一起用。

### 3. 建议在 3D 纹理里存什么（给雾片用）

**大气雾相关（预计算）**

- 密度 / 消光系数（extinction）
- 散射系数或 albedo
- 透射（transmittance）或光学深度（可选，看你是查表还是现场算）
- 若用高度雾：可存基于世界高度的密度乘数

这些可以在 ① 用分析公式（如指数高度雾）或预计算 LUT 填进 3D 纹理。

**场景/投影相关**

- 体素中心对应的**视图空间深度**或**线性深度**（雾片可用来和场景深度比较、做遮挡/混合）
- 可选：从 GBuffer 采样的简化的场景信息（如粗略法线、遮挡 mask），用于雾与几何的过渡

这些在 ① 由体素在 view 空间的位置 + 深度缓冲/GBuffer 计算并写入。

**具体通道布局示例（按需裁剪）**

- **Texture3D A**：R=密度/消光, G=散射系数, B=透射或保留, A=高度雾权重 等
- **Texture3D B**（可选）：RGB=注入光/散射结果, A=线性深度或遮挡
- 或把「场景投影参数」合进 A 的额外通道，减少纹理数量。

### 4. 分辨率与性能

- **典型分辨率**：约 128×64×64 到 256×128×64（宽×高×深度），深度 slice 数对性能影响大。
- Z 用指数分布可减少远处 slice 数或让远处体素更大。
- 雾片采样时用**三线性过滤**即可；若要更稳可加**时间滤波**（temporal reprojection）减轻闪烁。

---

## 三、实现步骤摘要

1. **建 3D 纹理**  
   创建 2–3 张 3D 纹理（如 RGBA16F），尺寸按上面范围；生命周期与相机/视锥绑定，每帧或每 N 帧重建。

2. **Pass 1：初始化**  
   Compute Shader：对每个体素根据其在 view 空间的位置（可转世界空间）计算：
   - 大气雾密度、消光、散射（分析式或查预计算 LUT）；
   - 可选：从深度缓冲采样，得到该体素对应的场景深度/遮挡，写入「场景投影参数」。

3. **Pass 2：光照注入**  
   对每个光源：用 shadow map 或体积 shadow 计算该光源在体素处的可见性与强度，乘散射相位，additive 写入体积光照纹理（或合并到同一纹理的 RGB）。

4. **Pass 3：散射（可选）**  
   若要做多散射或传播，可在 3D 纹理上再做 1–2 个 compute pass；若只做单散射，可省略或简化。

5. **雾片着色**  
   雾片 VS/PS：从相机发射 view ray，按步长 raymarch，每步采样 3D 纹理（位置由 view 空间或 NDC 转 3D UV），累加透射与散射，得到最终雾颜色；同时可用 3D 纹理里的「场景投影参数」与场景深度做混合/遮挡。

---

## 四、参考实现与链接（成熟方案）

下面都是「视锥/视图空间 3D 纹理 + 体积雾/大气」的经典或工程可用方案，可直接对照实现细节。

### 1. 体积雾管线（视锥 3D 纹理、froxel）

- **Bart Wronski – Volumetric Fog (Siggraph 2014)**  
  视锥对齐 3D 纹理、光照注入、散射、沿视线积分的完整管线，很多引擎方案的源头。  
  - PDF：<https://bartwronski.com/wp-content/uploads/2014/08/bwronski_volumetric_fog_siggraph2014.pdf>  
  - 博客与代码：<https://bartwronski.com/2014/08/20/major-c-net-graphics-framework-update-volumetric-fog-code/>

- **GPU Pro 6 – Volumetric fog and lighting**  
  与上面思路一致，写成书本章节，便于对照公式与流程。  
  - O'Reilly：<https://www.oreilly.com/library/view/gpu-pro-6/9781482264623/chapter-56.html>

- **Flax Engine – Volumetric Fog**  
  基于 Frostbite/育碧思路的 4 步管线（初始化 → 光照注入 → 散射 → 积分），文档清晰。  
  - 手册：<https://docs.flaxengine.com/manual/graphics/fog-effects/volumetric-fog.html>  
  - 博客：<https://flaxengine.com/blog/flax-facts-14-volumetric-fog/>

- **Unreal Engine – Volumetric Fog**  
  官方实现：视锥内体积、指数高度雾、每光源散射强度与体积阴影。  
  - UE5：<https://dev.epicgames.com/documentation/en-us/unreal-engine/volumetric-fog-in-unreal-engine?application_version=5.0>  
  - UE4：<https://docs.unrealengine.com/4.26/en-US/BuildingWorlds/FogEffects/VolumetricFog/>

- **CryEngine – Volumetric Fog**  
  体素化体积雾、动态阴影、环境探针。  
  - <https://www.cryengine.com/docs/static/engines/cryengine-5/categories/23756816/pages/26215326>

### 2. 预计算大气（LUT / 3D 纹理）

- **Bruneton – Precomputed Atmospheric Scattering**  
  预计算 2D/3D LUT（transmittance、scattering、irradiance），运行时查表得到大气颜色与透射；可与你的 3D 体积结合（在初始化 pass 里查这些 LUT 填进体素）。  
  - 主页与实现：<https://ebruneton.github.io/precomputed_atmospheric_scattering/>  
  - 代码：<https://github.com/ebruneton/precomputed_atmospheric_scattering>

### 3. 极线采样（可选优化）

- **Epipolar sampling for volumetric fog / god rays**  
  用极线将体积光/阴影变成 1D 采样，减少 raymarch 成本；若你后面要做体积光轴，可参考。  
  - ACM：<https://dl.acm.org/doi/10.1145/1730804.1730823>

### 4. 寒霜/育碧（froxel 概念）

- **Physically Based and Unified Volumetric Rendering in Frostbite**  
  视锥对齐体素、统一体积渲染、与材质/光照解耦。  
  - SlideShare：<https://www.slideshare.net/slideshow/physically-based-and-unified-volumetric-rendering-in-frostbite/51840934>  
  - EA/Frostbite：<https://www.ea.com/frostbite/news/physically-based-unified-volumetric-rendering-in-frostbite>

### 5. 开源/示例代码

- diharaw/volumetric-fog：<https://github.com/diharaw/volumetric-fog>
- wyzwzz/VolumeFog：<https://github.com/wyzwzz/VolumeFog>

---

## 五、和需求的对应关系

| 需求 | 做法 |
|------|------|
| 「视锥空间生成一份 3D 纹理」 | 采用 froxel 布局，用 Compute 多 pass 填 3D 纹理（如上 ①～③）。 |
| 「预计算的大气雾参数」 | 在**初始化 pass** 里按体素位置算（或查 Bruneton 类 LUT）密度、消光、散射等，写入 3D 纹理；雾片只做采样+积分。 |
| 「场景投影参数」 | 在初始化时用体素 view 位置 + 深度缓冲/GBuffer 得到深度、遮挡等，写入同一或另一 3D 纹理通道，供雾片做遮挡/混合。 |

按上述管线实现后，雾片端就只需要：**view ray + 3D 纹理采样 + 积分**，逻辑会简单很多。若你说明当前是 Unity 还是别的引擎、以及是否已有深度/GBuffer，可以再细化到具体 shader 接口和 3D 纹理格式（例如 R11G11B10 + R16 等）。
