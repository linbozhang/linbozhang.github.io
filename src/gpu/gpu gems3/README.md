# GPU Gems 3 章节概要

以下为《GPU Gems 3》（2007）各章标题及中文概要，便于快速了解每章内容。

---

## Part I: Geometry（几何）

**Chapter 1. Generating Complex Procedural Terrains Using the GPU**  
用 GPU 生成复杂程序化地形：在 GPU 上通过噪声、分形、侵蚀等程序化方法生成地形高度与细节，支持大规模、可无限延伸的地形，并讨论与 LOD、流式加载的配合。

**Chapter 2. Animated Crowd Rendering**  
动画人群渲染：高效渲染大量角色（人群、军队），通过实例化、LOD、共享动画与贴图、GPU 蒙皮与剔除，在保持视觉多样性的同时控制 draw call 与三角形数。

**Chapter 3. DirectX 10 Blend Shapes: Breaking the Limits**  
DirectX 10 形态混合：突破旧有限制：利用 DX10 几何着色器与流输出等能力，实现更多、更灵活的 blend shapes（变形目标），用于面部与身体变形动画。

**Chapter 4. Next-Generation SpeedTree Rendering**  
下一代 SpeedTree 渲染：介绍 SpeedTree 在植被几何、LOD、风动、光照与阴影等方面的进阶技术，实现高质量、大规模植被渲染。

**Chapter 5. Generic Adaptive Mesh Refinement**  
通用自适应网格细化：在 GPU 上根据误差或视距对网格做自适应细分或简化，适用于地形、流体表面、等值面等需要局部加密的几何。

**Chapter 6. GPU-Generated Procedural Wind Animations for Trees**  
GPU 生成的树木程序化风动动画：在 GPU 上基于风场与树枝层级计算树木的摆动与弯曲，减少 CPU 与带宽，适用于大量树木实例。

**Chapter 7. Point-Based Visualization of Metaballs on a GPU**  
GPU 上 Metaball 的基于点可视化：用点精灵或点云在 GPU 上渲染隐式曲面（metaball），支持变形、融合与实时交互，用于有机体、流体等。

---

## Part II: Light and Shadows（光照与阴影）

**Chapter 8. Summed-Area Variance Shadow Maps**  
求和区域方差阴影图（SAVSM）：将方差阴影图（VSM）与求和区域表结合，把每个阴影 texel 视为深度分布而非单值，支持线性滤波、mipmap 与任意矩形滤波区域，减少光渗并实现柔和阴影。

**Chapter 9. Interactive Cinematic Relighting with Global Illumination**  
带全局光照的交互式电影级重光照：在保留场景几何与材质的前提下，实时改变光照并考虑间接光，用于预览与电影级交互式打光。

**Chapter 10. Parallel-Split Shadow Maps on Programmable GPUs**  
可编程 GPU 上的平行分割阴影图（PSSM）：将视锥沿深度平行分割为多层，每层独立渲染一张阴影图，提高近处阴影分辨率、减轻锯齿，适用于大场景实时阴影。

**Chapter 11. Efficient and Robust Shadow Volumes Using Hierarchical Occlusion Culling and Geometry Shaders**  
用层次遮挡剔除与几何着色器实现高效稳健的阴影体：结合层次遮挡剔除与几何着色器优化阴影体生成与渲染，在复杂场景下保持性能与稳定性。

**Chapter 12. High-Quality Ambient Occlusion**  
高质量环境光遮蔽：在实时管线中实现更高质量的 SSAO 或屏幕空间 AO，改善接触阴影与缝隙处的体积感，并讨论噪声、半径与性能权衡。

**Chapter 13. Volumetric Light Scattering as a Post-Process**  
作为后处理的体积光散射：在屏幕空间用后处理近似光线在大气中的散射（如 God rays），将解析日光散射与体积遮挡结合，适用于任意复杂场景的实时体积光效。

---

## Part III: Rendering（渲染）

