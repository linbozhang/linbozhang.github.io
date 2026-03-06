# Volumetric Fog: Unified compute shader based solution to atmospheric scattering

**Bartlomiej Wronski, Ubisoft Montreal · SIGGRAPH 2014 Vancouver**

以下为根据 PDF 幻灯片整理的文字版，每页附原幻灯片图；文末为 PDF 内嵌插图（ilovepdf 提取）。术语保留英文括号。

---

## 第 1 页 · SIGGRAPH 2014 封面

SIGGRAPH 2014 官方封面。主视觉为金属质感双环 logo，标语「NATURALLY DIGITAL」，举办地 Vancouver。

![第1页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0001.jpg)

---

## 第 2 页 · 演讲标题与作者

- **标题**：Volumetric Fog: Unified compute shader based solution to atmospheric scattering（体积雾：基于统一 compute shader 的大气散射方案）
- **作者**：Bartlomiej Wronski  
- **单位**：Ubisoft Montreal  
- **会议**：The 41st International Conference and Exhibition on Computer Graphics and Interactive Techniques

![第2页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0002.jpg)

---

## 第 3 页 · 演讲概览 (Presentation overview)

演讲分为 5 部分：

1. **大气散射简介**：现象的重要性、物理规律、在真实感渲染与游戏中的应用。  
2. **现有游戏方案**：以往游戏如何处理大气效果，以及为何现有方案对项目仍不满足。  
3. **算法概览**：核心思路、步骤与数据结构。  
4. **实现细节**：实现要点与如何做到快速、稳健。  
5. **Beyond Assassin's Creed 4**：因时间或项目约束未进入 AC4、但计划在后续项目中实现或正在实现的想法。

![第3页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0003.jpg)

---

## 第 4 页 · 大气散射 (Atmospheric scattering)

大气散射是多种视觉现象背后的物理原因，例如：

- 天空颜色 (Sky color)  
- 雾 (Fog)  
- 云 (Clouds)  
- 「上帝之光」 (God rays)  
- 光轴 (Light shafts)  
- 体积阴影 (Volumetric shadows)

本页配有天空、雾中光轴与云层的示例图。  
为何需要模拟大气散射？因为它是可见世界中许多视觉元素的物理基础。

![第4页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0004.jpg)

---

## 第 5 页 · 游戏中的大气散射 (Atmospheric scattering in games)

在游戏中的意义：

- 真实感渲染所需  
- 帮助感知距离差异  
- 有助于隐藏 LOD 与流式加载（早期游戏就曾用很浓的线性雾掩盖极短的流式距离）  
- 营造氛围与情绪  
- 作为美术工具实现「特殊」效果  

总结：不仅用于正确再现现实，也帮助玩家感知物体间距、形成统一的场景构图，并且是艺术方向和特殊效果的重要工具。

![第5页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0005.jpg)

---

## 第 6 页 · 大气散射现象与能量守恒

大气散射由光子与构成传输介质的粒子相互作用引起。光穿过非真空介质时，可能与粒子碰撞，发生**透射 (Transmission)**、**散射 (Out-scattering)** 或**吸收 (Absorption)**。光学中常用统计模型描述，可定义参与以下过程的能量比例：

- **透射 (Transmittance)**  
- **散射 (Scattering)**  
- **吸收 (Absorption)**  

能量守恒：**L_incoming = L_transmitted + L_absorbed + L_scattered**

（原文幻灯片中「Absorption」曾误拼为「Absorbtion」。）

![第6页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0006.jpg)

---

## 第 7 页 · 无散射 (No scattering)

**无光散射 / 非参与介质 (non-participating transport media)**：假定传输介质像真空一样，光在物体之间的路径上没有辐射的损失或增益。  
典型渲染情形：光从光源出发，按表面 BRDF 在物体间反射，最终到达相机；最简情况是仅直接光、无反弹/GI。图中为光源→物体→相机的直线光路示意。

![第7页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0007.jpg)

---

## 第 8 页 · 光散射 (Light scattering)

当介质参与光传输时，每个足够大、能影响光子/光线的粒子都会参与光传输方程。例如尘埃或水粒子会使部分光线/光子弹向随机方向：一部分光**进入**视线路径（**内散射，In-scattering**），另一部分光被弹**出**视线路径、变暗（**外散射，Out-scattering**）。  
图中：光源在右侧、视锥/相机在左侧，中央水平灰箭为主光路；灰色箭头从光源折向主光路表示内散射，青色箭头从主光路向下/向外表示外散射；另有前向散射示意。  
现实中每个粒子都会按相位函数同时产生外散射与内散射，多条射线多次进出光路，非常复杂；实时渲染中通常**忽略多重散射 (multiple scattering)**。

![第8页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0008.jpg)

---

## 第 9 页 · 比尔–朗伯定律 (Beer-Lambert Law)

用于光散射计算的一条重要物理定律是 **Beer-Lambert 定律**，它描述**入射光的消光 (extinction)**，即光的**外散射**。该定律定义**透射率 (transmittance)**：从给定方向入射、经介质传输后仍保留的光的比例。  
公式：**T(A → B) = e^(−∫_A^B βe(x) dx)**  
其中 **βe** 为**消光系数 (extinction coefficient)**，等于散射系数与吸收系数之和。由 Beer-Lambert 可知，光在介质中的消光是光所经距离的**指数函数**。  
图中：左侧为光源，光线穿过中间含粒子的矩形介质，部分被散射出（小箭头），右侧为透射后的光（青色箭头与绿块）。

![第9页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0009.jpg)

---

## 第 10 页 · 散射类型 (Different scattering types)

**Mie 散射**：较大粒子（如气溶胶、尘埃）。**各向异性**强，**前向瓣 (forward lobe)** 明显，吸收比例较高。  
**Rayleigh 散射**：极小粒子（如空气分子）。**各向同性**、均匀，但**与波长相关**，短波散射更强，吸收可忽略，常用来解释天空的蓝色。  
图中对比了两种散射的入射光、透射与出射散射方向。

![第10页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0010.jpg)

---

## 第 11 页 · 相位函数 (Phase functions)

