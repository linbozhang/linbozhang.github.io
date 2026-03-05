# GPU Pro 系列章节概要

以下为 GPU Pro / GPU Zen 系列各册的章节标题及中文概要，保留英文标题并附正确章节序号，便于快速查阅。

---

## GPU Pro (2010)

### Mathematics（数学与色彩）

**Chapter 1. GPU Color Quantization** (Chi Sing Leung, Tze-Yui Ho, Yi Xiao)  
在 GPU 上实现颜色量化：将高色深图像或帧缓冲压缩为有限调色板，用于节省带宽、LUT 或艺术风格化，并利用并行性加速聚类与抖动等步骤。

**Chapter 2. Visualize Your Shadow Map Techniques** (Fan Zhang, Chong Zhao, Adrian Egli)  
阴影图技术可视化：通过调试视图与可视化工具直观展示阴影图、级联、滤波与遮挡结果，便于调优阴影质量与性能。

### Geometry Manipulation（几何处理）

**Chapter 3. As-Simple-As Possible Tessellation for Interactive Applications** (Tamy Boubekeur)  
交互式应用中尽可能简单的曲面细分：用最少复杂度在 GPU 上做自适应细分，兼顾平滑轮廓与实时性能，适合游戏与 DCC 预览。

**Chapter 4. Rule-based Geometry Synthesis in Real-time** (Milan Magdics, Gergely Klar)  
基于规则的实时几何合成：用规则与程序化方法在运行时生成建筑、植被等几何，减少预制作与存储，支持大场景变化。

**Chapter 5. GPU-based NURBS Geometry Evaluation and Rendering** (Graham Hemingway)  
基于 GPU 的 NURBS 几何求值与渲染：在着色器或计算管线中求值 NURBS 曲面并光栅化，实现高质量 CAD 风格曲面实时渲染。

**Chapter 6. Polygonal-Functional Hybrids for Computer Animation and Games** (D. Kravtsov, O. Fryazinov, V. Adzhiev, A. Pasko, P. Comninos)  
计算机动画与游戏中的多边形–函数混合：结合多边形网格与隐式/函数式表示，用于变形、布尔运算与有机体动画。

### Rendering Techniques（渲染技术）

**Chapter 7. Quad-tree Displacement Mapping with Height Blending** (Michał Drobot)  
带高度混合的四叉树位移贴图：用四叉树组织高度场并在 GPU 上做位移与混合，在保持细节的同时控制采样与 LOD。

**Chapter 8. NPR effects using the Geometry Shader** (Pedro Hermosilla, Pere-Pau Vazquez)  
用几何着色器实现 NPR 效果：在几何着色器中生成轮廓线、笔触或卡通风格几何，与光栅化管线结合实现非真实感渲染。

**Chapter 9. Alpha Blending as a Post-Process** (Benjamin Hathaway)  
作为后处理的 Alpha 混合：将透明物体写入额外缓冲，在屏幕空间按深度排序并合成，在固定管线限制下实现近似 OIT 或半透明效果。

**Chapter 10. Virtual Texture Mapping 101** (Matthaus G. Chajdas, Christian Eisenacher, Marc Stamminger, Sylvain Lefebvre)  
虚拟纹理映射入门：将超大纹理按需分页、流式加载并在 GPU 上做寻址与混合，实现超出显存的大规模纹理渲染。

**Chapter 11. Volume Decals** (Emil Persson)  
体积贴花：在场景中放置局部体积效果（如弹孔、污渍、烟雾），通过体采样或射线步进与场景几何结合，用于破坏与氛围。

### Global Illumination（全局光照）

**Chapter 12. Fast, Stencil-Based Multiresolution Splatting for Indirect Illumination** (Chris Wyman, Greg Nichols, Jeremy Shopf)  
基于 stencil 的快速多分辨率溅射间接光照：用多分辨率 splat 与 stencil 加速间接光注入与传播，在实时下近似多弹间接漫反射。

**Chapter 13. Screen-Space Directional Occlusion** (Thorsten Grosch, Tobias Ritschel)  
屏幕空间方向性遮蔽：在屏幕空间根据法线与深度估计方向性 AO，增强缝隙与接触处的体积感与方向性阴影。

**Chapter 14. Real-time multi-bounce ray-tracing with geometry impostors** (Peter Dancsik, Laszlo Szecsi)  
用几何 impostor 的实时多弹光线追踪：用简化的 impostor 几何做少量二次光线追踪，在可接受成本下得到多弹反射或间接光。

### Image Space（图像空间）

**Chapter 15. Anisotropic Kuwahara Filtering on the GPU** (Jan Eric Kyprianidis, Henry Kang, Jürgen Döllner)  
GPU 上的各向异性 Kuwahara 滤波：沿结构方向的自适应平滑，在保留边缘的同时产生绘画/油画风格，用于 NPR 与风格化。

**Chapter 16. Edge Anti-aliasing by Post-Processing** (Hugh Malan)  
后处理边缘抗锯齿：在屏幕空间检测几何边缘并做亚像素滤波或混合，作为 MSAA 的补充或替代以减轻锯齿。

**Chapter 17. Environment Mapping with Floyd-Steinberg Halftoning** (Laszlo Szirmay-Kalos, Laszlo Szecsi, Anton Penzov)  
带 Floyd-Steinberg 半调的环境映射：将环境贴图与半调网屏结合，实现印刷/点阵风格的反射与 NPR 效果。

**Chapter 18. Hierarchical Item Buffers for Granular Occlusion Culling** (Thomas Engelhardt, Carsten Dachsbacher)  
用于细粒度遮挡剔除的层次化物体缓冲：用层次化 ID/深度缓冲做逐物体或逐块遮挡查询，优化大场景的绘制顺序与剔除。

**Chapter 19. Realistic Depth-of-Field in Post-Production** (David Illes, Peter Horvath)  
后期制作中的真实感景深：在后期用深度与光圈模型模拟景深模糊，支持散景形状与焦点控制，用于电影感画面。

**Chapter 20. Real-Time Screen Space Cloud Lighting** (Kaori Kubota)  
实时屏幕空间云层光照：在屏幕空间对云或体积做光照计算，结合阴影与散射近似，用于飞行/开放世界中的天空与云。

**Chapter 21. Screen-Space Subsurface Scattering** (Jorge Jimenez, Diego Gutierrez)  
屏幕空间次表面散射：在屏幕空间对皮肤等半透明材质做模糊与颜色渗透近似，以较低成本实现可接受的 SSS 效果。

### Handheld Devices（手持设备）

**Chapter 22. Migration to OpenGL ES 2.0** (Ken Catterall)  
向 OpenGL ES 2.0 迁移：从固定管线或 ES 1.x 迁移到可编程着色器管线，讨论兼容性、精度与移动端最佳实践。

**Chapter 23. Touchscreen-based user interaction** (Andrea Bizzotto)  
基于触屏的用户交互：在 3D 应用中将触控、手势与相机控制结合，实现直观的移动端交互与 UI。

**Chapter 24. iPhone 3GS Graphics Development and Optimization Strategies** (Andrew Senior)  
iPhone 3GS 图形开发与优化策略：针对当时 iPhone GPU 的带宽、填充率与 API 限制，给出渲染与资源优化建议。

**Chapter 25. Optimizing a 3D UI Engine for Mobile Devices** (Hyunwoo Ki)  
为移动设备优化 3D UI 引擎：在移动端实现高效 3D 菜单、HUD 与界面渲染，平衡 draw call、纹理与 overdraw。

### Shadows（阴影）

**Chapter 26. Fast Conventional Shadow Filtering** (Holger Gruen)  
快速传统阴影滤波：在保持 PCF 等传统方法的前提下，通过采样模式、预滤波或硬件加速减少软阴影成本。

**Chapter 27. Hybrid Min-Max Plane-Based** (Holger Gruen)  
基于最小–最大平面的混合方法：用 min-max 层次或平面近似做阴影测试或遮挡，在软阴影与性能之间折中。

**Chapter 28. Shadow Mapping for Omni-Directional Light Using Tetrahedron Mapping** (Hung-Chien Liao)  
用四面体映射的全向光阴影图：将点光源的立方体阴影图打包为四面体布局，节省采样与带宽并简化 shader。

