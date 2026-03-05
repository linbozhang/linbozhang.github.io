# GPU Gems 1 章节概要

以下为《GPU Gems: Programming Techniques, Tips and Tricks for Real-Time Graphics》（GPU Gems 1，2004）各章标题及中文概要，便于快速了解每章内容。

---

## Part I: Natural Effects（自然效果）

**Chapter 1. Effective Water Simulation from Physical Models**  
基于物理模型的实时水面模拟：用正弦波叠加（从简单正弦到 Gerstner 波）近似水面高度与法线，结合几何网格起伏与动态法线贴图，在 GPU 上实现从池塘到海面的大范围水体，曾用于《Uru: Ages Beyond Myst》。

**Chapter 2. Rendering Water Caustics**  
实时渲染水下焦散：以美学与实现简便为主，用 Snell 定律作为物理基础，程序化生成焦散图案（光线经曲面折射/反射后汇聚形成的亮纹），适用于高层级着色语言与多数图形硬件。

**Chapter 3. Skin in the "Dawn" Demo**  
“Dawn” 演示中的皮肤渲染：介绍该 NVIDIA 演示里角色皮肤着色的实现思路与技巧。

**Chapter 4. Animation in the "Dawn" Demo**  
“Dawn” 演示中的动画：介绍 Dawn 角色动画在 GPU 上的实现方式。

**Chapter 5. Implementing Improved Perlin Noise**  
改进版 Perlin 噪声实现（作者 Ken Perlin）：面向硬件实现、更好视觉特性与跨平台一致性，给出在 3D 空间上的带限、视觉各向同性的伪随机噪声，可用于沙丘等自然效果。

**Chapter 6. Fire in the "Vulcan" Demo**  
“Vulcan” 演示中的火焰：为展示 GeForce FX 5900 能力而做的火焰、烟雾与辉光，涉及体纹理、渲染到纹理、后处理与多光源照明。

**Chapter 7. Rendering Countless Blades of Waving Grass**  
大量摇曳草叶的渲染：在 GPU 上高效渲染大面积草地并模拟风动与 LOD 等。

**Chapter 8. Simulating Diffraction**  
衍射模拟：在实时渲染中近似光波的衍射现象（如通过狭缝或边缘时的弯曲与干涉）。

---

## Part II: Lighting and Shadows（光照与阴影）

**Chapter 9. Efficient Shadow Volume Rendering**  
高效阴影体渲染：用 stencil buffer 标记阴影像素，实现点光、聚光、平行光下的锐利、逐像素精确阴影，适用于复杂光源与任意颜色、衰减及多种几何类型。

**Chapter 10. Cinematic Lighting**  
电影感光照：将 Pixar 的 “uberlight” 光照模型移植到 GPU，支持艺术家用 cookie、barn light 等手段直观塑造光源，服务于叙事与氛围而非严格物理。

**Chapter 11. Shadow Map Antialiasing**  
阴影图抗锯齿：针对阴影图放大时的锯齿，介绍百分比近距滤波（PCF）等思路，通过每像素多次采样并平均减轻边缘锯齿。

**Chapter 12. Omnidirectional Shadow Mapping**  
全向阴影贴图：从任意方向生成高质量阴影的 shadow mapping 方案，支持硬阴影与软阴影，可与硬件细分、GPU 动画等配合。

**Chapter 13. Generating Soft Shadows Using Occlusion Interval Maps**  
用遮挡区间图生成软阴影：通过 occlusion interval 表示半影，在静态户外场景中实现太阳等光源的柔和阴影过渡，曾用于 “Last Chance Gas” 演示。

**Chapter 14. Perspective Shadow Maps: Care and Feeding**  
透视阴影贴图（PSM）的用法与注意点：在投影空间重新分配阴影图分辨率（近大远小），以缓解大场景、广角或全向光下的阴影锯齿与失真。

**Chapter 15. Managing Visibility for Per-Pixel Lighting**  
逐像素光照中的可见性管理：在 per-pixel 光照管线中高效组织可见性查询（如遮挡、阴影），以支持多光源与复杂遮挡。

---

## Part III: Materials（材质）

**Chapter 16. Real-Time Approximations to Subsurface Scattering**  
实时的次表面散射近似：模拟光进入材质内部散射再出射的效果，用于皮肤、大理石等半透明材质，涵盖柔化光照、颜色渗透（如皮肤偏红）及简单近似（如 wrap lighting）。

**Chapter 17. Ambient Occlusion**  
环境光遮蔽（AO）：在 crevice 与接触处减弱环境光，增强体积感与接触阴影，本章介绍早期实时 AO 思路。

**Chapter 18. Spatial BRDFs**  
空间变化的 BRDF：BRDF 随表面位置或朝向变化，用于表现材质变化与细节。

**Chapter 19. Image-Based Lighting**  
基于图像的光照（IBL）：用局部化立方体贴图等实现更真实的反射、阴影以及漫反射/环境项，超越简单环境贴图。

**Chapter 20. Texture Bombing**  
纹理轰炸：程序化地将小图以不规则间隔铺满大面积；将 UV 空间划分成网格，在格内随机放置图案以减少重复感。