**相位函数 (phase function)** 描述光在各个方向上被散射多少，是**入射光方向与出射方向夹角**的函数；具有**能量守恒**性质：对所有方向的积分等于 1（若内含吸收信息则可小于 1）。  
图中：左侧为简化示意——水平灰箭为入射光，从中心粒子向上偏左的绿箭为散射光 **T(α)**，角 **α** 为散射角；下标「Light scattered in direction T(α)」。  
**能量守恒**公式：**∫₀^2π ∫₀^π P(θ) dθ dφ = 1**  
右侧为**极坐标图**示例：某复杂相位函数（如云层相位函数）随散射角变化的曲线，可见前向瓣等不规则瓣状。  
来源：Bouthors et al., «Real-time realistic illumination and shading of stratiform clouds»。  
说明：相位函数可以非常复杂，可由多种模型或真实采集数据描述。

![第11页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0011.jpg)

---

## 第 12 页 · 解析相位函数 (Analytical phase functions)

常用以模拟 Mie 类各向异性散射的是 **Henyey-Greenstein 相位函数**。特点：

- 可调各向异性因子  
- 对解析光源求值成本低（多可预计算）  
- 可简单展开为球谐；支持 zonal 球谐 (1, g, g², g³)  

公式：**p(θ) = (1 − g²) / (4π [1 + g² − 2g cos θ]^(3/2))**  
更复杂的相位函数可由多个 Henyey-Greenstein 的加权和构造。

![第12页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0012.jpg)

---

## 第 13 页 · 散射各向异性 (Scattering anisotropy)

三张并排图展示不同**各向异性参数 g** 下体积雾效果（室内、光线从矩形窗射入）：  
- **g = 0**（左）：各向同性散射，光线均匀弥散，无明显光束，窗户不突出。  
- **g = 0.9**（中）：强前向散射，窗光形成非常清晰、明亮的光柱（丁达尔效应），其余区域较暗。  
- **g = 0.3**（右）：介于二者之间，有可见光束但不如 g=0.9 强烈，雾气仍有一定弥散。  
说明 **g**（通常 ∈ [−1, 1]）对体积雾中光的传播与视觉影响很大：g 越接近 1，前向散射越强，光束越明显。

![第13页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0013.jpg)

---

## 第 14 页 · 游戏中的近似（续）(Approximations in games)

**解析解 (Analytical solutions)**  
自 90 年代与早期 OpenGL 起，第一种近似是解析解；早期多为简单**线性深度雾**，上一代主机上的先进做法是**基于指数距离的解析雾**。C. Wenzel 在 «Real-time atmospheric effects in games revisited» 中有清晰描述；基于真实散射现象并给出解析解，但**无法处理变化的介质密度与阴影**。配图：晴朗天空下的远山，大气透视/雾效。来源：C. Wenzel。  

**基于公告板/粒子 (Billboard / particle based)**  
第二种是美术制作的**面向相机的公告板或粒子**（与相机相交时淡出），易用、对程序员依赖少；缺点：依赖美术、设置繁琐、不够稳健（如昼夜或视角变化时可能「不对」）、不够动态（对光照与阴影变化响应不足）。配图：密林中的 God rays 与体积雾。

![第14页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0014.jpg)

---

## 第 15 页 · 游戏中的近似 (Approximations in games)

两类常见近似：

- **后处理类 (Post-effect based)**：因 UE3、CryEngine 而流行，基于后处理与径向模糊的屏幕空间效果；观感可以很好，但光源不在屏幕内时效果会完全消失。  
- **光线步进 (Ray-marching)**：效果出色（尤其配合极线采样），但通常作用距离较短并有局限。  

配图引用：C. Wyman, S. Ramsey «Interactive Volumetric Shadows in Participating Media with Single-Scattering»。

![第15页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0015.jpg)

---

## 第 16 页 · 为何不用 2D 光线步进？(Why not 2D raymarching?)

**2D 光线步进的局限：**  
- 多数**不基于物理**，多为近距离「体积阴影/光束」，用艺术家指定的混合模式。  
- **循环**执行，对 GPU 并行性利用差：样本顺序计算；在 AMD GCN 等架构上会浪费大量线程波。  
- **极线采样**等优化在诸多限制下工作：不支持**变化的介质密度**、不支持**多光源**（每个光源需不同极线方案）。  
- 与**前向渲染**不兼容：单层效果、只存一个深度，无法正确处理透明物体或粒子。  
- **低分辨率**带来欠采样、锯齿与**边缘伪影**。  

因此需要更统一的体积方案（如 3D 纹理 + compute）。

![第16页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0016.jpg)

---

## 第 17 页 · 灵感来源 (Inspiration)

**Kaplanyan, «Light Propagation Volumes», Siggraph 2009**  
在对多种「经典」技术做原型后，最大灵感来自 Anton Kaplanyan 在 Siggraph 2009 的**光传播体 (LPV)** 全局光照技术。该技术总结与未来工作中提到：用**发光体积纹理**（注入并传播光以模拟 GI 的结果）来**计算参与介质中的光传输**；好处是**只需一次 raymarching、与光源数量无关**，参与介质中的光传输可被统一。若再加上简单**阴影项**，就能以阴影计算的成本得到光轴/God rays。本页配图为拱形室内、地面红/绿/蓝光源在体积雾中形成彩色光束。

![第17页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0017.jpg)

---

## 第 18 页 · Volumetric Fog 方案引入

在既有启发与 raymarching 方案基础上，发展出新方案并命名为「Volumetric Fog」。本页为城镇/街道场景的体积雾效果图：建筑、树木与地面被雾与光轴填充，远处有 God rays。

![第18页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0018.jpg)

---

## 第 19 页 · 视频截图（体积雾效果）

游戏内截图：第三人称、角色背对镜头，站在雨雾弥漫的丛林中；中远景有厚重体积雾，雨丝与棕榈剪影，界面含血条/耐力、小地图、手柄按键提示（X/B/A）等。下方标注「VIDEO」，表示来自视频演示。用于展示体积雾在实际场景中的表现。

![第19页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0019.jpg)

---

## 第 20 页 · 多光源效果

实际运行截图：丛林场景中体积雾与**多光源**协同工作——包括方向光形成的光轴与场景中的点光源（黄色灯泡图标），雾在光源周围形成光晕。说明：该方案可连贯、正确、完善地支持多光源。

![第20页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0020.jpg)

---

## 第 21 页 · 算法概览（章节页）(Algorithm overview)

本页为「算法概览」部分的**章节标题页**，中央标题 "Algorithm overview"，表示接下来将展开算法的详细说明。

![第21页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0021.jpg)

---

## 第 22 页 · 算法概览 (Algorithm overview)