**Chapter 29. Screen Space Soft Shadows** (Jesus Gumbau, Miguel Chover, Mateu Sbert)  
屏幕空间软阴影：在屏幕空间根据遮挡距离或 penumbra 估计生成软边阴影，避免多采样阴影图的高成本。

### 3D Engine Design（3D 引擎设计）

**Chapter 30. Multi-Fragment Effects on the GPU using Bucket Sort** (Meng-Cheng Huang, Fang Liu, Xue-Hui Liu, En-Hua Wu)  
用 GPU 桶排序实现多片段效果：用桶排序或类似结构在 GPU 上按深度/材质组织片段，支持 OIT、多光源等多片段效果。

**Chapter 31. Parallelized Light Pre-Pass Rendering with the Cell Broadband Engine** (Steven Tovey, Stephen McAuley)  
在 Cell Broadband Engine 上并行化 Light Pre-Pass 渲染：将光照预通道路线适配到 Cell 的 SPU/PPU 架构，利用多核与 DMA。

**Chapter 32. Porting code between Direct3D 9 and OpenGL 2.0** (Wojciech Sterna)  
在 Direct3D 9 与 OpenGL 2.0 间移植代码：讨论两种 API 在状态、着色器、纹理与扩展上的对应关系与移植策略。

**Chapter 33. Practical Thread Rendering for DirectX 9** (David Pangerl)  
DirectX 9 下的实用毛发渲染：用线段、纹理与光照在 DX9 上实现头发或毛发，控制 fillrate 与视觉质量。

### Game Postmortems（游戏复盘）

**Chapter 34. Stylized Rendering in Spore** (Shalin Shodhan, Andrew Willmott)  
《孢子》中的风格化渲染：介绍该游戏的整体视觉风格、着色与后处理管线，以及如何用有限资源达成统一风格。

**Chapter 35. Rendering Techniques in Call of Juarez: Bound in Blood** (Paweł Rohleder, Maciej Jamrozik)  
《狂野西部：生死同盟》中的渲染技术：总结该作在西部场景、角色与光照上的关键渲染方案与优化。

**Chapter 36. Making it large, beautiful, fast and consistent – Lessons learned developing Just Cause 2** (Emil Persson)  
做大、做美、做快且一致——《正当防卫 2》开发经验：从渲染架构、LOD、光照与美术管线角度总结开放世界大场景的工程经验。

**Chapter 37. Destructible Volumetric Terrain** (Marek Rosa)  
可破坏体积地形：用体素或高度场表示地形并支持实时破坏与变形，用于《武装突袭》等军事/沙盒游戏。

### Beyond Pixels & Triangles（超越像素与三角形）

**Chapter 38. Parallelized Implementation of Universal Visual Computer** (Tze-Yui Ho, Ping-Man Lam, Chi-Sing Leung)  
通用视觉计算机的并行实现：将通用图像/视觉计算映射到 GPU 并行架构，用于非图形学的视觉与图像处理。

**Chapter 39. Accelerating Virtual Texturing using CUDA** (Charles-Frederik Hollemeersch, Bart Pieters, Peter Lambert, Rik Van de Walle)  
用 CUDA 加速虚拟纹理：在 GPU 计算管线中处理纹理分页、压缩与反馈，进一步加速虚拟纹理的更新与查找。

**Chapter 40. Efficient Rendering of Highly Detailed Volumetric Scenes With GigaVoxels** (Cyril Crassin, Fabrice Neyret, Miguel Sainz, Elmar Eisemann)  
用 GigaVoxels 高效渲染高细节体积场景：基于稀疏体素八叉树与锥追踪的体渲染框架，支持极大规模体积数据与光照的实时渲染。

**Chapter 41. Spatial Binning on the GPU** (Christopher Oat, Joshua Barczak, Jeremy Shopf)  
GPU 上的空间分箱：用 GPU 对粒子或图元做空间划分与分箱，为碰撞、排序或光照等后续 pass 提供高效数据结构。

**Chapter 42. Real-Time Interaction between Particles and Dynamic Mesh on GPU** (Vlad Alexandrov)  
GPU 上粒子与动态网格的实时交互：在 GPU 上同时更新粒子与可变形网格，并处理碰撞与力反馈，用于破碎、布料与特效。

---

## GPU Pro 2 (2011)

### Geometry Manipulation（几何处理）

**Chapter 1. Terrain and Ocean Rendering with Hardware Tessellation** (Xavier Bonaventura)  
用硬件曲面细分的地形与海洋渲染：利用 DX11 细分着色器生成自适应地形与海面网格，兼顾近处细节与远处性能。

**Chapter 2. Practical and Realistic Facial Wrinkles Animation** (Jorge Jimenez, Jose I. Echevarria, Christopher Oat, Diego Gutierrez)  
实用且真实的面部皱纹动画：根据表情或年龄在纹理空间或网格上驱动皱纹的生成与混合，增强角色面部表现力。

**Chapter 3. Procedural Content Generation on GPU** (Aleksander Netzel, Pawel Rohleder)  
GPU 上的程序化内容生成：在 GPU 上生成地形、植被或关卡片段，用于大世界或 Roguelike 的运行时内容扩展。

### Rendering Techniques（渲染技术）

**Chapter 4. Pre-Integrated Skin Shading** (Eric Penner, George Borshukov)  
预积分皮肤着色：将次表面散射在曲率–入射角空间预积分为查找表，实时查表实现柔和、真实的皮肤外观，避免昂贵 SSS 模拟。

**Chapter 5. Implementing Fur in Deferred Shading** (Donald Revie)  
在延迟着色中实现毛发：在 G-Buffer 与光照 pass 中支持多层毛发几何或 shell 渲染，与延迟管线兼容并控制 overdraw。

**Chapter 6. Large-scale terrain rendering for outdoor games** (Ferenc Pintér)  
户外游戏的大规模地形渲染：结合 clipmap、LOD、流式与遮挡剔除，实现开放世界地形的稳定帧率与视觉连续性。

**Chapter 7. Practical Morphological Anti-Aliasing** (Jorge Jimenez, Belen Masia, Jose I. Echevarria, Fernando Navarro, Diego Gutierrez)  
实用形态学抗锯齿（PMAA）：在屏幕空间根据形态学算子检测并平滑几何边缘，作为后处理 AA 的实用方案，平衡质量与性能。

**Chapter 8. Volume Decals** (Emil Persson)  
体积贴花：与 GPU Pro 1 同主题的进阶实现，在场景中放置局部体积效果并与光照、阴影集成。

### Global Illumination（全局光照）

**Chapter 9. Temporal Screen-Space Ambient Occlusion** (Oliver Mattausch, Daniel Scherzer, Michael Wimmer)  
时间性屏幕空间环境光遮蔽：在 SSAO 中引入时间滤波与重用，减少噪声与闪烁，在保持性能下提高 AO 稳定性。

**Chapter 10. Level-of-Detail and Streaming Optimized Irradiance Normal Mapping** (Ralf Habel, Anders Nilsson, Michael Wimmer)  
面向 LOD 与流式的辐照法线映射优化：预计算辐照与法线信息的 LOD 与流式加载策略，用于大场景的间接光与细节。

**Chapter 11. Real-Time One-bounce Indirect Illumination and Indirect Shadows using Ray-Tracing** (Holger Gruen)  
用光线追踪的实时单弹间接光照与间接阴影：在可接受成本下用少量射线实现单次反弹间接光与遮挡，提升场景真实感。

**Chapter 12. Real-Time Approximation of Light Transport in Translucent Homogenous Media** (Colin Barré-Brisebois, Marc Bouchard)  
均匀半透明介质中光传输的实时近似：用扩散或简化模型近似光在皮肤、大理石等介质内的传输，实现实时 SSS 或体积感。

**Chapter 13. Real-time diffuse Global Illumination with Temporally Coherent Light Propagation Volumes** (Anton Kaplanyan, Wolfgang Engel, Carsten Dachsbacher)  
时间连贯的光传播体积（LPV）实现实时漫反射全局光照：用球谐表示体素化辐射并在体积中传播，支持动态光源与物体的实时漫反射 GI，CryEngine 3 等引擎采用。

### Shadows（阴影）

**Chapter 14. Variance Shadow Maps Light-Bleeding Reduction Tricks** (Wojciech Sterna)  
方差阴影图光渗抑制技巧：在 VSM 基础上通过重映射、裁剪或混合减少光渗与漏光，提升软阴影视觉质量。