---

## Part IV: Image Processing（图像处理）

**Chapter 21. Real-Time Glow**  
实时辉光：为《Tron 2.0》开发的全屏大范围辉光方案，满足 60+ fps，并可泛化为景深、光散射、边缘检测等后处理。

**Chapter 22. Color Controls**  
色彩控制：在 GPU 上对画面做色调、饱和度、对比度等调节，用于调色与风格化。

**Chapter 23. Depth of Field: A Survey of Techniques**  
景深技术综述：介绍五类景深实现——光线追踪、累积缓冲、合成、前向映射 z-buffer、反向映射 z-buffer，并说明弥散圆（CoC）与焦内/焦外模糊的关系。

**Chapter 24. High-Quality Filtering**  
高质量滤波：在实时管线中实现高质量纹理与图像滤波，平衡性能与视觉质量。

**Chapter 25. Fast Filter-Width Estimates with Texture Maps**  
用纹理图快速估计滤波宽度：基于纹理或梯度快速得到各向异性滤波宽度，用于自适应采样与抗锯齿。

**Chapter 26. The OpenEXR Image File Format**  
OpenEXR 图像格式：工业光魔开发的高动态范围格式，支持 16/32 位浮点、无损压缩、任意通道（深度、法线等），与图形硬件帧缓冲兼容。

**Chapter 27. A Framework for Image Processing**  
图像处理框架：为后处理、合成、多 pass 效果设计可复用的图像处理管线与接口。

---

## Part V: Performance and Practicalities（性能与实践）

**Chapter 28. Graphics Pipeline Performance**  
图形管线性能：现代图形管线概览，以及定位瓶颈、进行性能测试与优化的流程。

**Chapter 29. Efficient Occlusion Culling**  
高效遮挡剔除：利用 GPU occlusion query 与 early-z 等机制，跳过视锥外或被遮挡的几何，并处理 CPU/GPU 异步带来的结果延迟问题。

**Chapter 30. The Design of FX Composer**  
FX Composer 的设计：NVIDIA 着色器编辑器的架构与设计思路，为美术与程序员提供 shader 编写与调试环境。

**Chapter 31. Using FX Composer**  
FX Composer 的使用：如何用 FX Composer 编写、调试与集成 shader。

**Chapter 32. An Introduction to Shader Interfaces**  
着色器接口入门：在应用与 shader、shader 与 shader 之间定义清晰接口与参数传递方式。

**Chapter 33. Converting Production RenderMan Shaders to Real-Time**  
将 RenderMan 生产级着色器转为实时：把离线 RenderMan 风格 shader 改写成适合 GPU 实时管线的形式（索尼影业 Imageworks 经验）。

**Chapter 34. Integrating Hardware Shading into Cinema 4D**  
在 Cinema 4D 中集成硬件着色：将 GPU 着色与实时预览整合进 DCC 工具的工作流。

**Chapter 35. Leveraging High-Quality Software Rendering Effects in Real-Time Applications**  
在实时应用中借鉴高质量软件渲染效果：把离线或软件渲染中的技术（光照、采样、合成等）简化为可实时运行的版本。

**Chapter 36. Integrating Shaders into Applications**  
在应用中集成着色器：从引擎或工具侧管理 shader 编译、变体、材质与管线集成的实践。

---

## Part VI: Beyond Triangles（超越三角形） / Appendix（附录）

**Chapter 37. A Toolkit for Computation on GPUs**  
GPU 计算工具包：早期 GPGPU 入门，介绍在 GPU 上做通用计算（如排序、搜索）的编程原语与思路，为“用 GPU 做非图形计算”打基础。

**Chapter 38. Fast Fluid Dynamics Simulation on the GPU**  
GPU 上的快速流体动力学模拟：基于 Stam 的“稳定流体”方法在 GPU 上实现稳定、快速的流体求解，相对 CPU 可获得数倍加速，是后续 3D 流体工作的基础参考。

**Chapter 39. Volume Rendering Techniques**  
体绘制技术：基于纹理的体绘制，将体数据映射为光学属性（颜色、不透明度）并沿视线积分，用于 3D 体数据可视化及云、烟、火焰等特效，可与多边形渲染结合并保持交互帧率。

**Chapter 40. Applying Real-Time Shading to 3D Ultrasound Visualization**  
将实时着色应用于 3D 超声可视化：在 GPU 上对“声学网格”形式的时变 3D 超声数据（4D 体）做体绘制与着色，解决非笛卡尔采样带来的可视化问题，并以胎儿超声为例展示效果。

**Chapter 41. Real-Time Stereograms**  
实时立体图：用 GPU 实时生成单图随机点立体图（SIRDS），在 2D 图像中编码立体信息，通过适当观看方式呈现隐藏 3D 场景。

**Chapter 42. Deformers**  
变形器：在 GPU 上执行顶点变形（deformer），用少量控制参数驱动复杂网格形变，用于动画与交互建模，定义为不增删几何的、确定性的逐顶点函数。

---

*以上概要结合 NVIDIA GPU Gems 官网章节介绍与相关书评整理，供快速查阅。完整内容与示例代码见原书及随书 CD / 在线资源。*