- 使用**体积纹理 (Volumetric textures)** 作为中间存储。  
- 使用 **Compute Shader** 与 **UAV (Unordered Access Views)** 进行高效的 raymarch 与写入。  

这样便于拆分 pass、独立调度，并以高效且方便的方式向 3D 纹理写入体积数据。

![第22页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0022.jpg)

---

## 第 23 页 · 算法概览：解耦散射步骤 (Algorithm overview)

**解耦典型的散射步骤 (Decouple typical scattering steps)**：  
1. 参与介质密度估计 (Participating media density estimation)  
2. 计算内散射光照 (Calculating in-scattered lighting)  
3. 光线步进 (Ray-marching)  
4. 应用效果 (Applying effect)  

算法的关键思想是将 raymarching 的典型步骤**解耦并并行化**，分别启动；从而获得并行性，并可**独立交换与调整**算法的每个环节。

![第23页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0023.jpg)

---

## 第 24 页 · 算法概览：多 Pass 流程图 (Algorithm overview)

流程图：**密度估计 (Density estimation)** 与 **光照计算 (Lighting calculation)** 可合并或串行/并行执行，二者分别写入 **3D 纹理**；两路 3D 纹理输入到 **Raymarching**，再输出到 **3D 纹理**；最后 **Apply in forward / deferred** 得到 **Shaded objects**。  
说明：  
1. 首先对每个体积单元做光照与阴影计算。  
2. 并行或串行地估计并驱动参与介质密度。  
3. 用体积纹理中存储的信息做 2D raymarching，结果存于体积切片。  
4. 用像素着色器将结果应用到前向或延迟着色的物体上。

![第24页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0024.jpg)

---

## 第 25 页 · 体积纹理布局 (Volume texture layout)

**我们的体积雾中间存储长什么样？**

- **初版思路**：与世界空间对齐的立方体。优点包括时间滤波简单；缺点是在体积内 raymarch 需要多次采样、较慢且易产生走样。  
- **采用方案**：与**相机视锥 (View frustum)** 对齐。  
  - 宽高用 NDC (device coordinates x/y)，深度用**指数深度分布 (Exponential depth distribution)**，近处精度更高（走样在近处最明显）。  
  - 缺点是对时间性走样/闪烁更敏感；优点是对视线做 raymarch 可简化为沿深度切片的**并行扫描**。  
- **实现**：体积尺寸为 **160×90×64** 或 **160×90×128**（依平台），**16bit Float RGBA**；成本与屏幕分辨率几乎无关；160×90×64 的体素数相当于 720p 表面。光照在每个体素上只算一次；效果距离由美术设定，约 50–128 米，与当代表现风格一致；更长距离可通过指数深度或级联实现。

![第25页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0025.jpg)

---

## 第 26 页 · 体积纹理分辨率够吗？(Is this volumetric texture resolution enough?)

场景截图：热带/遗迹场景，青蓝调体积雾、右侧火炬暖光在雾中形成清晰光束，无明显块状或阶梯伪影。  
下方问题：「**Is this volumetric texture resolution enough?**」（这个体积纹理分辨率足够吗？）——从视觉上说明所选分辨率在该类雾效下是可接受的。

![第26页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0026.jpg)

---

## 第 27 页 · 体素分辨率——太低了吗？(Volume resolution - too low?)

要点：我们为**整条视线**存储信息，并沿深度做 **tex3D 过滤**；每个 1080p 像素都能获得**正确信息**，**没有边缘伪影**；缺点是结果偏柔和。  
说明：体素纹理分辨率看起来很低但足够，因为 (1) 沿光线每个深度存的是低频信息；(2) 应用效果时对体素做**四线性过滤**，看不到单纹素；(3) 每个像素在其精确深度收到正确信息；(4) 透视校正与体素形状保证信息正确分布；(5) 深度不连续处不会出现边缘伪影。效果偏柔和符合艺术方向，也与真实大气中多重散射的柔化一致。另一优势：不依赖场景深度，可在阴影贴图就绪后与场景渲染**并行**（如 AMD 异步计算、控制台 API 或 Mantle）。

![第27页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0027.jpg)

---

## 第 28 页 · 2D 方案的边缘伪影 (2D Approach – edge artifacts)

图：X–Z 截面中两条平滑轮廓（青线）与**低分辨率采样**得到的阶梯状近似（灰块）对比；下方为相机/观察者图标。  
在做常规 2D 低分辨率渲染时，主要问题出在**边缘不连续**处：低分辨率后处理必须从多个可能深度中**选一个**，导致部分最终着色片段得到错误信息（无论是插值还是从邻域选取，如 bilateral upsampling）。即 2D 方法在深度突变处易产生伪影。

![第28页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0028.jpg)

---

## 第 29 页 · 3D 纹理——正确边缘 (3D Texture - proper edges)

图：3D 网格中一大球与一扁椭球，两个绿色棱柱表示采样体，中心红点为采样点；下方绿色箭头指向输出块。  
用 **3D 纹理与 3D 插值**则没有上述问题：每个全分辨率片段及其深度都得到**分段线性插值**的计算结果；虽仍是低分辨率、可能「锯齿」，但**没有边缘不连续伪影**。

![第29页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0029.jpg)

---

## 第 30 页 · 走样问题 (Aliasing problem)

图例说明：**低通滤波**如何减轻高频率源信息带来的**时间性走样/闪烁**。  
「Without low-pass filter」：帧 N 与 N+1 间采样位置或亮度变化导致明显闪烁与锯齿轮廓。  
「With low-pass filter」：滤波后采样周围有柔和晕斑，帧间更稳定，闪烁与锯齿轮廓减弱。

![第30页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0030.jpg)

---

## 第 31 页 · 走样问题：阴影级联 (Aliasing problem)

**4 个 shadow cascade，1536×1536**（或依平台 1k×1k）：细节过多，阴影信息**高于体积的奈奎斯特频率**，导致大量走样与闪烁，需要对阴影施加**低通滤波**；朴素的 32-tap PCF 性能不可接受。  
算法第一步是为雾的太阳散射阴影**准备阴影图**。常规级联阴影分辨率很高、信息密集，对平滑近似的体积雾而言过多（尤其近处、前两级 cascade 集中在几米内）；需要更低分辨率以减轻植被等运动带来的闪烁/走样。早期用大核 PCF 的实现性能差且仍有闪烁与走样。

![第31页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0031.jpg)