**Chapter 15. Fast Soft Shadows via Adaptive Shadow Maps** (Pavlo Turchyn)  
通过自适应阴影图实现快速软阴影：根据场景与视角自适应分配阴影图分辨率，在关键区域获得更细的软阴影。

**Chapter 16. Adaptive Volumetric Shadow Maps** (Marco Salvi, Kiril Vidimče, Andrew Lauritzen, Aaron Lefohn, Matt Pharr)  
自适应体积阴影图：用体积表示或层次化阴影图支持体积光、半透明与软阴影的更高精度与可扩展性。

**Chapter 17. Fast Soft Shadows with Temporal Coherence** (Daniel Scherzer, Michael Schwärzler, Oliver Mattausch)  
利用时间连贯性的快速软阴影：在帧间重用或外推软阴影信息，减少每帧采样与滤波成本。

**Chapter 18. MipMapped Screen Space Soft Shadows** (Alberto Aguado, Eugenia Montiel)  
Mipmap 屏幕空间软阴影：在屏幕空间软阴影中引入 mipmap 或层次化采样，根据距离与遮挡改善质量与性能。

### Handheld Devices（手持设备）

**Chapter 19. A Shader-Based E-Book Renderer** (Andrea Bizzotto)  
基于着色器的电子书渲染器：用 GPU 着色器实现文字排版、高亮与翻页效果，用于移动端阅读应用。

**Chapter 20. Post-Processing Effects on Mobile Devices** (Marco Weber, Peter Quayle)  
移动设备上的后处理效果：在 ES 2.0 等移动 API 上实现 Bloom、色调映射、简单 DoF 等后处理，并控制带宽与功耗。

**Chapter 21. Shader Based Water Effects** (Joe Davis, Ken Catterall)  
基于着色器的水面效果：在移动 GPU 上用顶点/片段着色器实现水面动画、反射与折射，兼顾效果与性能。

### 3D Engine Design（3D 引擎设计）

**Chapter 22. Practical, Dynamic Visibility for Games** (Stephen Hill, Daniel Collin)  
游戏中的实用动态可见性：结合遮挡剔除、Portal、PVS 或 GPU 查询，在动态场景中高效决定可见集合与绘制顺序。

**Chapter 23. Shader Amortization using Pixel Quad Message Passing** (Eric Penner)  
用像素四边形消息传递分摊着色器成本：在像素四边形内共享或传递中间结果，减少重复计算并优化占用率。

**Chapter 24. A Rendering Pipeline for Real-time Crowds** (Benjamín Hernández, Isaac Rudomin)  
实时人群渲染管线：用 LOD、实例化、共享动画与遮挡剔除渲染大量角色，用于人群模拟与大型场景。

### GPGPU（通用 GPU 计算）

**Chapter 25. 2D Distance Field Generation with the GPU** (Philip Rideout)  
用 GPU 生成 2D 距离场：在 GPU 上并行计算 2D 有符号距离场（SDF），用于矢量渲染、碰撞或 UI。

**Chapter 26. Order-Independent Transparency Using Per-Pixel Linked Lists in DirectX 11** (Nicolas Thibieroz)  
在 DirectX 11 中用每像素链表实现顺序无关透明（OIT）：用 UAV 与链表存储每像素的透明片段并排序合成，实现高质量 OIT。

**Chapter 27. Simple and Fast Fluid Flow Simulation on the GPU** (Martin Guay, Fabrice Colin, Richard Egli)  
GPU 上的简单快速流体模拟：用粒子或网格在 GPU 上求解简化流体方程，实现实时烟雾、水花等效果。

**Chapter 28. A Fast Poisson Solver for OpenCL using Multigrid Methods** (Sebastien Noury, Samuel Boivin, Olivier Le Maître)  
用 OpenCL 与多重网格法实现快速 Poisson 求解器：在 GPU 上求解 Poisson 方程，用于流体、扩散或投影步。

---

## GPU Pro 3 (2012)

### Geometry Manipulation（几何处理）

**Chapter 1. Vertex Shader Tessellation** (Holger Gruen)  
顶点着色器曲面细分：在顶点着色器阶段做简单细分或 LOD，在不支持硬件细分时增加几何细节或平滑轮廓。

**Chapter 2. Real-time Deformable Terrain Rendering** (Egor Yusov)  
实时可变形地形渲染：支持运行时变形、破坏或雕刻的地形表示与渲染，用于载具痕迹、爆炸坑等。

**Chapter 3. Optimized Stadium Crowd Rendering** (Alan Chambers)  
优化的体育场人群渲染：针对体育场等固定视角与大量观众，用 impostor、LOD 与动画简化实现高性能人群渲染。

**Chapter 4. Geometric Anti-Aliasing Methods** (Emil Persson)  
几何抗锯齿方法：在几何或光栅化阶段改善边缘质量，讨论覆盖、alpha 与硬件 AA 的配合与替代方案。

### Rendering（渲染）

**Chapter 5. Practical Elliptical Texture Filtering** (Pavlos Mavridis, Georgios Papaioannou)  
实用椭圆纹理滤波：根据投影后像素的椭圆形状做各向异性采样或滤波，减少斜视角下的纹理模糊。

**Chapter 6. An Approximation to the Chapman Grazing-Incidence Function for Atmospheric Scattering** (Christian Schüler)  
大气散射中 Chapman 掠入射函数的近似：用可计算的近似替代昂贵的大气函数，加速天空与大气散射的实时计算。

**Chapter 7. Volumetric Real-Time Water and Foam Rendering** (Daniel Scherzer, Florian Bagar, Oliver Mattausch)  
体积化实时水体与泡沫渲染：用体积表示或粒子表现水体与泡沫的飞溅与白沫，并与表面反射折射结合。

**Chapter 8. CryENGINE 3** (Tiago Sousa, Nick Kasyan, Nicolas Schulz)  
CryENGINE 3 渲染管线概览：介绍 CryEngine 3 的延迟光照、LPV 全局光照、地形与植被等核心渲染架构与实现要点。

**Chapter 9. Inexpensive Anti-Aliasing of Simple Objects** (Mikkel Gjol, Mark Gjol)  
简单物体的低成本抗锯齿：针对线条、符号等简单几何，用距离场或解析边缘实现高质量、低成本的 AA。

### Global Illumination Effects（全局光照效果）

**Chapter 10. Ray-traced Approximate Reflections Using a Grid of Oriented Splats** (Holger Gruen)  
用定向 splat 网格做光线追踪近似反射：用稀疏 splat 表示场景并追踪反射射线，在可接受成本下得到近似反射。

**Chapter 11. Screen-space Bent Cones: A Practical Approach** (Oliver Klehm, Tobias Ritschel, Elmar Eisemann, Hans-Peter Seidel)  
屏幕空间弯曲锥：实用方法：在屏幕空间用弯曲锥近似遮挡与间接光方向，实现实用的间接漫反射或 AO。

**Chapter 12. Real-time Near-field Global Illumination based on a Voxel Model** (Sinje Thiedemann, Niklas Henrich, Thorsten Grosch, Stefan Mueller)  
基于体素模型的实时近场全局光照：用体素化场景与锥追踪或辐射传播实现近场间接光，支持动态物体与光源。

### Shadows（阴影）

**Chapter 13. Efficient Online Visibility for Shadow Maps** (Oliver Mattausch, Jiri Bittner, Ari Silvnennoinen, Daniel Scherzer, Michael Wimmer)  
阴影图的高效在线可见性：在渲染阴影图时做在线遮挡剔除或层次化更新，减少冗余绘制并提高阴影图利用率。

**Chapter 14. Depth Rejected Gobo Shadows** (John White)  
深度拒绝的 Gobo 阴影：用投影纹理（gobo）配合深度测试实现图案化或复杂形状的阴影，用于树叶、格栅等。

### 3D Engine Design（3D 引擎设计）

**Chapter 15. Z3 Culling** (Pascal Gautron, Jean-Eudes Marvie, Gaël Sourimant)  
Z3 剔除：利用深度与层次信息做更激进的遮挡剔除，减少不可见物体的绘制与状态切换。

**Chapter 16. Quaternion-based rendering pipeline** (Dzmitry Malyshau)  
基于四元数的渲染管线：用四元数统一表示旋转与插值，简化动画、蒙皮与相机控制的数学与管线。