**Chapter 14. Advanced Techniques for Realistic Real-Time Skin Rendering**  
真实感实时皮肤渲染的进阶技术：结合基于物理的 BRDF、半透明阴影图与纹理空间次表面散射，在实时下实现高真实度的人体皮肤外观。

**Chapter 15. Playable Universal Capture**  
可玩的通用捕捉：将《黑客帝国》式的多相机面部捕捉适配为实时方案：用多路高清视频记录面部动画，经 PCA 等压缩后在 GPU 上解压并驱动高细节面部贴图，保留细微表情与皱纹。

**Chapter 16. Vegetation Procedural Animation and Shading in Crysis**  
《孤岛危机》中的植被程序化动画与着色：Crytek 介绍如何在 GPU 上对大量植被实例做程序化风动（主干弯曲与叶片细节）与着色，风力按实例计算、顶点成本通过 GPU 保持恒定。

**Chapter 17. Robust Multiple Specular Reflections and Refractions**  
稳健的多重镜面反射与折射：用分层距离图（立方体贴图存颜色、距离与法线）在 GPU 上追踪二次光线，实现单次与多次反射折射，结合 ray marching 与割线搜索处理曲面与自反射。

**Chapter 18. Relaxed Cone Stepping for Relief Mapping**  
Relief 映射的松弛锥步进：在 cone stepping 与二分搜索之间取得平衡，高效求射线与高度场交点，为表面增加几何细节的同时减少早期 relief mapping 的走样与性能问题。

**Chapter 19. Deferred Shading in Tabula Rasa**  
《Tabula Rasa》中的延迟着色：介绍该 MMO 的延迟着色实现：几何与光照分离、多 pass 光照、G-Buffer 设计，并讨论不支持 alpha 混合、无硬件 MSAA、高带宽等限制与应对。

**Chapter 20. GPU-Based Importance Sampling**  
基于 GPU 的重要性采样：用蒙特卡洛重要性采样在 GPU 上对环境贴图积分，实现 glossy 物体的基于图像光照（IBL），单 pass、预计算少，适合实时反射与高光。

---

## Part IV: Image Effects（图像效果）

**Chapter 21. True Impostors**  
真· impostor：用始终面向相机的四边形与纹理定义体积，在像素着色器中做射线与体积求交，从任意视角得到正确几何、自阴影与反射折射，用极低多边形表现复杂模型。

**Chapter 22. Baking Normal Maps on the GPU**  
在 GPU 上烘焙法线贴图：将高模细节烘焙为法线贴图的计算放在 GPU 上执行，加速美术管线或运行时生成。

**Chapter 23. High-Speed, Off-Screen Particles**  
高速离屏粒子：将昂贵粒子渲染到低分辨率离屏目标，再合成到主画面，在保持视觉效果的同时降低 overdraw 与填充率压力。

**Chapter 24. The Importance of Being Linear**  
线性的重要性：阐述正确的 gamma 与线性空间：纹理与帧缓冲应在线性空间下进行光照与混合，输出时再做 gamma 校正，以得到正确的色彩与混合结果。

**Chapter 25. Rendering Vector Art on the GPU**  
在 GPU 上渲染矢量图：将参数曲线（如 Bézier）隐式化后在 GPU 上直接光栅化，实现与分辨率无关的矢量图渲染并支持抗锯齿。

**Chapter 26. Object Detection by Color: Using the GPU for Real-Time Video Image Processing**  
基于颜色的物体检测：用 GPU 做实时视频图像处理，通过像素着色器计算质心与面积等，按颜色跟踪物体，用于机器人、监控、游戏与交互。

**Chapter 27. Motion Blur as a Post-Processing Effect**  
作为后处理的运动模糊：在屏幕空间根据速度缓冲或运动向量做后处理运动模糊，在不增加几何复杂度的前提下增强动感。

**Chapter 28. Practical Post-Process Depth of Field**  
实用后处理景深：在屏幕空间根据深度与光圈形状模拟景深模糊，实现电影感焦点与虚化，并讨论性能与质量权衡。