---

## 第 32 页 · 指数阴影贴图 (Exponential shadow maps)

**ESM 性质**：不需做深度比较即可做阴影测试；估计**阴影概率**；阴影测试计算高效；**可降采样**（如 256×256 R32F 级联）。  
图中为阴影函数 **e^(−k(d−z))** 在 (d−z) 为横轴、不同 k（如 10、20、80）下的曲线；阴影测试 > 1.0 无效、域外标注。来源：Annen et al., «Exponential Shadow Maps»。  
ESM 可对估计的阴影概率做滤波，从而对阴影函数降采样；阴影测试的实现简单且高效，附赠幻灯片中有简单代码片段。

![第32页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0032.jpg)

---

## 第 33 页 · 指数阴影贴图（续）(Exponential shadow maps)

**可过滤**（可分离模糊）；缺点为**阴影泄漏 (shadow leaking)**，在参与介质中可忽略。代码片段见附赠幻灯片。  
实现：将级联阴影图下采样四次（目标 R32F 1024×256）；下采样时计算指数阴影函数（参见 Exponential Shadow Mapping，即用指数函数替代切比雪夫不等式的方差阴影图扩展）；此 pass 中再做**可分离盒式滤波**（两步）使阴影更柔、去除走样。ESM 的阴影泄漏在常规渲染中不实用，但在参与介质中不明显。

![第33页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0033.jpg)

### 补充说明：指数函数、切比雪夫/方差、可分离盒式滤波与 ESM 阴影泄漏

**1. 指数函数在 ESM 里的作用**  
方差阴影图 (VSM) 用**切比雪夫不等式**从深度的一阶、二阶矩估计「被遮挡概率」的上界，公式形如 P(z ≥ d) ≤ σ²/(σ² + (d−μ)²)，容易产生光渗 (light bleeding)。**ESM** 不用切比雪夫，而是直接存 **e^(−c·深度)**：渲染 shadow map 时存 exp(−c·深度)，着色时用 exp(−c·(d−z)) 估计遮挡。这样**可滤波**——指数函数在卷积下性质较好，下采样/模糊后仍能近似平均遮挡程度；且**不需要深度比较**，一次采样即可，适合体积雾里低分辨率、大核的阴影。因此「用指数函数替代切比雪夫不等式的方差阴影图」指：不再用 VSM 的切比雪夫概率上界，用指数函数近似遮挡强度，且该近似可滤波。

**2. 切比雪夫不等式与方差阴影图 (VSM)**  
切比雪夫不等式：对随机变量 X（均值 μ、方差 σ²），P(|X−μ| ≥ t) ≤ σ²/t²。VSM 在 shadow map 里存深度 z 的一阶矩（μ）和二阶矩，得到 σ²，用单边形式估计 P(z ≥ d) ≤ σ²/(σ² + (d−μ)²)。ESM 论文（Annen et al.）在此基础上改为用**指数函数 e^(−c(d−z))** 近似遮挡，便于滤波与下采样，故称「用指数函数替代切比雪夫不等式的方差阴影图扩展」。

**3. 可分离盒式滤波（两步）**  
**盒式滤波**：每个像素取矩形邻域内像素的平均；若核为 n×n，直接做为 O(n²)。**可分离**即 2D 核可拆成「先对行做 1D 核、再对列做 1D 核」：第一遍对每行做 1D 盒式滤波（水平），第二遍对中间结果每列做 1D 盒式滤波（垂直），总复杂度 O(2n)，效果等价于 2D 盒式模糊。这里在 ESM 下采样 pass 里同时做可分离盒式滤波（水平+垂直两步），使阴影变柔、减弱高频，从而**减轻走样与闪烁**，适合体积雾所需的大尺度柔和阴影。

**4. ESM 的阴影泄漏 (shadow leaking)**  
**阴影泄漏**：本应完全在阴影内的区域被算成还有一点亮，像光从遮挡物边缘「漏」进阴影。原因可理解为：ESM 存的是 exp(−c·深度)，模糊后得到的是邻域内指数值的平均，遮挡物边缘附近既有遮挡深度也有非遮挡深度，平均后 exp 不会完全为 0，着色时阴影变浅，在硬阴影边缘形成不该亮的过渡带。在**常规物体阴影**里要锐利边缘，漏光明显，故 ESM 在常规渲染中不实用。在**参与介质（体积雾）**里本身就要柔和渐变阴影，漏光被散射和多次采样平均掉，视觉上不明显，因此「在参与介质中不明显」。

---

## 第 34 页 · 聚光灯抗锯齿 (Spotlights antialiasing)

图：聚光灯**锥体**（灰色大三角 + 白色半透明内锥）与**像素网格**相交；锥角标为 α。网格中与锥边相交的像素（如绿色块）被部分照亮，产生锯齿。  
说明当聚光硬边落在像素之间时，需要抗锯齿以平滑聚光灯边缘造成的锯齿。

![第34页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0034.jpg)

---

## 第 35 页 · 算法细节 (Algorithm details)

流程图概括管线：

- **输入**：Shadow cascades、Depth buffer、Color buffer。  
- **阴影**：PS 将 Shadowmap 下采样与模糊，得到 **ESM**。  
- **体积计算 (CS)**：CS 做密度估计与体积光照 (Density estimation and volume lighting)，输出 **Density & in-scattering**；再经 CS 求解散射方程 (Solving scattering equation)，得到 **Accumulated scattering**。  
- **应用 (PS)**：PS 使用 Accumulated scattering、Depth、Color 做 **Apply fog**，得到 **Final color buffer**。  

因此算法的第一步是对阴影信息进行下采样。

![第35页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0035.jpg)

---

## 第 36 页 · 算法细节：管线图 (Algorithm details)

流程图：Shadow cascades → **CS: Shadowmap downsample & blur** → ESM；随后 **CS: Density estimation and volume lighting** 产出 **Density & in-scattering**（3D 块）；再 **CS: Solving scattering equation** → **Accumulated scattering**；最后 **Depth buffer**、**Color buffer** 与 Accumulated scattering 进入 **PS: Apply fog** → **Final color buffer**。  
说明：下采样后的阴影信息就绪后，进行参与介质光照计算。

![第36页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0036.jpg)

---

## 第 37 页 · 密度估计与体积光照 (Density estimation and volume lighting)