**Chapter 17. Implementing a Directionally Adaptive Edge AA Filter using DirectX 11** (Matthew Johnson)  
用 DirectX 11 实现方向自适应边缘 AA 滤波器：根据边缘方向选择滤波核或采样模式，提升后处理 AA 的质量。

**Chapter 18. Designing a Data-Driven Renderer** (Donal Revie)  
设计数据驱动的渲染器：用配置、脚本或资源驱动材质、pass 与管线组合，提高可扩展性与美术迭代效率。

### GPGPU（通用 GPU 计算）

**Chapter 19. Volumetric transparency with Per-Pixel Fragment Lists** (Laszlo Szecsi, Pal Barta, Balazs Kovacs)  
用每像素片段列表实现体积透明：在 UAV 中为每像素维护透明片段链表，支持体积与透明物体的正确合成与光照。

**Chapter 20. Practical Binary Surface and Solid Voxelization with Direct3D 11** (Michael Schwarz)  
用 Direct3D 11 实现实用二值表面与实体体素化：将三角网格体素化到 3D 纹理或缓冲，用于 GI、碰撞或体渲染。

**Chapter 21. Interactive Ray Tracing Using the Compute Shader in DirectX 11** (Arturo García, Francisco Avila, Sergio Murguía, Leo Reyes)  
在 DirectX 11 中用计算着色器做交互式光线追踪：用 Compute Shader 组织 BVH 遍历与着色，实现实时或近实时的光线追踪反射与阴影。

---

## GPU Pro 4 (2013)

### Geometry Manipulation（几何处理）

**Chapter 1. GPU Terrain Subdivision and Tessellation** (Benjamin Mistal)  
GPU 地形细分与曲面细分：在 GPU 上根据高度图与 LOD 规则做地形网格细分，与硬件 tessellation 结合实现大规模地形。

**Chapter 2. Introducing the Programmable Vertex Pulling Rendering Pipeline** (Christophe Riccio, Sean Lilley)  
可编程顶点拉取渲染管线介绍：将顶点数据存放在缓冲中，在顶点着色器内按索引“拉取”，提高灵活性与缓存利用率。

**Chapter 3. A WebGL Globe Rendering Pipeline** (Patrick Cozzi, Daniel Bagnell)  
WebGL 地球渲染管线：在浏览器中用 WebGL 渲染带地形、大气与 LOD 的交互式地球，用于地图与可视化。

### Rendering（渲染）

**Chapter 4. Practical Planar Reflections using Cubemaps and Image Proxies** (Sébastien Lagarde, Antoine Zanuttini)  
用立方体贴图与图像代理实现实用平面反射：用代理几何与立方体贴图或简化射线在实时下实现水面、地板等平面反射。

**Chapter 5. Real-Time Ptex and Vector Displacement** (Karl Hillesland)  
实时 Ptex 与向量位移：在 GPU 上支持 Ptex 无接缝纹理与向量位移贴图，提升角色与高模资产的细节与一致性。

**Chapter 6. Decoupled Deferred Shading on the GPU** (Gábor Liktor, Carsten Dachsbacher)  
GPU 上的解耦延迟着色：将几何、光照与材质解耦为独立 pass，支持更多光源与复杂材质的同时优化带宽与扩展性。

**Chapter 7. Tiled Forward Shading** (Markus Billeter, Ola Olsson, Ulf Assarsson)  
瓦片前向着色：按屏幕瓦片划分光源，在每个瓦片内做前向多光源着色，在保持前向优势的同时控制光源数量与成本。

**Chapter 8. Forward+: A Step Toward Film-Style Shading in Real Time** (Takahiro Harada, Jay McKee, Jason C. Yang)  
Forward+：向实时电影级着色迈进：结合瓦片光源分配与前向着色，支持大量光源与更复杂的材质模型，用于高质量实时渲染。

**Chapter 9. Progressive Screen-Space Multi-Channel Surface Voxelization** (Athanasios Gaitatzes, Georgios Papaioannou)  
渐进式屏幕空间多通道表面体素化：在屏幕空间将场景逐步体素化并写入多通道体数据，用于 GI、AO 或体渲染。

**Chapter 10. Rasterized Voxel-Based Dynamic Global Illumination** (Hawar Doghramachi)  
基于光栅化体素的动态全局光照：用体素化与光栅化（非射线）实现体素 GI 的注入与传播，支持动态场景的实时漫反射 GI。

### Image Space（图像空间）

**Chapter 11. The Skylands Depth-of-Field Shader** (Michael Bukowski, Padraic Hennessy, Brian Osman, Morgan McGuire)  
《Skylands》景深着色器：针对 2D/2.5D 或特定艺术风格的景深实现，控制散景形状与焦点过渡。

**Chapter 12. Simulating Partial Occlusion in Post-Processing Depth-of-Field Methods** (David C. Schedl, Michael Wimmer)  
后处理景深方法中模拟部分遮挡：在 DoF 后处理中考虑被遮挡物体的虚化与混合，减少错误的前后景混合。

**Chapter 13. Second-Depth Anti-Aliasing** (Emil Persson)  
第二深度抗锯齿：利用第二层深度或背面信息改善边缘与透明处的 AA，减少漏光与闪烁。

**Chapter 14. Practical Frame Buffer Compression** (Pavlos Mavridis, Georgios Papaioannou)  
实用帧缓冲压缩：在管线中压缩 G-Buffer 或中间缓冲，降低带宽与显存，并讨论解压与质量权衡。

**Chapter 15. Coherence-Enhancing Filtering on the GPU** (Jan Eric Kyprianidis, Henry Kang)  
GPU 上的相干增强滤波：在 GPU 上实现各向异性扩散或结构增强滤波，用于风格化、细节增强或 NPR。

### Shadows（阴影）

**Chapter 16. Real-Time Deep Shadow Maps** (René Fürst, Oliver Mattausch, Daniel Scherzer)  
实时深度阴影图：用多层或体积深度表示半透明与体积物体的阴影，支持头发、烟雾等的柔和体积阴影。

### Game Engine Design（游戏引擎设计）

**Chapter 17. An Aspect-Based Engine Architecture** (Donald Revie)  
基于方面的引擎架构：用方面（Aspect）或组件化设计组织渲染、物理与逻辑，提高模块化与可维护性。

**Chapter 18. Kinect Programming with Direct3D 11** (Jason Zink)  
用 Direct3D 11 进行 Kinect 编程：将 Kinect 深度与彩色流与 D3D11 渲染结合，实现体感交互与 3D 重建可视化。

**Chapter 19. A Pipeline for Authored Structural Damage** (Homam Bahnassi, Wessam Bahnassi)  
美术主导的结构破坏管线：用美术预制的破坏阶段与混合，实现建筑、载具等的分阶段破坏与塌陷效果。

### GPGPU（通用 GPU 计算）

**Chapter 20. Bit-Trail Traversal for Stackless LBVH on DirectCompute** (Sergio Murguía, Francisco Ávila, Leo Reyes, Arturo García)  
DirectCompute 上无栈 LBVH 的比特路径遍历：用短栈或比特栈在 GPU 上遍历 LBVH，用于光线追踪与碰撞检测。

**Chapter 21. Real-Time JPEG Compression using DirectCompute** (Stefan Petersson)  
用 DirectCompute 实现实时 JPEG 压缩：在 GPU 上并行执行 DCT、量化与熵编码，用于截图、流式或视频编码。

---

## GPU Pro 5 (2014)

### Rendering（渲染）

**Chapter 1. Per-pixel lists for Single Pass A-Buffer** (Sylvain Lefebvre, Samuel Hornus, Anass Lasram)  
单遍 A-Buffer 的每像素列表：在单次 pass 中为每像素维护片段列表并排序合成，实现高质量 OIT 与多片段效果。

**Chapter 2. Reducing Texture Memory Usage by 2-Channel Color Encoding** (Krzysztof Kluczek)  
用双通道颜色编码减少纹理内存：将 RGB 等压缩为两通道表示并在着色器中解码，在可接受质量下显著降低纹理占用。

**Chapter 3. GPU-accelerated Interactive Material Aging** (Tobias Günther, Kai Rohmer, Thorsten Grosch)  
GPU 加速的交互式材质老化：在 GPU 上模拟锈蚀、褪色、污渍等随时间变化的材质外观，用于叙事或环境叙事。

