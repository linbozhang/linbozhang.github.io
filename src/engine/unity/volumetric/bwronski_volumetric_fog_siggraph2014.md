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

## 第 8–9 页

（本页为散射与参与介质相关图示或公式，见下图。）

![第8页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0008.jpg)

![第9页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0009.jpg)

---

## 第 10 页 · 散射类型 (Different scattering types)

**Mie 散射**：较大粒子（如气溶胶、尘埃）。**各向异性**强，**前向瓣 (forward lobe)** 明显，吸收比例较高。  
**Rayleigh 散射**：极小粒子（如空气分子）。**各向同性**、均匀，但**与波长相关**，短波散射更强，吸收可忽略，常用来解释天空的蓝色。  
图中对比了两种散射的入射光、透射与出射散射方向。

![第10页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0010.jpg)

---

## 第 11 页

（本页为相位函数或散射公式相关，见下图。）

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

## 第 13–14 页

（本页为相位函数或散射模型图示，见下图。）

![第13页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0013.jpg)

![第14页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0014.jpg)

---

## 第 15 页 · 游戏中的近似 (Approximations in games)

两类常见近似：

- **后处理类 (Post-effect based)**：因 UE3、CryEngine 而流行，基于后处理与径向模糊的屏幕空间效果；观感可以很好，但光源不在屏幕内时效果会完全消失。  
- **光线步进 (Ray-marching)**：效果出色（尤其配合极线采样），但通常作用距离较短并有局限。  

配图引用：C. Wyman, S. Ramsey «Interactive Volumetric Shadows in Participating Media with Single-Scattering»。

![第15页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0015.jpg)

---

## 第 16–17 页

（本页为现有方案或 raymarching 示意图，见下图。）

![第16页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0016.jpg)

![第17页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0017.jpg)

---

## 第 18 页 · Volumetric Fog 方案引入

在既有启发与 raymarching 方案基础上，发展出新方案并命名为「Volumetric Fog」。本页为城镇/街道场景的体积雾效果图：建筑、树木与地面被雾与光轴填充，远处有 God rays。

![第18页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0018.jpg)

---

## 第 19 页

（本页为算法或管线概览，见下图。）

![第19页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0019.jpg)

---

## 第 20 页 · 多光源效果

实际运行截图：丛林场景中体积雾与**多光源**协同工作——包括方向光形成的光轴与场景中的点光源（黄色灯泡图标），雾在光源周围形成光晕。说明：该方案可连贯、正确、完善地支持多光源。

![第20页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0020.jpg)

---

## 第 21 页

（本页为体积雾管线或数据流，见下图。）

![第21页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0021.jpg)

---

## 第 22 页 · 算法概览 (Algorithm overview)

- 使用**体积纹理 (Volumetric textures)** 作为中间存储。  
- 使用 **Compute Shader** 与 **UAV (Unordered Access Views)** 进行高效的 raymarch 与写入。  

这样便于拆分 pass、独立调度，并以高效且方便的方式向 3D 纹理写入体积数据。

![第22页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0022.jpg)

---

## 第 23–24 页

（本页为算法步骤或体积布局示意，见下图。）

![第23页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0023.jpg)

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

## 第 26–29 页

（本页为体积格式、深度分布或光照注入相关，见下图。）

![第26页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0026.jpg)

![第27页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0027.jpg)

![第28页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0028.jpg)

![第29页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0029.jpg)

---

## 第 30 页 · 走样问题 (Aliasing problem)

图例说明：**低通滤波**如何减轻高频率源信息带来的**时间性走样/闪烁**。  
「Without low-pass filter」：帧 N 与 N+1 间采样位置或亮度变化导致明显闪烁与锯齿轮廓。  
「With low-pass filter」：滤波后采样周围有柔和晕斑，帧间更稳定，闪烁与锯齿轮廓减弱。

![第30页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0030.jpg)

---

## 第 31–34 页

（本页为时间滤波或实现细节，见下图。）

![第31页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0031.jpg)

![第32页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0032.jpg)

![第33页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0033.jpg)

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

## 第 36–39 页

（本页为密度估计、光照注入或散射步骤，见下图。）

![第36页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0036.jpg)

![第37页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0037.jpg)

![第38页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0038.jpg)

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

## 第 41–67 页（幻灯片图）

以下各页为实现细节、性能、结果对比、Beyond AC4 及总结等，保留原图供查阅。

![第41页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0041.jpg)

![第42页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0042.jpg)

![第43页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0043.jpg)

![第44页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0044.jpg)

![第45页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0045.jpg)

![第46页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0046.jpg)

![第47页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0047.jpg)

![第48页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0048.jpg)

![第49页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0049.jpg)

![第50页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0050.jpg)

![第51页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0051.jpg)

![第52页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0052.jpg)

![第53页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0053.jpg)

![第54页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0054.jpg)

![第55页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0055.jpg)

![第56页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0056.jpg)

![第57页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0057.jpg)

![第58页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0058.jpg)

![第59页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0059.jpg)

![第60页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0060.jpg)

![第61页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0061.jpg)

![第62页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0062.jpg)

![第63页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0063.jpg)

![第64页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0064.jpg)

![第65页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0065.jpg)

![第66页](./ilovepdf_pages-to-jpg/bwronski_volumetric_fog_siggraph2014_page-0066.jpg)

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