**参与介质密度估计**：程序化 Perlin 噪声由风驱动动画、垂直衰减、散射系数存于体积纹理 A 通道。  
**光照内散射**：主光用 ESM 阴影、常数环境项、对点光源循环；结果存于体积纹理 RGB。  
密度与光照合并计算以略减带宽、分辨率一致；也可拆开完全解耦。密度为单八度 Perlin 噪声 + 风动画；垂直密度按指数衰减（重粒子如蒸汽倾向于近地面）。主光（日/月）、环境项与艺术家标记的、与视锥相交的动态点光累加，主光用 ESM；光照经密度调制后存 RGB。

![第37页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0037.jpg)

---

## 第 38 页 · 密度估计与体积光照（续）(Density estimation and volume lighting)

**AC4 中的光照内散射相位函数**：非基于物理、艺术驱动——**两种颜色**（太阳方向、反太阳方向）；图中圆盘示意太阳方向颜色（亮黄/橙）与反方向颜色（浅白/黄）。  
AC4 未用基于物理的相位函数，光照颜色渐变（沿太阳方向）完全由美术控制；形状除这两方向外为完全各向同性。任何相位函数都可在此 pass 中应用以获得更物理的结果（后文述）。

![第38页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0038.jpg)

---

## 第 39 页 · 算法细节：散射方程 (Algorithm details)

同第 35/36 页的算法细节流程图，本页突出**第三步**：**CS: Solving scattering equation**（亮绿框）。  
说明：第三步是通过在雾体积中**线性步进 (linearly marching)** 并做数值积分来**求解散射方程**。

![第39页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0039.jpg)

---

## 第 40 页 · 求解散射方程 (Solving scattering equation)

- 沿体积 **raymarch**：从相机出发沿射线步进。  
- **消光系数 (extinction)** 沿路径累加。  
- 用 **Beer-Lambert 定律**计算透射率，存于 Alpha。  
- 将**内散射光 (in-scattered)** 累加到 RGB。  
- 透射率也作用于内散射结果。  

外散射由 Beer-Lambert 描述（密度积分随距离的指数衰减）；内散射为至今内散射光的累加，并考虑基于距离的外散射。体积纹理中已有预计算并累加的内散射；因此对每条射线从相机出发沿体积步进，累加密度、内散射辐射与透射衰减即可。图中为光源照射沿射线的体积采样、raymarch 顺序示意。

![第40页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0040.jpg)

---

## 第 41 页 · 求解散射方程（实现）(Solving scattering equation)

**方法**：2D compute shader；暴力数值积分；沿深度切片步进并累积；使用 **UAV 写入**。  
Compute shader 在每一步累积内散射光与雾密度（数值解），得到体积纹理：每个纹素存有从相机到该 3D 点的内散射光量以及累积的参与介质密度（描述外散射量）。该数据可在前向（绘制物体时直接应用）或延迟（全屏 quad pass）方式下应用。

![第41页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0041.jpg)

---

## 第 42 页 · 求解散射方程（图示）(Solving scattering equation)

**图示说明**：左侧为 X–Z 平面上的 2D 网格，沿 Z 轴有若干离散采样点（竖列 '+'）；中间为 3D 体积中的 **Step 0** 与 **Step Z-1**，中间标注「X×Y 的 2D 计算着色器线程组」沿 Z 轴步进；右侧为沿 Z 累积后的 2D 结果，自上而下由白到黑渐变，表示内散射光与消光系数的累积。  
图中展示了 **2D 计算着色器线程组如何沿 3D 体积步进，逐层累积内散射光照与消光系数**。

![第42页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0042.jpg)

---

## 第 43 页 · 为什么不使用并行求和？(Why not parallel sum?)

**要点**：演讲者**尝试过**「**并行前缀和（扫描）**」(Parallel Prefix Sum / Scan) 方案，**但比暴力法慢了 20–30%**。原因包括：LDS 银行冲突 (LDS bank conflicts)、更差的着色器占用率 (worse shader occupancy)、缓存抖动/局部性差 (cache trashing / poor locality) 等。不过在某些情况下，对 **2D** 可能仍更合适。  
右侧示意图为 Harris 等人《使用 CUDA 的并行前缀和（扫描）》(GPU Gems 3) 中的算法流程：从输入 `x_0 … x_7` 经多阶段（d=1, 2, 3）并行组合与传播，得到前缀和。

![第43页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0043.jpg)

---

## 第 44 页 · 应用效果 (Applying effect)

**图示**：一条青色的视线 (view ray) 从左到右穿过场景；沿射线依次有**实心物体**（左侧方块）、**多个透明物体**（两团云状透明体）和右侧**实心星形**。射线下方用小块堆叠表示各段对应的**透射率与内散射**数据层（蓝/白矩形）。  
**说明**：由于存储了**整条视线的体积信息**，体积雾既可正确应用到**实心物体 (1)**，也可应用到**多个透明物体 (2)(3)**，它们都拥有正确且经过滤波的**透射率 (transmittance)** 与**内散射 (in-scattering)** 信息。图中也体现了**不透明与透明物体的多层叠加**以及**双线性 3D 纹理滤波**的运用。

![第44页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0044.jpg)

---

## 第 45 页 · 应用效果（实现）(Applying effect)

**要点**：计算像素在体积纹理中的位置；简单的 **3D 纹理查找**；在**前向 (forward)** 与**延迟 (deferred)** 中都很容易实现；兼容**任意数量的透明层**。  
**代码要点**：从 `VolumetricFogSampler` 采样得到 `scatteringInformation`（rgb=内散射，a=透射率），最终像素颜色为 `pixelColorWithoutFog * transmittance + inScattering`（即无雾颜色×透射率 + 内散射）。  
屏幕上最终应用效果在延迟和前向中都非常简单：无需特殊技巧，仅需对 3D 纹理的**双线性查找**和**融合乘加 (fused multiply-add)**；该效果与任意数量的透明物体层兼容。

![第45页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0045.jpg)

---

## 第 46 页 · 体积雾效果截图

**场景**：废弃/古老城镇街景，薄暮或清晨，被**体积雾**笼罩。远处建筑与棕榈树在雾中若隐若现；**光束（耶稣光）**从左上穿透雾气，形成明显体积光，增强深度与戏剧感。左侧有红棕色柱体与浅色教堂式建筑、棕榈树；右侧为木结构建筑与灯笼。地面有沙土、木板与杂物。  
本页用于展示体积雾与光线交互的**大气效果**及**深度感**。