**Chapter 4. Simple Rasterization-Based Liquids** (Martin Guay)  
基于光栅化的简单液体：用高度场或表面网格的光栅化表示液体表面，配合简单物理实现实时水流与飞溅。

### Lighting（光照）

**Chapter 5. Physically Based Area Lights** (Michal Drobot)  
基于物理的面光源：用解析或预积分实现矩形、圆盘等面光源的漫反射与高光，提升室内与角色光照真实感。

**Chapter 6. High Performance Outdoor Light Scattering using Epipolar Sampling** (Egor Yusov)  
用极线采样的高性能户外光散射：沿极线采样大气散射积分，在保持体积光质量的同时大幅减少采样数与成本。

**Chapter 7. Volumetric Light Effects in Killzone Shadow Fall** (Nathan Vos)  
《杀戮地带：暗影坠落》中的体积光效果：介绍该作体积光、光轴与大气散射的管线与优化，实现下一代主机上的体积光照。

**Chapter 8. Hi-Z Screen-Space Cone-Traced Reflections** (Yasin Uludag)  
Hi-Z 屏幕空间锥追踪反射：用 mip 层级深度（Hi-Z）加速屏幕空间反射的射线步进，快速收敛反射交点并支持粗糙反射。

**Chapter 9. TressFX – Advanced Real-Time Hair Rendering** (Timothy Martin, Wolfgang Engel, Nicolas Thibieroz, Jason Yang, Jason Lacroix)  
TressFX 进阶实时头发渲染：AMD 的实时头发方案，涵盖几何、阴影、抗锯齿与光照，用于高质量角色头发。

**Chapter 10. Wire Anti-Aliasing** (Emil Persson)  
线框抗锯齿：针对线框或细线的抗锯齿与亚像素覆盖，改善技术可视化与 NPR 中的线条质量。

### Image Space（图像空间）

**Chapter 11. Screen Space Grass** (David Pangerl)  
屏幕空间草地：在屏幕空间用粒子或四边形渲染草地，与深度与法线结合实现廉价的大面积植被覆盖。

**Chapter 12. Screen Space Deformable Meshes via CSG with Per-Pixel Linked Lists** (João Raza, Gustavo Nunes)  
用每像素链表的 CSG 实现屏幕空间可变形网格：在屏幕空间用 CSG 与片段列表实现布尔与变形效果。

**Chapter 13. Bokeh Effects on the SPU** (Serge Bernier)  
SPU 上的散景效果：在 Cell 的 SPU 上实现散景形状的景深与光斑效果，用于电影感后期。

### Mobile Devices（移动设备）

**Chapter 14. Realistic Real-Time Skin Rendering on Mobile** (Renaldas Zioma, Ole Ciliox)  
移动端真实感实时皮肤渲染：在移动 GPU 上实现简化但有效的皮肤 SSS 与高光，兼顾质量与功耗。

**Chapter 15. Deferred Rendering Techniques on Mobile Devices** (Ashley Vaughan Smith)  
移动设备上的延迟渲染技术：将 G-Buffer 与光照 pass 适配到 ES 与移动带宽限制，实现移动端延迟着色。

**Chapter 16. Bandwidth Efficient Graphics with ARM Mali GPUs** (Marius Bjørge)  
ARM Mali GPU 上的带宽高效图形：针对 Mali 架构的带宽与 tile-based 特性，优化渲染顺序与缓冲使用。

**Chapter 17. Efficient Morph Target Animation using OpenGL ES 3.0** (James Lewis Jones)  
用 OpenGL ES 3.0 实现高效变形目标动画：在移动端用 morph target 与 ES 3.0 特性实现面部与身体变形动画。

**Chapter 18. Tiled Deferred Blending** (Ramses Ladlani)  
瓦片延迟混合：将透明或多片段合成按瓦片组织，在移动或带宽受限平台上降低 overdraw 与带宽。

**Chapter 19. Adaptive Scalable Texture Compression** (Stacy Smith)  
自适应可扩展纹理压缩：根据内容与视角选择块压缩格式与 Mip 级别，平衡质量与内存。

**Chapter 20. Optimising OpenCL kernels for the ARM Mali-T600 GPUs** (Johan Gronqvist, Anton Lokhmotov)  
为 ARM Mali-T600 优化 OpenCL 内核：针对 Mali 的线程与内存模型，优化 GPGPU 内核的占用率与访存。

### 3D Engine Design（3D 引擎设计）

**Chapter 21. Quaternions Revisited** (Peter Sikachev, Vladimir Egorov, Sergey Makeev)  
四元数再探：从数值稳定性、插值与管线集成角度重新讨论四元数在动画与渲染中的正确用法。

**Chapter 22. glTF: Designing an Open-Standard Runtime Asset Format** (Fabrice Robinet, Rémi Arnaud, Tony Parisi, Patrick Cozzi)  
glTF：设计开放标准的运行时资源格式：介绍 glTF 的设计目标、几何、材质与动画表示，作为 Web 与跨平台 3D 的交换与运行时格式。

**Chapter 23. Managing Transformations in Hierarchy** (Bartosz Chodorowski, Wojciech Sterna)  
层次变换管理：在引擎中高效管理与更新场景图、骨骼与实例的变换层次，避免重复计算与同步问题。

### Compute（计算）

**Chapter 24. Hair Simulation in TressFX** (Dongsoo Han)  
TressFX 中的头发模拟：在 GPU 上模拟头发的动力学、碰撞与风场，与 TressFX 渲染管线配合。

**Chapter 25. Object-Order Ray Tracing for Fully Dynamic Scenes** (Tobias Zirr, Hauke Rehfeld, Carsten Dachsbacher)  
全动态场景的物体序光线追踪：按物体或 BVH 节点顺序遍历并发射射线，支持每帧更新的动态场景的反射与阴影。

**Chapter 26. Quadtrees on the GPU** (Jonathan Dupuy, Jean-Claude Iehl, Pierre Poulin)  
GPU 上的四叉树：在 GPU 上构建、遍历或更新四叉树，用于 LOD、碰撞或地形。

**Chapter 27. Two-level Constraint Solver** (Takahiro Harada)  
两级约束求解器：将物理约束分解为局部与全局两级在 GPU 上并行求解，用于布料、绳索与刚体。

**Chapter 28. Non-Separable 2D, 3D and 4D Filtering with Cuda** (Anders Eklund, Paul Dufort)  
用 CUDA 实现不可分 2D/3D/4D 滤波：在 GPU 上高效实现广义高斯或自定义不可分卷积，用于医学成像与信号处理。

---

## GPU Pro 6 (2015)

### Geometry（几何）

**Chapter 1. Dynamic GPU Terrain** (David Pangerl)  
动态 GPU 地形：在 GPU 上支持运行时编辑、变形与流式加载的地形管线，用于开放世界与沙盒。

**Chapter 2. Bandwidth Efficient Procedural Meshes in the GPU via Tessellation** (Gustavo Bastos Nunes, João Lucas Guberman Raza)  
通过曲面细分在 GPU 上实现带宽高效的程序化网格：用细分着色器从紧凑描述生成几何，减少顶点数据与带宽。

**Chapter 3. Real-Time Deformation of Subdivision Surfaces on Object Collisions** (Henry Schaefer, Matthias Nießner, Benjamin Keinert, Marc Stamminger)  
物体碰撞时细分曲面的实时变形：在碰撞时更新细分曲面并保持平滑与连续性，用于可变形物体与物理交互。

**Chapter 4. Realistic Volumetric Explosions in Games** (Alex Dunn)  
游戏中真实感体积爆炸：用体渲染、噪声与光照模拟爆炸的火焰、烟雾与冲击波，用于特效与战斗。

### Rendering（渲染）

**Chapter 5. Next-Gen Rendering in Thief** (Peter Sikachev, Samuel Delmont, Uriel Doyon, Jean-Normand Bucci)  
《神偷》中的次世代渲染：介绍该作的 PBR、光照与后处理管线，以及如何在 stealth 游戏中平衡质量与性能。

**Chapter 6. Grass rendering and simulation with LOD** (Dongsoo Han, Hongwei Li)  
带 LOD 的草地渲染与模拟：对大面积草地做几何与动画 LOD，并结合风动与碰撞，保持视觉一致性与性能。

**Chapter 7. Hybrid Reconstruction Anti-aliasing** (Michał Drobot)  
混合重建抗锯齿：结合 MSAA、后处理与时间重建的混合 AA 方案，在质量与成本间取得平衡。