---

## Part V: Physics Simulation（物理仿真）

**Chapter 29. Real-Time Rigid Body Simulation on GPUs**  
GPU 上的实时刚体仿真：将刚体表示为粒子集，在 GPU 上求解运动与碰撞，用速度换精度，并自然扩展到非刚体与流体等统一框架。

**Chapter 30. Real-Time Simulation and Rendering of 3D Fluids**  
3D 流体的实时仿真与渲染：在 GPU 上求解流体方程并渲染 3D 流体（烟雾、水等），给出游戏与交互中可用的完整方案。

**Chapter 31. Fast N-Body Simulation with CUDA**  
用 CUDA 实现快速 N 体仿真：在 CUDA 上高效实现 N 体问题（每体受其余所有体作用），性能超越优化过的 CPU 实现，用于天体、分子与粒子系统。

**Chapter 32. Broad-Phase Collision Detection with CUDA**  
用 CUDA 做粗测碰撞检测：在 GPU 上通过并行空间划分（如网格、BVH）快速排除不可能碰撞的物体对，为细测与物理响应提供候选。

**Chapter 33. LCP Algorithms for Collision Detection Using CUDA**  
用 CUDA 的 LCP 算法做碰撞检测：用线性互补问题（LCP）与 Lemke 互补主元算法在 GPU 上求解凸体碰撞检测，并涉及线性/二次规划与凸包等应用。

**Chapter 34. Signed Distance Fields Using Single-Pass GPU Scan Conversion of Tetrahedra**  
用四面体单遍 GPU 扫描转换生成有符号距离场：在 GPU 上通过四面体的单遍扫描转换高效计算 SDF，用于布料、多体动力学、可变形体与运动规划中的碰撞与查询。

**Chapter 35. Fast Virus Signature Matching on the GPU**  
GPU 上的快速病毒特征匹配：Juniper 等将病毒特征匹配实现为 GPU 上的并行过滤，在大量数据对象上同时匹配特征库，用于网络安全与扫描加速。

---

## Part VI: GPU Computing（GPU 计算）

**Chapter 36. AES Encryption and Decryption on the GPU**  
GPU 上的 AES 加解密：利用 GeForce 8 系列的整数与位运算以及 transform feedback 等能力，在 GPU 上实现 AES 流式加解密，相比 CPU 获得加速。

**Chapter 37. Efficient Random Number Generation and Application Using CUDA**  
用 CUDA 的高效随机数生成与应用：在 CUDA 上为蒙特卡洛等应用生成高质量随机数（含高斯分布），用于金融期权定价、仿真与采样。

**Chapter 38. Imaging Earth's Subsurface Using CUDA**  
用 CUDA 对地球地下成像：将地震或探地雷达等地下成像中的大规模计算（如逆问题、波动方程）移植到 CUDA，加速石油勘探与地质成像。

**Chapter 39. Parallel Prefix Sum (Scan) with CUDA**  
用 CUDA 实现并行前缀和（Scan）：介绍 GPU 上的全前缀和这一基础并行原语，用于排序、流压缩、radix sort、求和面积表及并行数据结构构建。

**Chapter 40. Incremental Computation of the Gaussian**  
高斯的增量计算：在 GPU 上高效增量更新高斯分布或相关统计量，用于实时跟踪、滤波与机器学习等需要递推高斯参数的场景。

**Chapter 41. Using the Geometry Shader for Compact and Variable-Length GPU Feedback**  
用几何着色器实现紧凑且可变长度的 GPU 反馈：利用几何着色器与流输出将可变长度的中间结果写回缓冲，避免多次 pass 与冗余，适用于粒子、裁剪与通用 GPU 计算的数据回写。

---

以上概要结合 NVIDIA GPU Gems 3 官网、O'Reilly 书籍目录及网络资料整理，供快速查阅每章主题与要点。