![第46页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0046.jpg)

---

## 第 47 页 · Xbox One 上的性能 (Performance on Xbox One)

**性能数据**（总成本约 **1.1 ms**）：Shadowmap downsample 0.163 ms；Shadowmap blur 0.177 ms；**Lighting volume and calculating scattering**（光照体积并计算散射）**0.43 ms**（最贵）；Solving scattering equation 0.116 ms；Applying on screen（可与光照合并）0.247 ms。  
**说明**：总成本出奇地小；双倍分辨率下约 1.6 ms。最昂贵的部分是**构建密度并对体积做光照**（约 0.43 ms）；其余通道均低于 0.2 ms，「应用」通道若与光照合并则可视为「免费」。

![第47页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0047.jpg)

---

## 第 48 页 · 优化 (Optimizations)

**优化要点**：拆分通道以保持**寄存器计数 (register count)** 较低；**低分辨率 ESM 非常高效**；为**粒子与半透明物体**复用 ESM 阴影贴图；用体积雾的**光照体积**对粒子做光照与阴影；将**雾的应用**与**延迟光照**合并。  
**说明**：体积雾是受益于高波占用率与低 VGPR 的效果之一，拆分通道很有用。部分成本来自阴影贴图设置，将其复用于粒子、半透明/透明物体（如海洋）等低频光照很有意义。体积纹理中的光照与多光源遍历成本也可通过**体积纹理查找**复用。对于很远的雾距离，无需完整光照——可在一定距离后对阴影与光照做 **LOD**。

![第48页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0048.jpg)

---

## 第 49 页 · 优化（续）(Optimizations continued)

**要点**：在 **G-Buffer 渲染期间用异步计算 (async compute)** 执行雾效；**或**若引擎有 **tile MaxZ**，可用来做剔除（在光照/光线步进中 early out）；使用**聚类/分块局部光源 (clustered/tiled local lights)**。  
**说明**：可对体积纹理中位于实际渲染几何体背后的部分做 early out；若有**分层 Z 缓冲 (hierarchical Z buffer)**，体积雾可读取并用于剔除。不必遍历所有可见光，可用 **Forward+** 或 **Clustered shading** 做雾光剔除。若引擎无此类信息或收益不大（如大量室外远距场景），可用次世代主机的 **async compute** 在 shadowmaps 就绪后立即算雾——算法不依赖场景几何，可与 G-Buffer 等顶点密集通道并行，减轻带宽与 ALU 压力。

![第49页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0049.jpg)

---

## 第 50 页 · 延迟式光照注入 (Deferred-like light injection)

图：相机望向体积网格，两个黄色光源分别影响网格中不同单元格（黄框标出）。  
光照也可**注入体积**，作为前向光照的替代：计算光源的**体积包围盒**，仅对与之相交的体素做光照；可用 DX11/次世代主机的 **indirect dispatch** 实现。该优化对高 VGPR 消耗的复杂光源（如面光源）很有用。

![第50页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0050.jpg)

---

## 第 51 页 · Beyond AC4

**引言**：在演示最后一部分，将介绍 **AC4 之后**开发的体积雾扩展。  
**要点**：(1) 如何使效果**更基于物理**——缺失部分包括：对分析光源的**基于物理的相位函数**支持、**基于 SH 的光源**支持；(2) 通过**时间重投影 (temporal reprojection)** 与**抖动 (jittering)** 使效果更稳定。

![第51页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0051.jpg)

---

## 第 52 页 · 对环境光/全局光照（GI）的支持 (Support for ambient / GI)

**图示**：左图为**无雾场景**——拱形巷道光照充足、结构清晰；右图为**有雾但无天空光/GI**——同一巷道在雾中明显变暗，阴影区过暗、不真实，图中用红箭头标出变暗区域。  
**说明**：缺乏雾的**环境光/天空光**支持会导致阴影区**过度变暗**：有光线被外散射出去，却几乎没有内散射（因缺少光照），结果不真实；因此需要加入一定的 **GI**。

![第52页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0052.jpg)

---

## 第 53 页 · 对环境光/全局光照（GI）的支持（续）

**图示**：两幅并排的拱形巷道体积雾渲染。左图「Fog without sky light / GI = darkening」——阴影区雾过暗；右图「Fog with sky light」——加入天空光后雾在阴影区也更自然、明亮。  
**说明**：对比可见，**加入天空光照**能明显改善结果，并在阴影区域呈现正确的雾效。

![第53页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0053.jpg)

---

## 第 54 页 · 夸张的 GI (Exaggerated GI)

**场景**：狭窄走廊/小巷，远端强光源形成明显**体积光束（上帝光）**；受光处雾亮、侧面与阴影处雾更暗，呈现亮度与冷灰渐变。  
**说明**：在此截图（夸张的雾与 GI）中可见，**GI 颜色**会参与最终雾颜色，带来合理的**空间颜色变化**。

![第54页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0054.jpg)

---

## 第 55 页 · 环境光/GI 支持（球谐）(Ambient / GI support)

**要点**：(1) 为 **Henyey-Greenstein 相位函数**计算 **Zonal SH（区域球谐）**，再按视线方向旋转；二阶 SH 时等价于 `float4(1.0f, dir.y, dir.z, dir.x) * float4(1.0f, g, g, g)`。(2) 在给定点与相位函数下，计算环境光的 **SH 乘积积分**——每个颜色通道只需**一次点积**。  
**说明**：环境光/GI 常用**球谐 (Spherical Harmonics)** 存储，具有正交性、旋转不变性等性质；**Zonal SH** 易于旋转（尤其低阶），也适用于体积雾。HG 相位函数可简单展开为 Zonal SH，二阶时易旋转（见幻灯片代码）。体积雾响应即：旋转后的相位函数 SH 与存储的天空光/GI SH 的乘积积分；可在时间域做抖动与滤波。

![第55页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0055.jpg)

---

## 第 56 页 · 时间重投影 (Temporal reprojection)

**要点**：欠采样与走样仍可能出现；使用**时间抖动 (temporal jitter)** 与**重投影 (reprojection)**；这是常见的现代 **AA** 技术（如 Crysis 2/3、Killzone: Shadowfall、Assassin's Creed 4、Unreal Engine 4、Infamous: Second Son 等）；在体积雾中**比 2D 情况容易得多**。  
**说明**：尽管通过下采样 SM 表示花了不少力气减轻体积雾的走样与欠采样，仍可能有欠采样伪影。对策之一是**时间超采样**：每帧对采样模式做抖动，再用时间平滑与重投影合并多帧。该思路在 3D 体积中重投影比 2D 简单得多，故也适用于体积雾。