**Chapter 8. Real-time Rendering of Physically-Based Clouds using Pre-computed Scattering** (Egor Yusov)  
用预计算散射实现基于物理的实时云渲染：预计算云的多重散射查找表，实时查表实现高质量体积云。

**Chapter 9. Sparse Procedural Volume Rendering** (Doug McNabb)  
稀疏程序化体渲染：用稀疏体素或程序化密度表示体积，结合 raymarching 实现云、烟等的大规模体渲染。

### Lighting（光照）

**Chapter 10. Real-time lighting via Light Linked List** (Abdul Bezrati)  
通过光源链表实现实时光照：为每像素维护光源链表或紧凑列表，支持大量光源的前向或混合光照。

**Chapter 11. Deferred normalized irradiance probes** (John Huelin, Benjamin Rouveyrol, Bartłomiej Wroński)  
延迟归一化辐照探针：用延迟 pass 更新与采样辐照探针，实现动态场景的间接光与漫反射 GI。

**Chapter 12. Volumetric fog and lighting** (Bartłomiej Wroński)  
体积雾与光照：在体积中模拟雾、光轴与散射，与场景深度和光源结合，用于大气与室内体积效果。

**Chapter 13. Physically Based Light Probe Generation On GPU** (Ivan Spogreev)  
GPU 上基于物理的光照探针生成：在 GPU 上从场景几何与光源实时或预计算生成辐照或反射探针。

**Chapter 14. Real-time global illumination using slices** (Hugh Malan)  
用切片实现实时全局光照：用 2D 或分层切片表示与传播间接光，在可接受成本下实现实时漫反射 GI。

### Shadows（阴影）

**Chapter 15. Practical Screen-Space Soft Shadows** (Márton Tamás, Viktor Heisenberger)  
实用屏幕空间软阴影：在屏幕空间根据遮挡距离与光源大小估计半影，实现高质量软阴影并控制性能。

**Chapter 16. Tile-Based Omnidirectional Shadows** (Hawar Doghramachi)  
基于瓦片的全向阴影：将点光源的立方体阴影图按瓦片或层级组织，优化采样与缓存。

**Chapter 17. Shadow Map Silhouette Revectorization** (Vladimir Bondarev)  
阴影图轮廓重矢量化：从阴影图提取或优化轮廓边缘，用于软阴影滤波或阴影质量提升。

### Mobile Devices（移动设备）

**Chapter 18. Hybrid Ray Tracing on a PowerVR GPU** (Gareth Morgan)  
PowerVR GPU 上的混合光线追踪：在移动 GPU 上做有限范围的射线追踪（如反射、AO），与光栅化结合。

**Chapter 19. Implementing a GPU-only particles collision system with ASTC 3D textures and OpenGL ES 3.0** (Daniele Di Donato)  
用 ASTC 3D 纹理与 OpenGL ES 3.0 实现纯 GPU 粒子碰撞：在移动端用 3D 纹理存储空间划分或 SDF，实现粒子与场景的 GPU 端碰撞。

**Chapter 20. Animated Characters with Shell Fur for Mobile Devices** (Andrew Girdler, James L. Jones)  
移动端带壳毛发的动画角色：在移动平台上用多层 shell 渲染毛发或绒毛，与 LOD 和简化光照配合。

**Chapter 21. High Dynamic Range Computational Photography on mobile GPUs** (Simon McIntosh-Smith, Amir Chohan, Dan Curran, Anton Lokhmotov)  
移动 GPU 上的高动态范围计算摄影：在移动端实现 HDR 合并、色调映射或简单计算摄影管线。

### Compute（计算）

**Chapter 22. Compute-Based Tiled Culling** (Jason Stewart)  
基于计算着色器的瓦片剔除：在 Compute Shader 中做视锥与遮挡的瓦片级剔除，生成紧凑的绘制列表。

**Chapter 23. Rendering Vector Displacement Mapped Surfaces in a GPU Ray Tracer** (Takahiro Harada)  
在 GPU 光线追踪器中渲染向量位移映射表面：在射线与三角形求交时考虑向量位移，实现高细节的光线追踪表面。

**Chapter 24. Smooth Probabilistic Ambient Occlusion for Volume Rendering** (Thomas Kroes, Dirk Schut, Elmar Eisemann)  
体渲染的平滑概率环境光遮蔽：在体渲染中估计并应用 AO，增强体积的接触阴影与空间感。

### 3D Engine Design（3D 引擎设计）

**Chapter 25. Blockwise Linear Binary Grids for Fast Ray Casting Operations** (Holger Gruen)  
用于快速射线投射的分块线性二值网格：用压缩的二值或线性网格加速体素或 SDF 的射线求交。

**Chapter 26. Semantic based shader generation using Shader Shaker** (Michael Delva, Julien Hamaide, Ramses Ladlani)  
用 Shader Shaker 的基于语义的着色器生成：通过语义与节点图自动或半自动生成与变体管理着色器。

**Chapter 27. ANGLE: Bringing OpenGL ES to the Desktop** (Shannon Woods, Nicolas Capens, Jamie Madill, Geo Lang)  
ANGLE：将 OpenGL ES 带到桌面：介绍 ANGLE 将 ES 翻译为 D3D 或原生 GL 的架构，用于浏览器与跨平台。

---

## GPU Pro 7 (2016)

### Geometry Manipulation（几何处理）

**Chapter 1. Hardware-Tessellated Deformable Snow in Rise of the Tomb Raider** (Anton Kai Michels, Peter Sikachev)  
《古墓丽影：崛起》中硬件细分的可变形雪：用细分着色器与高度/法线贴图实现可踩踏、可形变的雪地表面。

**Chapter 2. Catmull Clark Subdivision Surfaces** (Wade Brainerd)  
Catmull-Clark 细分曲面：在 GPU 上实现或加速 Catmull-Clark 细分，用于高模角色与有机体渲染。

### Lighting（光照）

**Chapter 3. Clustered shading: Assigning lights using conservative rasterization in DirectX 12** (Kevin Örtegren, Emil Persson)  
簇着色：在 DirectX 12 中用保守光栅化分配光源：用保守光栅化将光源分配至屏幕空间簇，支持大量光源的延迟或前向光照。

**Chapter 4. Fine Pruned Tiled Light Lists** (Morten S. Mikkelsen)  
细剪枝瓦片光源列表：在瓦片光源列表基础上做更细粒度的剪枝与压缩，减少每像素光照成本。

**Chapter 5. Deferred Attribute Interpolation Shading** (Christoph Schied, Carsten Dachsbacher)  
延迟属性插值着色：将顶点属性插值推迟到光照或后处理阶段，节省 G-Buffer 带宽并支持更复杂的材质。

**Chapter 6. Real-time volumetric cloudscapes** (Andrew Schneider)  
实时体积云景：用体积噪声与预计算散射实现大规模、多层次的实时体积云天空。

### Rendering（渲染）

**Chapter 7. Adaptive Virtual Textures** (Ka Chen)  
自适应虚拟纹理：根据视角与使用频率动态调整虚拟纹理的页与分辨率，平衡质量与流式带宽。

**Chapter 8. Deferred Coarse Pixel Shading** (Rahul P. Sathe, Tomasz Janczak)  
延迟粗像素着色：在粗像素粒度执行部分着色或可见性，用于 VRS 或降低着色成本。

**Chapter 9. Progressive Rendering using Multi-Frame Sampling** (Daniel Limberger, Karsten Tausche, Johannes Linke, Jürgen Döllner)  
用多帧采样的渐进式渲染：在时间上累积采样（如路径追踪或高成本效果），实现交互式高质量或离线级预览。

### Mobile Devices（移动设备）

**Chapter 10. Efficient Soft Shadows Based on Static Local Cube map** (Sylvester Bala, Roberto Lopez Mendez)  
基于静态局部立方体贴图的高效软阴影：用预烘焙或局部立方体贴图近似区域光阴影，适合移动端性能约束。

### 3D Engine Design（3D 引擎设计）

**Chapter 11. Interactive Cinematic Particles** (Homam Bahnassi, Wessam Bahnassi)  
交互式电影级粒子：将粒子系统与镜头、叙事事件结合，实现可编排的电影感粒子与特效。

