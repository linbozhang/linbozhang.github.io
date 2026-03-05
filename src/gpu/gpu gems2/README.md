# GPU Gems 2 章节概要

以下为《GPU Gems 2: Programming Techniques for High-Performance Graphics and General-Purpose Computation》（2005）各章标题及中文概要，便于快速了解每章内容。

---

## Part I: Geometric Complexity（几何复杂度）

**Chapter 1. Toward Photorealism in Virtual Botany**  
虚拟植物向照片级真实感迈进：讨论在实时应用中渲染大量植物（树木、灌木、草地等）的几何、LOD、光照与材质策略，结合程序化与预计算以兼顾质量与性能。

**Chapter 2. Terrain Rendering Using GPU-Based Geometry Clipmaps**  
基于 GPU 几何 Clipmap 的地形渲染：将地形表示为围绕视点的多级 clipmap 环，在顶点着色器中采样高度与法线，实现大规模地形的流式渲染与 LOD，减少顶点数与带宽。

**Chapter 3. Inside Geometry Instancing**  
几何实例化深入解析：通过一次 Draw Call 绘制同一网格的多个实例，在顶点着色器中用实例 ID 取变换与参数，大幅降低 CPU 与 API 开销，适用于植被、建筑、人群等重复几何。

**Chapter 4. Segment Buffering**  
段缓冲：将几何按“段”组织并缓冲，用于高效批处理与剔除，减少状态切换与 draw call，适合大场景的静态或半静态内容。

**Chapter 5. Optimizing Resource Management with Multistreaming**  
用多流优化资源管理：利用多顶点流（multistreaming）分离静态与动态顶点数据，使 GPU 更高效地更新动画或变形部分，同时保持静态数据不变，降低带宽与延迟。

**Chapter 6. Hardware Occlusion Queries Made Useful**  
让硬件遮挡查询真正有用：解决朴素遮挡查询的两大问题——查询本身的开销与等待结果的延迟；通过上一帧结果复用、层次化场景（k-d 树或八叉树）减少查询次数并弱化延迟影响，适用于城市漫游等仅小部分可见的大场景。

**Chapter 7. Adaptive Tessellation of Subdivision Surfaces with Displacement Mapping**  
带位移贴图细分曲面的自适应细分：根据视距与曲率在 GPU 上对细分曲面做自适应细分并应用位移贴图，在保持轮廓平滑的同时增加局部几何细节。

**Chapter 8. Per-Pixel Displacement Mapping with Distance Functions**  
基于距离函数的逐像素位移贴图：在像素着色器中用距离函数（如 cone stepping、raymarching）沿高度场求交，实现无需额外几何的凹凸与镂空效果，是 relief/parallax 类技术的代表。

---

## Part II: Shading, Lighting, and Shadows（着色、光照与阴影）

**Chapter 9. Deferred Shading in S.T.A.L.K.E.R.**  
《潜行者》中的延迟着色：将几何与光照解耦，先渲染到 G-Buffer（位置、法线、材质等），再在屏幕空间对每光源做光照计算，支持大量光源与复杂材质，并讨论该游戏中的具体实现与权衡。

**Chapter 10. Real-Time Computation of Dynamic Irradiance Environment Maps**  
动态辐照环境图的实时计算：实时更新辐照环境图以反映场景变化（如移动物体、开关门），用于动态漫反射与环境光，结合球谐或立方体贴图等表示。

**Chapter 11. Approximate Bidirectional Texture Functions**  
近似双向纹理函数（BTF）：BTF 描述材质随视角与光照方向变化的外观；本章给出在实时渲染中近似 BTF 的压缩与采样策略，用于织物、鳞片等复杂外观。

**Chapter 12. Tile-Based Texture Mapping**  
基于瓦片的纹理映射：将大纹理或图集划分为瓦片，按需加载与缓存，减少显存占用并支持超大纹理或虚拟纹理的雏形思路。

**Chapter 13. Implementing the mental images Phenomena Renderer on the GPU**  
在 GPU 上实现 mental images 的 Phenomena 渲染器：将离线渲染器中的着色与现象（Phenomena）概念移植到实时 GPU 管线，兼顾艺术可控性与性能。

**Chapter 14. Dynamic Ambient Occlusion and Indirect Lighting**  
动态环境光遮蔽与间接光照：在动态场景中实时或近实时计算 AO 与简单间接光（如反射光、颜色渗透），常用屏幕空间或体素化等方法。