![第56页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0056.jpg)

---

## 第 57 页 · 2D 重投影面临的问题 (Problems with reprojection in 2D)

**图示**：左框「Frame n」中为带箭头的椭圆物体；右框「Frame n+1」中物体移动后出现红色「???」区域——未知像素、不正确重建数据。  
**说明**：2D 重投影通常有问题：物体移动会产生**遮挡/去遮挡**，既难检测运动（尤其在有抖动时），也难为产生的空洞找到合适填充数据，算法往往在**动态物体抖动**与**模糊/追踪/残影**之间难以取得平衡。

![第57页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0057.jpg)

---

## 第 58 页 · 体积重投影 (Volumetric reprojection)

**图示**：左图「Proper data stored」——视锥体内有红球、灰白柱体及青绿区域，表示数据有效；右图「Invalid reprojection」——视锥体旋转/移动后，仅超出原视锥体对齐体积的数据无效，其余后方数据仍正确。  
**说明**：在 **3D** 中容易得多：动态物体移动后所占空间虽可能无效，但其**后方所有数据**仍正确（在未做 early culling 时）；只有**原视锥体体积之外**的数据无效。但若使用强视点依赖、各向异性相位函数，仍可能出现明显重投影问题。

![第58页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0058.jpg)

---

## 第 59 页 · 样本抖动 (Sample jittering)

**图示**：左「Regular grid sampling」——3×3 网格中心规则采样点；右「Jittered grid sampling」——各格内采样点随机偏移。  
**要点**：用**噪声替代走样**；噪声更易滤波；可在**时间域**做抖动与滤波。  
**说明**：另一种抗走样手段是**空间网格上的样本抖动**。规则网格采样会产生难以对付的低频走样，抖动网格则将走样转为更高频噪声；噪声可用低分辨率核滤波/模糊。还可在时间域与空间域同时做抖动与滤波。

![第59页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0059.jpg)

---

## 第 60 页 · 子单元抖动/超采样 (Sub-cell jitter / supersampling)

**图示**：左图走廊/隧道体积雾场景，红箭头标出几何边缘处的**明显锯齿**；右图仅用**最简单的 1 样本时间抖动 + 重投影**，边缘伪影几乎全部消失，雾更平滑自然。  
**说明**：这两张截图表明，仅靠最简单的 1 样本时间抖动与重投影就能显著改善结果——几乎消除边缘伪影。未尝试更复杂的 3D 抖动网格采样模式，但未来值得研究，效果可能更好。

![第60页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0060.jpg)

---

## 第 61 页 · 特别鸣谢 (Special thanks)

**鸣谢**：Natalya Tatarchuk；育碧蒙特利尔 (Ubisoft Montreal) 的 Ulrich Haar、Stephen Hill、Lionel Berenguier、Typhaine Le Gallo、Alexandre Lahaise。

![第61页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0061.jpg)

---

## 第 62 页 · 问题？(Questions?)

**联系**：Contact me! Email: b_wronski@op.pl；WWW / slides / code: http://www.bartwronski.com；Twitter: @BartWronsk。

![第62页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0062.jpg)

---

## 第 63 页 · 参考文献 (References)

Hoffman, "Rendering Outdoor Light Scattering in Real Time", GDC 2002；Jarosz, "Efficient Monte Carlo Methods for Light Transport in Scattering Media"；Wenzel, "Real-time Atmospheric Effects in Games Revisited"；Wyman, Ramsey "Interactive Volumetric Shadows in Participating Media with Single-Scattering"；Yusov, "Practical Implementation of Light Scattering Effects Using Epipolar Sampling and 1D Min/Max Binary Trees"；Kaplanyan, "Light Propagation Volumes", Siggraph 2009；Sousa, "Crysis Next Gen Effects", GDC 2008；Myers, "Variance Shadow Mapping", NVIDIA；Annen et al, "Exponential Shadow Maps", Hasselt University；Harris et al, "Parallel Prefix Sum (Scan) with CUDA", GPU Gems 3；Wrenninge et al, "Volumetric Methods in Visual Effects", SIGGRAPH 2010；Bouthors et al, "Real-time realistic illumination and shading of stratiform clouds"；Bethell and Bergin, "The propagation of Lya in evolving protoplanetary disks"；Green, "Implementing Improved Perlin Noise", GPU Gems 2；Perlin, "Improving Noise".

![第63页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0063.jpg)

---

## 第 64 页 · 指数阴影贴图在体积雾中的应用 (Exponential Shadow Maps use in Volumetric Fog)

**(1) 阴影贴图降采样/转换到指数空间**：用 `GatherRed` 在四个偏移 `(0,0),(2,0),(0,2),(2,2)` 采样，对每样本乘 `EXPONENT` 后 `exp()` 累加，再与 `1/16` 点积写入 `OutputTextureESMShadowmap`。**(2) 可分离 11 像素宽盒式滤波器**：两次简单通道完成。**(3) 应用阴影贴图**：`receiver = exp(shadedPointShadowSpacePosition.z * EXPONENT)`，`occluder` 从 ESM 双线性采样，`shadow = saturate(occluder / receiver)`。

![第64页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0064.jpg)

---

## 第 65 页 · 求解散射方程（附录代码）(Solving scattering equation)

**RayMarchThroughVolume**：从 `InputTexture` 读 `dispatchThreadID.xy` 在 z=0 的 rgba 作为 `currentSliceValue`，写入输出；循环 z=1 到 VOLUME_DEPTH-1，每步读当前 z 的 `nextValue`，调用 `AccumulateScattering(currentSliceValue, nextValue)` 更新累积值并写回。即沿深度切片**暴力光线步进 (brute-force raymarching)** 累积散射。

![第65页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0065.jpg)

---

## 第 66 页 · 求解散射方程（附录公式）(Solving scattering equation)

**应用朗伯-比尔定律的一步**：`AccumulateScattering(colorAndDensityFront, colorAndDensityBack)` 中，`light = colorAndDensityFront.rgb + saturate(exp(-colorAndDensityFront.a)) * colorAndDensityBack.rgb`，返回 `float4(light, colorAndDensityFront.a + colorAndDensityBack.a)`（rgb=迄今内散射光，a=累积散射系数）。  
**写出最终散射值**：`WriteOutput(pos, colorAndDensity)` 将 `finalValue = float4(colorAndDensity.rgb, exp(-colorAndDensity.a))` 写入 `OutputTexture`（a 为外散射导致的消光）。