**Chapter 12. Real-time BC6H compression on GPU** (Krzysztof Narkowicz)  
GPU 上的实时 BC6H 压缩：在 GPU 上并行执行 BC6H 编码，用于 HDR 纹理的实时压缩或流式。

**Chapter 13. A 3D Visualization Tool used for Test Automation in the Forza Series** (Gustavo Bastos Nunes)  
《Forza》系列中用于测试自动化的 3D 可视化工具：用 3D 渲染与回放支持自动化测试与质量验证。

**Chapter 14. Semi-Static Load Balancing for Low Latency Ray Tracing on Heterogeneous Multiple GPUs** (Takahiro Harada)  
异构多 GPU 上低延迟光线追踪的半静态负载均衡：在多种 GPU 间分配射线追踪任务并做负载均衡，降低延迟与负载不均。

### Compute（计算）

**Chapter 15. Octree Mapping from a Depth Camera** (Dave Kotfis, Patrick Cozzi)  
从深度相机做八叉树建图：用 GPU 将深度图或点云转换为八叉树或体素表示，用于 SLAM 或 3D 重建。

**Chapter 16. Interactive Sparse Eulerian Fluid** (Alex Dunn)  
交互式稀疏欧拉流体：用稀疏存储与欧拉网格在 GPU 上模拟可交互的流体，支持障碍与力场。

---

## GPU Zen 1 (2017)

### Geometry Manipulation（几何处理）

**Chapter 1. Attributed Vertex Clouds** (Willy Scheibel, Stefan Buschmann, Matthias Trapp, Jürgen Döllner)  
属性顶点云：用带属性的点云表示几何或 LOD，支持灵活的属性插值与非传统渲染管线。

**Chapter 2. Rendering Convex Occluders with Inner Conservative Rasterization** (Marcus Svensson, Emil Persson)  
用内部保守光栅化渲染凸遮挡体：用保守光栅化正确标记凸体内部像素，用于遮挡剔除或体素化。

### Lighting（光照）

**Chapter 3. Rendering stable indirect illumination computed from reflective shadow maps** (Louis Bavoil, Holger Gruen)  
用反射阴影图计算并渲染稳定间接光照：从 RSM 发射与聚集间接光，并通过时间或空间滤波保持稳定性。

**Chapter 4. Real-Time Participating Media Effects Using Extruded Light Volumes** (Nathan Hoobler, Andrei Tatarinov, Alex Dunn)  
用挤出光体积实现实时参与介质效果：用沿光线的挤出体积表示体积光与散射，实现光轴与雾效。

### Rendering（渲染）

**Chapter 5. Deferred+: Next-Gen Culling and Rendering for Dawn Engine** (Hawar Doghramachi, Jean-Normand Bucci)  
Deferred+：Dawn 引擎的次世代剔除与渲染：介绍该引擎的延迟+管线、剔除与多光源架构。

**Chapter 6. Programmable per-pixel sample placement with conservative rasterizer** (Rahul P. Sathe)  
用保守光栅化实现可编程每像素采样放置：结合保守光栅化与自定义采样位置，用于 AA、遮挡或 VRS。

**Chapter 7. Mobile Toon Shading** (Felipe Lira, Flavio Villalva, Jesus Sosa, Kleverson Paixão, Teofilo Dutra)  
移动端卡通着色：在移动 GPU 上实现轮廓线与分阶着色的卡通风格，兼顾效果与性能。

**Chapter 8. High Quality GPU-efficient Image Detail Manipulation** (Kin-Ming Wong, Tien-Tsin Wong)  
高质量且 GPU 高效的图像细节操控：在 GPU 上做细节增强、去噪或风格化，保持质量与实时性。

**Chapter 9. Real-Time Linear-Light Shading with Linearly Transformed Cosines** (Eric Heitz, Stephen Hill)  
用线性变换余弦实现实时线光源着色：用 LTC 将面光源的 BRDF 积分预积分为查找表，实现精确的面光高光。

**Chapter 10. Profiling and Optimizing WebGL Application Using Google Chrome** (Gareth Morgan)  
用 Google Chrome 分析与优化 WebGL 应用：利用 Chrome 开发者工具对 WebGL 进行性能分析与优化。

### Screen-Space（屏幕空间）

**Chapter 11. Scalable Adaptive SSAO** (Filip Strugar)  
可扩展自适应 SSAO：根据场景与性能动态调整 SSAO 的半径、采样数与分辨率，实现可扩展的 AO。

**Chapter 12. Robust Screen Space Ambient Occlusion in 1 ms at 1080p on PS4** (Wojciech Sterna)  
在 PS4 上 1080p 1ms 内实现的稳健屏幕空间环境光遮蔽：针对主机的 SSAO 实现与优化，在严格预算内达到稳定质量。

**Chapter 13. Practical Gather-based Bokeh Depth of Field** (Wojciech Sterna)  
基于 gather 的实用散景景深：用 gather 与圆形/自定义核实现散景 DoF，控制质量与性能。

### Virtual Reality（虚拟现实）

**Chapter 14. Efficient Stereo and VR Rendering** (Iñigo Quilez)  
高效立体与 VR 渲染：利用双眼共享与重投影减少 VR 下的几何与着色成本。

**Chapter 15. Understanding, Measuring, and Analyzing VR Graphics Performance** (James Hughes, Reza Nourai, Ed Hutchins)  
理解、测量与分析 VR 图形性能：VR 特有的帧率、延迟与掉帧分析方法与指标。

### Compute（计算）

**Chapter 16. Optimizing the Graphics Pipeline with Compute** (Graham Wihlidal)  
用计算着色器优化图形管线：将剔除、排序、LOD 等步骤迁移到 Compute，减轻图形管线的负担。

**Chapter 17. Real Time Markov Decision Processes for Crowd Simulation** (Sergio Ruiz, Benjamin Hernandez)  
用于人群仿真的实时马尔可夫决策过程：用 MDP 在 GPU 上驱动大规模人群的决策与运动，用于人群模拟。

---

## GPU Zen 2 (2019)

### Rendering（渲染）

**Chapter 1. Adaptive GPU Tessellation with Compute Shaders** (Jad Khoury, Jonathan Dupuy, Christophe Riccio)  
用计算着色器实现自适应 GPU 曲面细分：在 Compute 中计算细分因子与 patch，再交给硬件细分，实现更灵活的地形或角色细分。

**Chapter 2. Applying Vectorized Visibility on All frequency Direct Illumination** (Ho Chun Leung, Tze Yui Ho, Zhenni Wang, Chi Sing Leung, Eric Wing Ming Wong)  
在全频率直接光照上应用向量化可见性：用 SIMD 或向量化加速可见性测试与直接光照计算。

**Chapter 3. Non-periodic Tiling of Noise-based Procedural Textures** (Aleksandr Kirillov)  
基于噪声的程序化纹理的非周期平铺：消除程序化噪声的重复图案，实现可无缝平铺的大尺度纹理。

**Chapter 4. Rendering Surgery Simulation with Vulkan** (Nicholas Milef, Di Qi, Suvranu De)  
用 Vulkan 渲染手术模拟：在 Vulkan 上实现软组织变形、切割与渲染，用于医学训练仿真。

**Chapter 5. Skinned Decals** (Hawar Doghramachi)  
蒙皮贴花：在蒙皮网格上正确放置与变形的贴花，用于角色伤害、污渍或定制化。

### Environmental Effects（环境效果）

**Chapter 6. Real-Time Fluid Simulation in Shadow of the Tomb Raider** (Peter Sikachev, Martin Palko, Alexandre Chekroun)  
《古墓丽影：暗影》中的实时流体模拟：介绍该作中水流、碰撞与渲染的流体方案。

**Chapter 7. Real-time Snow Deformation in Horizon Zero Dawn: The Frozen Wilds** (Kevin Örtegren)  
《地平线：零之曙光 冰尘雪野》中的实时雪变形：可踩踏、可形变雪地的实现与优化。

### Shadows（阴影）

**Chapter 8. Soft Shadow Approximation for Dappled Light Sources** (Mariano Merchante)  
斑驳光源的软阴影近似：对树叶、格栅等造成的斑驳光做软阴影近似，兼顾视觉效果与性能。

**Chapter 9. Parallax-Corrected Cached Shadow Maps** (Pavlo Turchyn)  
视差校正的缓存阴影图：对大场景或静态光缓存阴影图并做视差校正，减少重复计算与漏光。

### 3D Engine Design（3D 引擎设计）