**Chapter 15. Blueprint Rendering and "Sketchy Drawings"**  
蓝图渲染与“草图式”绘图：用 shader 与后处理实现技术插图风格（线条、轮廓、剖面线、手绘感），用于说明性可视化或艺术风格。

**Chapter 16. Accurate Atmospheric Scattering**  
精确大气散射：实现基于物理的大气散射模型（Rayleigh、Mie 等），用于日出日落、体积雾、天空与远山的大气效果，提升开放世界的空间感。

**Chapter 17. Efficient Soft-Edged Shadows Using Pixel Shader Branching**  
用像素着色器分支实现高效软边阴影：在 PCF 或类似滤波中利用动态分支 early-out，在保证软阴影边缘质量的同时减少不必要的采样与计算。

**Chapter 18. Using Vertex Texture Displacement for Realistic Water Rendering**  
用顶点纹理位移实现真实感水面渲染：从高度图或物理波在顶点着色器中采样位移，驱动水面网格变形，结合法线贴图与反射折射实现实时水面。

**Chapter 19. Generic Refraction Simulation**  
通用折射模拟：在实时管线中模拟透明与半透明物体的折射（如玻璃、水），涉及环境采样、法线、厚度与色散等近似。

---

## Part III: High-Quality Rendering（高质量渲染）

**Chapter 20. Fast Third-Order Texture Filtering**  
快速三阶纹理滤波：用三次 B-spline 核实现三阶（tricubic）滤波，通过线性纹理采样组合将 64 项求和约简为少量 trilinear 采样，用于体渲染、隐式曲面曲率等需要高阶导数的场景。

**Chapter 21. High-Quality Antialiased Rasterization**  
高质量抗锯齿光栅化：在可编程管线中实现更高质量的几何抗锯齿（如覆盖、解析边缘、alpha 修正），超越简单 MSAA 的局限。

**Chapter 22. Fast Prefiltered Lines**  
快速预滤波线段：对线段进行预滤波或距离场表示，在 GPU 上实现高质量、可缩放的线框与矢量线渲染，减少锯齿与断裂。

**Chapter 23. Hair Animation and Rendering in the Nalu Demo**  
Nalu 演示中的头发动画与渲染：用少量“控制发丝”做动力学与碰撞，驱动大量发丝（如 4095 根、约 12 万顶点）的几何与渲染，采用线段图元与基于物理的次级运动，在保证视觉质量下控制性能。

**Chapter 24. Using Lookup Tables to Accelerate Color Transformations**  
用查找表加速色彩变换：将复杂颜色变换（如电影 LUT、校色、HDR 映射）预计算为 3D LUT，在 shader 中一次或少量采样完成，兼顾质量与速度。

**Chapter 25. GPU Image Processing in Apple's Motion**  
Apple Motion 中的 GPU 图像处理：介绍 Motion 等专业软件如何将滤镜、合成、调色等图像处理阶段映射到 GPU 流式架构，以加速非线性编辑与特效。

**Chapter 26. Implementing Improved Perlin Noise**  
实现改进版 Perlin 噪声：面向 GPU 的 Perlin 噪声实现，强调视觉质量与各向同性，用于程序化纹理、体密度、动画等。

**Chapter 27. Advanced High-Quality Filtering**  
进阶高质量滤波：讨论在实时渲染中实现更高质量的重建与滤波（如各向异性、锐化、专用核），用于纹理、阴影与后处理。

**Chapter 28. Mipmap-Level Measurement**  
Mipmap 层级测量：在 shader 中正确计算或估计当前采样对应的 mip 层级，用于避免过模糊或过锐、优化各向异性与 LOD 决策。

---

## Part IV: General-Purpose Computation on GPUs: A Primer（GPU 通用计算入门）

**Chapter 29. Streaming Architectures and Technology Trends**  
流式架构与技术趋势：介绍 GPU 作为流式、数据并行处理器的发展，以及带宽、延迟、编程模型等对 GPGPU 的影响。

**Chapter 30. The GeForce 6 Series GPU Architecture**  
GeForce 6 系列 GPU 架构：以 GeForce 6 为例讲解统一着色器、纹理单元、ROP、显存子系统等，为在 GPU 上做通用计算提供硬件背景。

**Chapter 31. Mapping Computational Concepts to GPUs**  
将计算概念映射到 GPU：把常见算法（如归约、扫描、排序、查找）映射到片段/顶点程序与多 pass 渲染，建立“计算即渲染”的思维。