![第66页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0066.jpg)

---

## 第 67 页 · 可控密度 (Controllable density)

**密度可由美术主导**；**关卡上的密度图**（如沼泽、尘封建筑）；**粒子注入**（如烟雾云）；**体积形状注入**；影视/CGI 中已有类似做法——见 Wrenninge et al., Siggraph 2010。  
本方案中密度为简单动画 Perlin 噪声，但也可由美术任意控制：可在关卡上绘制、用于充满雾或散射粒子的区域（沼泽、尘埃建筑）；也可通过粒子系统或解析体积形状/力场动态注入。参见 Wrenninge et al. Siggraph 2010 了解影视工业中的早期做法。

![第67页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0067.jpg)

---

## PDF 内嵌插图（ilovepdf 提取）

以下为从 PDF 中提取的独立插图，按文件名数字顺序排列，便于与幻灯片中的图示对应。

**1**  
![img6](ilovepdf_images-extracted/img6.jpg)

**2**  
![img12](ilovepdf_images-extracted/img12.jpg)

**3**  
![img15](ilovepdf_images-extracted/img15.jpg)

**4**  
![img28](ilovepdf_images-extracted/img28.jpg)

**5**  
![img31](ilovepdf_images-extracted/img31.jpg)

**6**  
![img34](ilovepdf_images-extracted/img34.jpg)

**7**  
![img37](ilovepdf_images-extracted/img37.jpg)

**8**  
![img40](ilovepdf_images-extracted/img40.jpg)

**9**  
![img43](ilovepdf_images-extracted/img43.jpg)

**10**  
![img51](ilovepdf_images-extracted/img51.jpg)

**11**  
![img54](ilovepdf_images-extracted/img54.jpg)

**12**  
![img57](ilovepdf_images-extracted/img57.jpg)

**13**  
![img60](ilovepdf_images-extracted/img60.jpg)

**14**  
![img63](ilovepdf_images-extracted/img63.jpg)

**15**  
![img66](ilovepdf_images-extracted/img66.jpg)

**16**  
![img69](ilovepdf_images-extracted/img69.jpg)

**17**  
![img72](ilovepdf_images-extracted/img72.jpg)

**18**  
![img75](ilovepdf_images-extracted/img75.jpg)

**19**  
![img78](ilovepdf_images-extracted/img78.jpg)

**20**  
![img81](ilovepdf_images-extracted/img81.jpg)

**21**  
![img84](ilovepdf_images-extracted/img84.jpg)

**22**  
![img87](ilovepdf_images-extracted/img87.jpg)

**23**  
![img90](ilovepdf_images-extracted/img90.jpg)

**24**  
![img93](ilovepdf_images-extracted/img93.jpg)

**25**  
![img96](ilovepdf_images-extracted/img96.jpg)

**26**  
![img99](ilovepdf_images-extracted/img99.jpg)

**27**  
![img102](ilovepdf_images-extracted/img102.jpg)

**28**  
![img105](ilovepdf_images-extracted/img105.jpg)

**29**  
![img108](ilovepdf_images-extracted/img108.jpg)

**30**  
![img111](ilovepdf_images-extracted/img111.jpg)

**31**  
![img114](ilovepdf_images-extracted/img114.jpg)

**32**  
![img117](ilovepdf_images-extracted/img117.jpg)

**33**  
![img120](ilovepdf_images-extracted/img120.jpg)

**34**  
![img123](ilovepdf_images-extracted/img123.jpg)

**35**  
![img126](ilovepdf_images-extracted/img126.jpg)

**36**  
![img129](ilovepdf_images-extracted/img129.jpg)

**37**  
![img132](ilovepdf_images-extracted/img132.jpg)

**38**  
![img135](ilovepdf_images-extracted/img135.jpg)

**39**  
![img138](ilovepdf_images-extracted/img138.jpg)

**40**  
![img141](ilovepdf_images-extracted/img141.jpg)

**41**  
![img144](ilovepdf_images-extracted/img144.jpg)

**42**  
![img147](ilovepdf_images-extracted/img147.jpg)

**43**  
![img150](ilovepdf_images-extracted/img150.jpg)

**44**  
![img153](ilovepdf_images-extracted/img153.jpg)

**45**  
![img156](ilovepdf_images-extracted/img156.jpg)

**46**  
![img159](ilovepdf_images-extracted/img159.jpg)

**47**  
![img162](ilovepdf_images-extracted/img162.jpg)

**48**  
![img165](ilovepdf_images-extracted/img165.jpg)

**49**  
![img168](ilovepdf_images-extracted/img168.jpg)

**50**  
![img171](ilovepdf_images-extracted/img171.jpg)

**51**  
![img174](ilovepdf_images-extracted/img174.jpg)

**52**  
![img177](ilovepdf_images-extracted/img177.jpg)

**53**  
![img180](ilovepdf_images-extracted/img180.jpg)

**54**  
![img183](ilovepdf_images-extracted/img183.jpg)

**55**  
![img186](ilovepdf_images-extracted/img186.jpg)

**56**  
![img189](ilovepdf_images-extracted/img189.jpg)

**57**  
![img192](ilovepdf_images-extracted/img192.jpg)

**58**  
![img195](ilovepdf_images-extracted/img195.jpg)

**59**  
![img198](ilovepdf_images-extracted/img198.jpg)

**60**  
![img201](ilovepdf_images-extracted/img201.jpg)

**61**  
![img204](ilovepdf_images-extracted/img204.jpg)

**62**  
![img207](ilovepdf_images-extracted/img207.jpg)

**63**  
![img210](ilovepdf_images-extracted/img210.jpg)

**64**  
![img213](ilovepdf_images-extracted/img213.jpg)

**65**  
![img216](ilovepdf_images-extracted/img216.jpg)

**66**  
![img219](ilovepdf_images-extracted/img219.jpg)

**67**  
![img222](ilovepdf_images-extracted/img222.jpg)

---

*以上文字根据 PDF 幻灯片内容整理，插图路径相对于本文档所在目录。原 PDF：<https://bartwronski.com/wp-content/uploads/2014/08/bwronski_volumetric_fog_siggraph2014.pdf>*