**Chapter 10. Real-Time Layered Materials Compositing Using Spatial Clustering Encoding** (Sergey Makeev)  
用空间聚类编码实现实时分层材质合成：将多层材质按空间聚类编码与合成，支持复杂表面与混合。

**Chapter 11. Procedural Stochastic Textures by Tiling and Blending** (Thomas Deliot, Eric Heitz)  
通过平铺与混合实现程序化随机纹理：用小图块与随机混合生成大尺度无重复程序化纹理。

**Chapter 12. A Ray Casting Technique for Baked Texture Generation** (Alain Galvan, Jeff Russell)  
用于烘焙纹理生成的光线投射技术：用光线投射从高模或场景生成光照贴图、AO 等烘焙纹理。

**Chapter 13. Writing an efficient Vulkan renderer** (Arseny Kapoulkine)  
编写高效 Vulkan 渲染器：从同步、内存、描述符与 pass 设计角度讨论 Vulkan 渲染器的高效实现。

**Chapter 14. glTF – Runtime 3D Asset Delivery** (Marco Hutter)  
glTF：运行时 3D 资源交付：glTF 在运行时加载、解析与渲染中的最佳实践与扩展。

### Ray Tracing（光线追踪）

**Chapter 15. Real-Time Ray-Traced One-Bounce Caustics** (Holger Gruen)  
实时光线追踪单弹焦散：用光线追踪计算水或玻璃的单次折射/反射焦散，实现高质量焦散。

**Chapter 16. Adaptive Anti-Aliasing using Conservative Rasterization and GPU Ray Tracing** (Rahul Sathe, Holger Gruen, Adam Marrs, Josef Spjut, Morgan McGuire, Yury Uralsky)  
用保守光栅化与 GPU 光线追踪的自适应抗锯齿：结合光栅化与光线追踪的混合 AA，在边缘或高曲率处用射线改善质量。

---

## GPU Zen 3 (2020+)

### GPU-Driven Rendering（GPU 驱动渲染）

**Chapter 1. GPU-Driven Rendering in Assassin's Creed Mirage** (William Bussère, Nicolas Lopez)  
《刺客信条：幻景》中的 GPU 驱动渲染：用 GPU 端剔除、LOD 与 draw call 生成减少 CPU 负担，实现高密度场景。

**Chapter 2. GPU-Driven Curve Generation from Mesh Contour** (Wangziwei Jiang)  
从网格轮廓做 GPU 驱动曲线生成：在 GPU 上从网格轮廓提取或生成曲线，用于轮廓线或矢量导出。

**Chapter 3. GPU Readback Texture Streaming in Skull and Bones** (Malte Bennewitz, Kaori Kato)  
《碧海黑帆》中的 GPU 回读纹理流式：用 GPU 回读与反馈驱动虚拟纹理或流式加载，平衡延迟与带宽。

**Chapter 4. Triangle Visibility Buffer 2.0** (Manas Kulkarni, Wolfgang Engel)  
三角形可见性缓冲 2.0：用紧凑的可见性缓冲存储三角形 ID 与少量属性，延迟材质与光照到后段，减少带宽。

**Chapter 5. Resource Management with Frame Graph in Messiah** (Yuwen Wu)  
Messiah 引擎中基于 Frame Graph 的资源管理：用帧图管理渲染 pass、资源生命周期与同步，提高可读性与正确性。

**Chapter 6. Multi-mega Particle System** (Nicola Palomba, Wolfgang Engel)  
百万级粒子系统：在 GPU 上支持百万级粒子的模拟、排序与渲染，用于大规模特效与场景元素。

### Rendering and Simulation（渲染与仿真）

**Chapter 7. The Evolution of the Real-Time Lighting Pipeline in Cyberpunk 2077** (Jakub Knapik 等)  
《赛博朋克 2077》实时光照管线的演进：介绍该作的光照架构、全局光照、反射与夜之城视觉的工程实现。

**Chapter 8. Real-Time Ray Tracing of Large Voxel Scenes** (Russel Arbore, Jeffrey Liu, Aidan Wefel, Steven Gao, Eric Shaffer)  
大规模体素场景的实时光线追踪：对体素化大场景做光线追踪，用于体渲染、GI 或 Voxel 游戏。

**Chapter 9. Optimizing FSR 2 for Adreno** (Randall Rauwendaal)  
为 Adreno 优化 FSR 2：在 Qualcomm Adreno GPU 上针对 FSR 2 时间重建与 upscale 的优化与适配。

**Chapter 10. IBL-BRDF Multiple Importance Sampling for Stochastic Screen-Space Indirect Specular** (Soufiane KHIAT)  
用于随机屏幕空间间接高光的 IBL-BRDF 多重重要性采样：用 MIS 结合 IBL 与 BRDF 采样，改善屏幕空间间接高光的噪声与收敛。

**Chapter 11. Practical Clustered Forward Decals** (Kirill Bazhenov)  
实用簇前向贴花：在前向或簇着色管线中高效支持多贴花与光照，用于弹孔、涂鸦等。

**Chapter 12. Virtual Shadow Maps** (Matej Sakmary, Jake Ryan, Justin Hall, Alessio Lustri)  
虚拟阴影图：用虚拟化与分页实现极高分辨率的阴影图，支持大场景与近处细节，用于开放世界与 UE5 等。

**Chapter 13. Real-Time Simulation of Massive Crowds** (Tomer Weiss)  
大规模人群的实时仿真：在 GPU 上模拟与渲染极大规模人群的动画、避障与 LOD。

**Chapter 14. Diffuse Global Illumination** (Darius Bouma)  
漫反射全局光照：实时或近实时的漫反射 GI 方案总结与实现要点（LPV、SDF、光线追踪等）。

### Game Engine Design（游戏引擎设计）

**Chapter 15. GPU Capability Tracking and Configuration System** (Thibault Ober, Wolfgang Engel)  
GPU 能力追踪与配置系统：在引擎中检测 GPU 特性、驱动版本并据此选择渲染路径与质量档位。

**Chapter 16. The Forge Shader Language** (Manas Kulkarni, Wolfgang Engel)  
The Forge 着色器语言：跨 API 的着色器语言与编译管线，用于 The Forge 等跨平台渲染框架。

**Chapter 17. Simple Automatic Resource Synchronization Method for Vulkan** (Grigory Javadyan)  
简单的 Vulkan 资源自动同步方法：在 Vulkan 中通过少量规则或封装自动插入 barrier 与布局转换，减少同步错误。

### Tools of the Trade（工具与技法）

**Chapter 18. Differentiable Graphics with Slang.D for Appearance-Based Optimization** (Yong He 等)  
用 Slang.D 的可微图形做基于外观的优化：在可微渲染框架中优化材质、光照或几何以匹配目标外观。

**Chapter 19. DRToolkit: Boosting Rendering Performance Using Differentiable Rendering** (Chen Qiao 等)  
DRToolkit：用可微渲染提升渲染性能：通过可微渲染与自动微分优化着色、采样或管线参数。

**Chapter 20. Flowmap Baking with LBM-SWE** (Wei Li, Haozhe Su, Zherong Pan 等)  
用 LBM-SWE 烘焙流场图：用浅水方程或格子玻尔兹曼方法在 GPU 上烘焙水流或流动场，用于水面与流体动画。

**Chapter 21. Animating Water Using Profile Buffer** (Haozhe Su, Wei Li, Zherong Pan 等)  
用剖面缓冲动画化水面：用高度剖面或 2D 剖面驱动水面动画，实现高效的水波与涟漪。

**Chapter 22. Advanced Techniques for Radix Sort** (Atsushi Yoshimura, Chih-Chen Kao)  
基数排序的进阶技巧：在 GPU 上优化基数排序的位数、分组与内存访问，用于排序与键值对。

**Chapter 23. Two-Pass HZB Occlusion Culling** (Miloš Kruškonja)  
两遍 HZB 遮挡剔除：用层次化 Z buffer（HZB）在两遍中完成遮挡查询与物体剔除，减少绘制量。

**Chapter 24. Shader Server System** (Djordje Pepic)  
着色器服务器系统：集中管理、版本化与分发着色器，支持热重载与多平台构建。

---

以上概要结合 GPU Pro / GPU Zen 系列书籍目录、Routledge/Taylor & Francis、O'Reilly 及网络资料整理，供快速查阅各章主题与要点。