**Chapter 32. Taking the Plunge into GPU Computing**  
投身 GPU 计算：从图形开发者角度切入 GPGPU，讨论数据布局、并行粒度、与 CPU 的协作以及常见陷阱。

**Chapter 33. Implementing Efficient Parallel Data Structures on GPUs**  
在 GPU 上实现高效并行数据结构：如并行树、网格、稀疏结构等，支持在 GPU 上高效进行碰撞、空间查询、粒子与流体等计算。

**Chapter 34. GPU Flow-Control Idioms**  
GPU 流程控制惯用法：在缺乏传统分支的早期硬件上用 predication、多 pass、分支合并等方式实现条件与循环，以及现代统一架构下的分支策略。

**Chapter 35. GPU Program Optimization**  
GPU 程序优化：从占用率、寄存器、纹理/显存访问、指令吞吐等方面分析并优化顶点与片段程序，提升图形与计算性能。

**Chapter 36. Stream Reduction Operations for GPGPU Applications**  
GPGPU 应用中的流归约操作：在 GPU 上高效实现 sum、max、min 等归约，作为排序、直方图、物理与 AI 等算法的基本构件。

---

## Part V: Image-Oriented Computing（面向图像的计算）

**Chapter 37. Octree Textures on the GPU**  
GPU 上的八叉树纹理：用八叉树在 GPU 上表示与采样稀疏体积或细节纹理，支持大范围与局部高分辨率，用于地形、云、全局光照等。

**Chapter 38. High-Quality Global Illumination Rendering Using Rasterization**  
用光栅化实现高质量全局光照渲染：不依赖光线追踪，而是用光栅化、多 pass、反射阴影图或类似技术近似间接光与焦散，在实时或近实时下得到高质量 GI。

**Chapter 39. Global Illumination Using Progressive Refinement Radiosity**  
用渐进式细化 Radiosity 的全局光照：在 GPU 上实现渐进式 radiosity，通过多轮发射与 gathering 逐步收敛漫反射间接光，用于预计算或动态场景的照明。

**Chapter 40. Computer Vision on the GPU**  
GPU 上的计算机视觉：利用 GPU 的流式与 SIMD 能力加速图像滤波、特征检测、光流、立体匹配等视觉任务，将底层运算交给 GPU、高层逻辑留给 CPU。

**Chapter 41. Deferred Filtering: Rendering from Difficult Data Formats**  
延迟滤波：从困难数据格式渲染：两遍法先将非常规数据（压缩、稀疏、复杂布局）重建为常规 2D 纹理，再利用硬件插值做高质量滤波，适用于体数据、云、爆炸等模拟与渲染。

**Chapter 42. Conservative Rasterization**  
保守光栅化：保证所有与三角形有交的像素都被覆盖（或反之），用于 GPU 上的碰撞检测、遮挡查询、体素化等需要几何覆盖一致性的应用。

---

## Part VI: Simulation and Numerical Algorithms（仿真与数值算法）

**Chapter 43. GPU Computing for Protein Structure Prediction**  
蛋白质结构预测中的 GPU 计算：将生物信息学中的蛋白质折叠或结构预测中的关键计算（如能量评估、搜索）移植到 GPU，利用并行性加速科学计算。

**Chapter 44. A GPU Framework for Solving Systems of Linear Equations**  
求解线性方程组的 GPU 框架：在 GPU 上实现迭代法（如 Jacobi、CG）或直接法求解大规模线性系统，为物理、仿真与数值模拟提供基础。

**Chapter 45. Options Pricing on the GPU**  
GPU 上的期权定价：用蒙特卡洛或树方法在 GPU 上并行定价金融期权，展示 GPGPU 在计算金融中的适用性。

**Chapter 46. Improved GPU Sorting**  
改进的 GPU 排序：通过数据无关的并行排序（如 bitonic merge sort）充分利用 GPU，满足可见性排序、物理空间结构等图形与仿真需求，并减少 CPU–GPU 数据传输。

**Chapter 47. Flow Simulation with Complex Boundaries**  
复杂边界下的流动仿真：在 GPU 上求解带复杂边界的流体或 Navier–Stokes 方程，用于烟雾、水、燃烧等效果。

**Chapter 48. Medical Image Reconstruction with the FFT**  
用 FFT 进行医学图像重建：利用 GPU 上的快速傅里叶变换加速 CT、MRI 等医学成像中的重建与滤波，缩短重建时间。

---

以上概要结合 NVIDIA GPU Gems 2 官网、O'Reilly 书籍目录及网络资料整理，供快速查阅每章主题与要点。
