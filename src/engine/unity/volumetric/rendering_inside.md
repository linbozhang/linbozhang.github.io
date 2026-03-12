# Rendering Inside（《Inside》渲染技术）

Playdead 出品游戏 **Inside**（及 Limbo）所用渲染技术的分享文稿，涉及体积雾、辉光与氛围光等。Unity 引擎。

---

## 第 1 页 · 标题页 (THE RENDERING OF INSIDE)

**THE RENDERING OF INSIDE** — **HIGH FIDELITY, LOW COMPLEXITY**  
**PLAYDEAD@GDC2016** · Mikkel Gjøl & Mikkel Svendsen  
url: github.com/playdeadgames/publications  
Twitter: @pixelmager @ikarosav  

背景：雾中高秆植物剪影与朦胧远景。

![第1页](./rendering_inside/rendering_inside_page-0001.jpg)

---

## 第 2 页 · Playdead / Inside

**PLAYDEAD**：左侧为《Limbo》风格截图（黑白、雾中小船与水面）；右侧为《Inside》截图（工业室内、红色「INSIDE」标题、穿白衣的人形队列、Unity 标志）。  
Trailer: http://playdead.com/inside/

![第2页](./rendering_inside/rendering_inside_page-0002.jpg)

---

## 第 3 页 · 议程 (Agenda)

**「接下来一小时的内容」**  
- 雾与体积效果 (Fog and volumetrics)  
- HDR 泛光 (HDR bloom)  
- 颜色条带与抖动 (Color-banding and dithering)  
- 投影贴花 (Projected Decals)：自定义光照、解析环境光遮蔽、屏幕空间反射  
- 水体渲染 (Water Rendering)  
- 效果拆解（眼糖果）  

「尤其是渲染方面、可能对他人有用的内容。」

![第3页](./rendering_inside/rendering_inside_page-0003.jpg)

---

## 第 4 页 · 体积雾参考

灰蓝色浓雾中的道路与电线杆，由近及远逐渐消失于雾中，展示**体积雾**对可见度与层次的影响。

![第4页](./rendering_inside/rendering_inside_page-0004.jpg)

---

## 第 5 页 · 美学、简洁、艺术 (Aesthetics, simplicity, art.)

**INSIDE Playdead**

**2.5D 横版、固定视角**：可完全控制玩家所见，从而**逐像素微调**；小团队非技术向美术，把精灵做到极致；艺术风格依赖细微细节，不容干扰主视觉、尽量减少干扰性伪影。

**技术目标**：当前主机 **1080p@60 Hz**；**自定义 Unity 5.0.x**（有源码）；**Light Prepass**。

![第5页](./rendering_inside/rendering_inside_page-0005.jpg)

---

## 第 6 页 · INSIDE 一帧：Light Prepass 渲染

**渲染流程**：basepass → lights → finalpass → translucency → posteffects。  
**缓冲生命周期**：depth normals（蓝）自 basepass 延续至 translucency；light（橙）自 lights 至 translucency；shadow maps 在 light 阶段内；framebuffer readback（红）在 translucency。  
说明：本质为**常规 Light Prepass**（Unity「Legacy deferred」）；translucency 中首次用到时做一次 grabpass（backbuffer 拷贝）；静态光阴影图可跨多帧；反射贴图在帧前渲染。

![第6页](./rendering_inside/rendering_inside_page-0006.jpg)

---

## 第 7 页 · 氛围感 (Atmospheric Atmosphere)

**副标题**：微妙、剪影、雾。  
三张场景：左—雾中沼泽/田野与植物剪影；中—工业/都市剪影、红衣小人与平台；右—多肢机械体剪影与室内雾光。  
「雾最终成为我们艺术风格的核心」「游戏里很多初期场景 literally 就是雾 + 剪影」。

![第7页](./rendering_inside/rendering_inside_page-0007.jpg)

---

## 第 8 页 · 雾与散射

雨雾中湿路、独行小人剪影、电线杆与远景；强调**雾与散射**对**表现力**的重要性。

![第8页](./rendering_inside/rendering_inside_page-0008.jpg)

---

## 第 9 页 · 雾效，无「散射」(Fog, no 'scattering')

**要点**：用雾**营造氛围**，不做复杂散射模拟；**简单线性雾 (Simple linear fog)**。  
唯一值得一提的做法：将雾**钳制到最大密度**，让高亮物体（车灯、聚光灯等）能「透出」——图中未展示，用于头灯/聚光灯等。  
配图：雨夜横版场景、小人剪影、电线杆与雾；右下小图为线性雾曲线（钳制到 1）。

![第9页](./rendering_inside/rendering_inside_page-0009.jpg)

---

## 第 11 页 · 作为大气散射的辉光 (Glow as Atmospheric Scattering)

**要点**：极宽的辉光（约半屏）；下采样后**多次模糊**，只需大范围模糊，每次迭代增大模糊半径（Kawase 风格）；用 **screen 混合模式** 合成。  
说明：早期由美术加入；老式低阈值「黄油镜头」LDR 辉光会让画面无意中发雾，但很适合**有意**做出雾蒙蒙效果。  
参考：Oat Steerable Streak Filter；GDC2003 DSTEAL。

![第11页](./rendering_inside/rendering_inside_page-0011.jpg)

---

## 第 10 页 · 雾 + 眩光 (fog + glare)

雨雾湿路、小人剪影与远处电线杆。  
**雾 + 眩光**：此处眩光主要由**大气散射 (atmospheric scattering)** 实现；（并加了一点暗角 vignetting）。

![第10页](./rendering_inside/rendering_inside_page-0010.jpg)

---

## 第 12 页 · HDR 辉光（两遍）

**口号**：「能花两倍价钱做两遍，何必只做一遍。」  
三图：左—推车上的暖黄发光体与泛光；中—角色持红色发光物、远处雾中光；右—橙色数字「19」与白框发光。  
需要**紧致的辉光 pass**；单遍加权合用时雾辉光与窄辉光互相干扰，故改为**两个独立 pass** 并分别调参。

![第12页](./rendering_inside/rendering_inside_page-0012.jpg)

---

## 第 13 页 · HDR 辉光 (HDR Glow)

**第二遍辉光，针对高亮发光物体。**  
**从遮罩物体产生的窄辉光**（橙色强调）：仅**自发光材质**（写入 alpha 通道）；遮罩值将 RGB 重映射到非线性强度 [1; 约 7]。  
中间 HDR 值编码为 [0;1] 定点：\( x/(x+1) \)。  
右图：上方为场景中多处红点发光与辉光；下方为仅发光点的遮罩视图。

![第13页](./rendering_inside/rendering_inside_page-0013.jpg)

---

## 第 14 页 · HDR 像素值 (HDR pixel values)

**HDR Glow**：用 LDR 颜色做 HDR 辉光会显得**奇怪**——泛光强度与自发光强度不匹配。应**将 HDR 值映射回屏幕**（线性映射，不做 tone mapping），**把源像素按 HDR 正确对待**。  
四格对比：LDR vs HDR 下「19」数字发光与场景中白灯/红光；HDR 版泛光更亮、更扩散。  
「若按某强度算 bloom，源像素也要用同一强度显示」「事后看显而易见，但很容易只加个 glow 强度滑条就不管——做对后视觉差异很大」。

![第14页](./rendering_inside/rendering_inside_page-0014.jpg)

---

## 第 15 页 · Sample Fitting（辉光滤波 [JIMENEZ14]）

**Sample Fitting** — glow-filter ala [JIMENEZ14]：**下采样时 13 tap 模糊**，**上采样时 9 tap 模糊**。Jimenez, Mittring (Samaritan)。  
右侧为多级分辨率金字塔示意图。链接：iryoku.com Next-Generation Post-Processing in Call of Duty: Advanced Warfare；Elemental Demo 技术 PDF。

![第15页](./rendering_inside/rendering_inside_page-0015.jpg)

---

## 第 16 页 · Sample Fitting（双线性与权重）

下采样：**13 次双线性采样覆盖 36 texel**，重叠 box + tent 近似高斯；**同一 texel 被多次采样**。上采样：9 tap 三角；**上采样时由美术给定权重**控制观感。  
**观察**：同一 texel 被重复采样；**改进**：用 9 次采样代替原 13 次，通过**拟合采样点以利用双线性滤波、使每个 texel 只被采样一次**。（本当对高斯分布做拟合而非对此近似采样……下次。）

![第16页](./rendering_inside/rendering_inside_page-0016.jpg)

---

## 第 17 页 · Sample Fitting 利用双线性滤波

**13 → 9 次双线性 tex 采样**；用简单 Python 脚本拟合（numpy.minimize）。**最坏权重近似误差 0.08**；**仅在恰好 ½ 分辨率时有效**；1920×1080 仅前 3 级 mip；提示：1920×1088 可得 6 级 mip；多数像素在前几级 mip，省得更多；若非精确半分辨率则退回完整 13 采样。  
角点采样双线性权重约 8% 误差，顶部采样精确；视觉上足够。因依赖双线性滤波，若非精确半分辨率会有严重问题，此时用完整 13 tap。（约省 0.1 ms。）

![第17页](./rendering_inside/rendering_inside_page-0017.jpg)

---

## 第 18 页 · 后处理配置 (Post Effects Setup)

**流程**：TAA (1.7 ms) → Wide Glow Blur（1/4 分辨率多遍模糊，0.6 ms）+ HDR Glow Blur（合计 0.4 ms）→ Combined Post-Pass（镜头畸变/色偏/辉光应用/「HDR」resolve，0.7 ms）。  
TAA 为 bloom 提供输入（也会对 bloom 遮罩做 AA）；两路辉光独立但为性能交错执行；「HDR resolve」来自辉光遮罩。

![第18页](./rendering_inside/rendering_inside_page-0018.jpg)

---

## 第 19 页

（本页内容见下图。）

![第19页](./rendering_inside/rendering_inside_page-0019.jpg)

---

## 第 20 页

（本页内容见下图。）

![第20页](./rendering_inside/rendering_inside_page-0020.jpg)

---

## 第 21 页

（本页内容见下图。）

![第21页](./rendering_inside/rendering_inside_page-0021.jpg)

---

## 第 22 页 · 体积光照 (Volumetric Lighting)

**「回到雾！」** 发现需要比**全局线性雾**更细的**局部控制**。**效果**：水下、手电筒、尘埃空气。四张图：倒挂角色与体积光柱、手电锥光穿雾、水下 god rays、车灯/聚光灯束穿尘。

![第22页](./rendering_inside/rendering_inside_page-0022.jpg)

---

## 第 23 页

（本页内容见下图。）

![第23页](./rendering_inside/rendering_inside_page-0023.jpg)

---

## 第 24 页 · 体积光照：沿相机射线 raymarch

**raymarch camera rays**：在阴影图投影空间内**步进到背景深度**；**每步**计算光照贡献：采样 shadowmap、cookie、falloff。  
示意图：相机、光源、兔子剪影与阴影；沿绿色相机射线上的红点为采样点。下图：手电锥光与体积雾实机效果。

![第24页](./rendering_inside/rendering_inside_page-0024.jpg)

---

## 第 25 页

（本页内容见下图。）

![第25页](./rendering_inside/rendering_inside_page-0025.jpg)

---

## 第 26 页 · 均匀采样 (Uniform Sampling)

**24 samples per pixel, 3.6 ms@1080p**。伪代码：沿射线 24 步累加 sampleLight(p)。优化到约 3.2 ms 仍偏慢，且**阶梯状伪影严重**；「又丑又慢……」

![第26页](./rendering_inside/rendering_inside_page-0026.jpg)

---

## 第 27 页

（本页内容见下图。）

![第27页](./rendering_inside/rendering_inside_page-0027.jpg)

---

## 第 28 页

（本页内容见下图。）

![第28页](./rendering_inside/rendering_inside_page-0028.jpg)

---

## 第 29 页

（本页内容见下图。）

![第29页](./rendering_inside/rendering_inside_page-0029.jpg)

---

## 第 30 页

（本页内容见下图。）

![第30页](./rendering_inside/rendering_inside_page-0030.jpg)

---

## 第 31 页

（本页内容见下图。）

![第31页](./rendering_inside/rendering_inside_page-0031.jpg)

---

## 第 32 页

（本页内容见下图。）

![第32页](./rendering_inside/rendering_inside_page-0032.jpg)

---

## 第 33 页

（本页内容见下图。）

![第33页](./rendering_inside/rendering_inside_page-0033.jpg)

---

## 第 34 页

（本页内容见下图。）

![第34页](./rendering_inside/rendering_inside_page-0034.jpg)

---

## 第 35 页

（本页内容见下图。）

![第35页](./rendering_inside/rendering_inside_page-0035.jpg)

---

## 第 36 页

（本页内容见下图。）

![第36页](./rendering_inside/rendering_inside_page-0036.jpg)

---

## 第 37 页

（本页内容见下图。）

![第37页](./rendering_inside/rendering_inside_page-0037.jpg)

---

## 第 38 页

（本页内容见下图。）

![第38页](./rendering_inside/rendering_inside_page-0038.jpg)

---

## 第 39 页

（本页内容见下图。）

![第39页](./rendering_inside/rendering_inside_page-0039.jpg)

---

## 第 40 页

（本页内容见下图。）

![第40页](./rendering_inside/rendering_inside_page-0040.jpg)


---

## 第 41 页

（本页内容见下图。）

![第41页](./rendering_inside/rendering_inside_page-0041.jpg)

---

## 第 42 页

（本页内容见下图。）

![第42页](./rendering_inside/rendering_inside_page-0042.jpg)
---

## 第 43 页

（本页内容见下图。）

![第43页](./rendering_inside/rendering_inside_page-0043.jpg)
---

## 第 44 页

（本页内容见下图。）

![第44页](./rendering_inside/rendering_inside_page-0044.jpg)
---

## 第 45 页

（本页内容见下图。）

![第45页](./rendering_inside/rendering_inside_page-0045.jpg)
---

## 第 46 页

（本页内容见下图。）

![第46页](./rendering_inside/rendering_inside_page-0046.jpg)
---

## 第 47 页

（本页内容见下图。）

![第47页](./rendering_inside/rendering_inside_page-0047.jpg)
---

## 第 48 页

（本页内容见下图。）

![第48页](./rendering_inside/rendering_inside_page-0048.jpg)
---

## 第 49 页

（本页内容见下图。）

![第49页](./rendering_inside/rendering_inside_page-0049.jpg)
---

## 第 50 页

（本页内容见下图。）

![第50页](./rendering_inside/rendering_inside_page-0050.jpg)
---

## 第 51 页

（本页内容见下图。）

![第51页](./rendering_inside/rendering_inside_page-0051.jpg)
---

## 第 52 页

（本页内容见下图。）

![第52页](./rendering_inside/rendering_inside_page-0052.jpg)
---

## 第 53 页

（本页内容见下图。）

![第53页](./rendering_inside/rendering_inside_page-0053.jpg)
---

## 第 54 页

（本页内容见下图。）

![第54页](./rendering_inside/rendering_inside_page-0054.jpg)
---

## 第 55 页

（本页内容见下图。）

![第55页](./rendering_inside/rendering_inside_page-0055.jpg)
---

## 第 56 页

（本页内容见下图。）

![第56页](./rendering_inside/rendering_inside_page-0056.jpg)
---

## 第 57 页

（本页内容见下图。）

![第57页](./rendering_inside/rendering_inside_page-0057.jpg)
---

## 第 58 页

（本页内容见下图。）

![第58页](./rendering_inside/rendering_inside_page-0058.jpg)
---

## 第 59 页

（本页内容见下图。）

![第59页](./rendering_inside/rendering_inside_page-0059.jpg)
---

## 第 60 页

（本页内容见下图。）

![第60页](./rendering_inside/rendering_inside_page-0060.jpg)
---

## 第 61 页

（本页内容见下图。）

![第61页](./rendering_inside/rendering_inside_page-0061.jpg)
---

## 第 62 页

（本页内容见下图。）

![第62页](./rendering_inside/rendering_inside_page-0062.jpg)
---

## 第 63 页

（本页内容见下图。）

![第63页](./rendering_inside/rendering_inside_page-0063.jpg)
---

## 第 64 页

（本页内容见下图。）

![第64页](./rendering_inside/rendering_inside_page-0064.jpg)
---

## 第 65 页

（本页内容见下图。）

![第65页](./rendering_inside/rendering_inside_page-0065.jpg)
---

## 第 66 页

（本页内容见下图。）

![第66页](./rendering_inside/rendering_inside_page-0066.jpg)
---

## 第 67 页

（本页内容见下图。）

![第67页](./rendering_inside/rendering_inside_page-0067.jpg)
---

## 第 68 页

（本页内容见下图。）

![第68页](./rendering_inside/rendering_inside_page-0068.jpg)
---

## 第 69 页

（本页内容见下图。）

![第69页](./rendering_inside/rendering_inside_page-0069.jpg)
---

## 第 70 页

（本页内容见下图。）

![第70页](./rendering_inside/rendering_inside_page-0070.jpg)
---

## 第 71 页

（本页内容见下图。）

![第71页](./rendering_inside/rendering_inside_page-0071.jpg)
---

## 第 72 页

（本页内容见下图。）

![第72页](./rendering_inside/rendering_inside_page-0072.jpg)
---

## 第 73 页

（本页内容见下图。）

![第73页](./rendering_inside/rendering_inside_page-0073.jpg)
---

## 第 74 页

（本页内容见下图。）

![第74页](./rendering_inside/rendering_inside_page-0074.jpg)
---

## 第 75 页

（本页内容见下图。）

![第75页](./rendering_inside/rendering_inside_page-0075.jpg)
---

## 第 76 页

（本页内容见下图。）

![第76页](./rendering_inside/rendering_inside_page-0076.jpg)
---

## 第 77 页

（本页内容见下图。）

![第77页](./rendering_inside/rendering_inside_page-0077.jpg)
---

## 第 78 页

（本页内容见下图。）

![第78页](./rendering_inside/rendering_inside_page-0078.jpg)
---

## 第 79 页

（本页内容见下图。）

![第79页](./rendering_inside/rendering_inside_page-0079.jpg)
---

## 第 80 页

（本页内容见下图。）

![第80页](./rendering_inside/rendering_inside_page-0080.jpg)
---

## 第 81 页

（本页内容见下图。）

![第81页](./rendering_inside/rendering_inside_page-0081.jpg)
---

## 第 82 页

（本页内容见下图。）

![第82页](./rendering_inside/rendering_inside_page-0082.jpg)
---

## 第 83 页

（本页内容见下图。）

![第83页](./rendering_inside/rendering_inside_page-0083.jpg)
---

## 第 84 页

（本页内容见下图。）

![第84页](./rendering_inside/rendering_inside_page-0084.jpg)
---

## 第 85 页

（本页内容见下图。）

![第85页](./rendering_inside/rendering_inside_page-0085.jpg)
---

## 第 86 页

（本页内容见下图。）

![第86页](./rendering_inside/rendering_inside_page-0086.jpg)
---

## 第 87 页

（本页内容见下图。）

![第87页](./rendering_inside/rendering_inside_page-0087.jpg)
---

## 第 88 页

（本页内容见下图。）

![第88页](./rendering_inside/rendering_inside_page-0088.jpg)
---

## 第 89 页

（本页内容见下图。）

![第89页](./rendering_inside/rendering_inside_page-0089.jpg)
---

## 第 90 页

（本页内容见下图。）

![第90页](./rendering_inside/rendering_inside_page-0090.jpg)
---

## 第 91 页

（本页内容见下图。）

![第91页](./rendering_inside/rendering_inside_page-0091.jpg)
---

## 第 92 页

（本页内容见下图。）

![第92页](./rendering_inside/rendering_inside_page-0092.jpg)
---

## 第 93 页

（本页内容见下图。）

![第93页](./rendering_inside/rendering_inside_page-0093.jpg)
---

## 第 94 页

（本页内容见下图。）

![第94页](./rendering_inside/rendering_inside_page-0094.jpg)
---

## 第 95 页

（本页内容见下图。）

![第95页](./rendering_inside/rendering_inside_page-0095.jpg)
---

## 第 96 页

（本页内容见下图。）

![第96页](./rendering_inside/rendering_inside_page-0096.jpg)
---

## 第 97 页

（本页内容见下图。）

![第97页](./rendering_inside/rendering_inside_page-0097.jpg)
---

## 第 98 页

（本页内容见下图。）

![第98页](./rendering_inside/rendering_inside_page-0098.jpg)
---

## 第 99 页

（本页内容见下图。）

![第99页](./rendering_inside/rendering_inside_page-0099.jpg)
---

## 第 100 页

（本页内容见下图。）

![第100页](./rendering_inside/rendering_inside_page-0100.jpg)
---

## 第 101 页

（本页内容见下图。）

![第101页](./rendering_inside/rendering_inside_page-0101.jpg)
---

## 第 102 页

（本页内容见下图。）

![第102页](./rendering_inside/rendering_inside_page-0102.jpg)
---

## 第 103 页

（本页内容见下图。）

![第103页](./rendering_inside/rendering_inside_page-0103.jpg)
---

## 第 104 页

（本页内容见下图。）

![第104页](./rendering_inside/rendering_inside_page-0104.jpg)
---

## 第 105 页

（本页内容见下图。）

![第105页](./rendering_inside/rendering_inside_page-0105.jpg)
---

## 第 106 页

（本页内容见下图。）

![第106页](./rendering_inside/rendering_inside_page-0106.jpg)
---

## 第 107 页

（本页内容见下图。）

![第107页](./rendering_inside/rendering_inside_page-0107.jpg)
---

## 第 108 页

（本页内容见下图。）

![第108页](./rendering_inside/rendering_inside_page-0108.jpg)
---

## 第 109 页

（本页内容见下图。）

![第109页](./rendering_inside/rendering_inside_page-0109.jpg)
---

## 第 110 页

（本页内容见下图。）

![第110页](./rendering_inside/rendering_inside_page-0110.jpg)
---

## 第 111 页

（本页内容见下图。）

![第111页](./rendering_inside/rendering_inside_page-0111.jpg)
---

## 第 112 页

（本页内容见下图。）

![第112页](./rendering_inside/rendering_inside_page-0112.jpg)
---

## 第 113 页

（本页内容见下图。）

![第113页](./rendering_inside/rendering_inside_page-0113.jpg)
---

## 第 114 页

（本页内容见下图。）

![第114页](./rendering_inside/rendering_inside_page-0114.jpg)
---

## 第 115 页

（本页内容见下图。）

![第115页](./rendering_inside/rendering_inside_page-0115.jpg)
---

## 第 116 页

（本页内容见下图。）

![第116页](./rendering_inside/rendering_inside_page-0116.jpg)
---

## 第 117 页

（本页内容见下图。）

![第117页](./rendering_inside/rendering_inside_page-0117.jpg)
---

## 第 118 页

（本页内容见下图。）

![第118页](./rendering_inside/rendering_inside_page-0118.jpg)
---

## 第 119 页

（本页内容见下图。）

![第119页](./rendering_inside/rendering_inside_page-0119.jpg)
---

## 第 120 页

（本页内容见下图。）

![第120页](./rendering_inside/rendering_inside_page-0120.jpg)
---

## 第 121 页

（本页内容见下图。）

![第121页](./rendering_inside/rendering_inside_page-0121.jpg)
---

## 第 122 页

（本页内容见下图。）

![第122页](./rendering_inside/rendering_inside_page-0122.jpg)
---

## 第 123 页

（本页内容见下图。）

![第123页](./rendering_inside/rendering_inside_page-0123.jpg)
---

## 第 124 页

（本页内容见下图。）

![第124页](./rendering_inside/rendering_inside_page-0124.jpg)
---

## 第 125 页

（本页内容见下图。）

![第125页](./rendering_inside/rendering_inside_page-0125.jpg)
---

## 第 126 页

（本页内容见下图。）

![第126页](./rendering_inside/rendering_inside_page-0126.jpg)
---

## 第 127 页

（本页内容见下图。）

![第127页](./rendering_inside/rendering_inside_page-0127.jpg)
---

## 第 128 页

（本页内容见下图。）

![第128页](./rendering_inside/rendering_inside_page-0128.jpg)
---

## 第 129 页

（本页内容见下图。）

![第129页](./rendering_inside/rendering_inside_page-0129.jpg)
---

## 第 130 页

（本页内容见下图。）

![第130页](./rendering_inside/rendering_inside_page-0130.jpg)
---

## 第 131 页

（本页内容见下图。）

![第131页](./rendering_inside/rendering_inside_page-0131.jpg)
---

## 第 132 页

（本页内容见下图。）

![第132页](./rendering_inside/rendering_inside_page-0132.jpg)
---

## 第 133 页

（本页内容见下图。）

![第133页](./rendering_inside/rendering_inside_page-0133.jpg)
---

## 第 134 页

（本页内容见下图。）

![第134页](./rendering_inside/rendering_inside_page-0134.jpg)
---

## 第 135 页

（本页内容见下图。）

![第135页](./rendering_inside/rendering_inside_page-0135.jpg)
---

## 第 136 页

（本页内容见下图。）

![第136页](./rendering_inside/rendering_inside_page-0136.jpg)
---

## 第 137 页

（本页内容见下图。）

![第137页](./rendering_inside/rendering_inside_page-0137.jpg)
---

## 第 138 页

（本页内容见下图。）

![第138页](./rendering_inside/rendering_inside_page-0138.jpg)
---

## 第 139 页

（本页内容见下图。）

![第139页](./rendering_inside/rendering_inside_page-0139.jpg)
---

## 第 140 页

（本页内容见下图。）

![第140页](./rendering_inside/rendering_inside_page-0140.jpg)
---

## 第 141 页

（本页内容见下图。）

![第141页](./rendering_inside/rendering_inside_page-0141.jpg)
---

## 第 142 页

（本页内容见下图。）

![第142页](./rendering_inside/rendering_inside_page-0142.jpg)
---

## 第 143 页

（本页内容见下图。）

![第143页](./rendering_inside/rendering_inside_page-0143.jpg)
---

## 第 144 页

（本页内容见下图。）

![第144页](./rendering_inside/rendering_inside_page-0144.jpg)
---

## 第 145 页

（本页内容见下图。）

![第145页](./rendering_inside/rendering_inside_page-0145.jpg)
---

## 第 146 页

（本页内容见下图。）

![第146页](./rendering_inside/rendering_inside_page-0146.jpg)
---

## 第 147 页

（本页内容见下图。）

![第147页](./rendering_inside/rendering_inside_page-0147.jpg)
---

## 第 148 页

（本页内容见下图。）

![第148页](./rendering_inside/rendering_inside_page-0148.jpg)
---

## 第 149 页

（本页内容见下图。）

![第149页](./rendering_inside/rendering_inside_page-0149.jpg)
---

## 第 150 页

（本页内容见下图。）

![第150页](./rendering_inside/rendering_inside_page-0150.jpg)
---

## 第 151 页

（本页内容见下图。）

![第151页](./rendering_inside/rendering_inside_page-0151.jpg)
---

## 第 152 页

（本页内容见下图。）

![第152页](./rendering_inside/rendering_inside_page-0152.jpg)
---

## 第 153 页

（本页内容见下图。）

![第153页](./rendering_inside/rendering_inside_page-0153.jpg)
---

## 第 154 页

（本页内容见下图。）

![第154页](./rendering_inside/rendering_inside_page-0154.jpg)
---

## 第 155 页

（本页内容见下图。）

![第155页](./rendering_inside/rendering_inside_page-0155.jpg)
---

## 第 156 页

（本页内容见下图。）

![第156页](./rendering_inside/rendering_inside_page-0156.jpg)
---

## 第 157 页

（本页内容见下图。）

![第157页](./rendering_inside/rendering_inside_page-0157.jpg)
---

## 第 158 页

（本页内容见下图。）

![第158页](./rendering_inside/rendering_inside_page-0158.jpg)
---

## 第 159 页

（本页内容见下图。）

![第159页](./rendering_inside/rendering_inside_page-0159.jpg)
---

## 第 160 页

（本页内容见下图。）

![第160页](./rendering_inside/rendering_inside_page-0160.jpg)
---

## 第 161 页

（本页内容见下图。）

![第161页](./rendering_inside/rendering_inside_page-0161.jpg)
---

## 第 162 页

（本页内容见下图。）

![第162页](./rendering_inside/rendering_inside_page-0162.jpg)
---

## 第 163 页

（本页内容见下图。）

![第163页](./rendering_inside/rendering_inside_page-0163.jpg)
---

## 第 164 页

（本页内容见下图。）

![第164页](./rendering_inside/rendering_inside_page-0164.jpg)
---

## 第 165 页

（本页内容见下图。）

![第165页](./rendering_inside/rendering_inside_page-0165.jpg)
---

## 第 166 页

（本页内容见下图。）

![第166页](./rendering_inside/rendering_inside_page-0166.jpg)
---

## 第 167 页

（本页内容见下图。）

![第167页](./rendering_inside/rendering_inside_page-0167.jpg)
---

## 第 168 页

（本页内容见下图。）

![第168页](./rendering_inside/rendering_inside_page-0168.jpg)
---

## 第 169 页

（本页内容见下图。）

![第169页](./rendering_inside/rendering_inside_page-0169.jpg)
---

## 第 170 页

（本页内容见下图。）

![第170页](./rendering_inside/rendering_inside_page-0170.jpg)
---

## 第 171 页

（本页内容见下图。）

![第171页](./rendering_inside/rendering_inside_page-0171.jpg)
---

## 第 172 页

（本页内容见下图。）

![第172页](./rendering_inside/rendering_inside_page-0172.jpg)
---

## 第 173 页

（本页内容见下图。）

![第173页](./rendering_inside/rendering_inside_page-0173.jpg)
---

## 第 174 页

（本页内容见下图。）

![第174页](./rendering_inside/rendering_inside_page-0174.jpg)
---

## 第 175 页

（本页内容见下图。）

![第175页](./rendering_inside/rendering_inside_page-0175.jpg)
---

## 第 176 页

（本页内容见下图。）

![第176页](./rendering_inside/rendering_inside_page-0176.jpg)
---

## 第 177 页

（本页内容见下图。）

![第177页](./rendering_inside/rendering_inside_page-0177.jpg)
---

## 第 178 页

（本页内容见下图。）

![第178页](./rendering_inside/rendering_inside_page-0178.jpg)
---

## 第 179 页

（本页内容见下图。）

![第179页](./rendering_inside/rendering_inside_page-0179.jpg)
---

## 第 180 页

（本页内容见下图。）

![第180页](./rendering_inside/rendering_inside_page-0180.jpg)
---

## 第 181 页

（本页内容见下图。）

![第181页](./rendering_inside/rendering_inside_page-0181.jpg)
---

## 第 182 页

（本页内容见下图。）

![第182页](./rendering_inside/rendering_inside_page-0182.jpg)
---

## 第 183 页

（本页内容见下图。）

![第183页](./rendering_inside/rendering_inside_page-0183.jpg)
---

## 第 184 页

（本页内容见下图。）

![第184页](./rendering_inside/rendering_inside_page-0184.jpg)
---

## 第 185 页

（本页内容见下图。）

![第185页](./rendering_inside/rendering_inside_page-0185.jpg)
---

## 第 186 页

（本页内容见下图。）

![第186页](./rendering_inside/rendering_inside_page-0186.jpg)
---

## 第 187 页

（本页内容见下图。）

![第187页](./rendering_inside/rendering_inside_page-0187.jpg)
---

## 第 188 页

（本页内容见下图。）

![第188页](./rendering_inside/rendering_inside_page-0188.jpg)
---

## 第 189 页

（本页内容见下图。）

![第189页](./rendering_inside/rendering_inside_page-0189.jpg)
---

## 第 190 页

（本页内容见下图。）

![第190页](./rendering_inside/rendering_inside_page-0190.jpg)
---

## 第 191 页

（本页内容见下图。）

![第191页](./rendering_inside/rendering_inside_page-0191.jpg)
---

## 第 192 页

（本页内容见下图。）

![第192页](./rendering_inside/rendering_inside_page-0192.jpg)
---

## 第 193 页

（本页内容见下图。）

![第193页](./rendering_inside/rendering_inside_page-0193.jpg)
---

## 第 194 页

（本页内容见下图。）

![第194页](./rendering_inside/rendering_inside_page-0194.jpg)
---

## 第 195 页

（本页内容见下图。）

![第195页](./rendering_inside/rendering_inside_page-0195.jpg)
---

## 第 196 页

（本页内容见下图。）

![第196页](./rendering_inside/rendering_inside_page-0196.jpg)
---

## 第 197 页

（本页内容见下图。）

![第197页](./rendering_inside/rendering_inside_page-0197.jpg)
---

## 第 198 页

（本页内容见下图。）

![第198页](./rendering_inside/rendering_inside_page-0198.jpg)
---

## 第 199 页

（本页内容见下图。）

![第199页](./rendering_inside/rendering_inside_page-0199.jpg)
---

## 第 200 页

（本页内容见下图。）

![第200页](./rendering_inside/rendering_inside_page-0200.jpg)
---

## 第 201 页

（本页内容见下图。）

![第201页](./rendering_inside/rendering_inside_page-0201.jpg)
---

## 第 202 页

（本页内容见下图。）

![第202页](./rendering_inside/rendering_inside_page-0202.jpg)
---

## 第 203 页

（本页内容见下图。）

![第203页](./rendering_inside/rendering_inside_page-0203.jpg)
---

## 第 204 页

（本页内容见下图。）

![第204页](./rendering_inside/rendering_inside_page-0204.jpg)
---

## 第 205 页

（本页内容见下图。）

![第205页](./rendering_inside/rendering_inside_page-0205.jpg)
---

## 第 206 页

（本页内容见下图。）

![第206页](./rendering_inside/rendering_inside_page-0206.jpg)
---

## 第 207 页

（本页内容见下图。）

![第207页](./rendering_inside/rendering_inside_page-0207.jpg)
---

## 第 208 页

（本页内容见下图。）

![第208页](./rendering_inside/rendering_inside_page-0208.jpg)
---

## 第 209 页

（本页内容见下图。）

![第209页](./rendering_inside/rendering_inside_page-0209.jpg)
---

## 第 210 页

（本页内容见下图。）

![第210页](./rendering_inside/rendering_inside_page-0210.jpg)
---

## 第 211 页

（本页内容见下图。）

![第211页](./rendering_inside/rendering_inside_page-0211.jpg)
---

## 第 212 页

（本页内容见下图。）

![第212页](./rendering_inside/rendering_inside_page-0212.jpg)
---

## 第 213 页

（本页内容见下图。）

![第213页](./rendering_inside/rendering_inside_page-0213.jpg)
---

## 第 214 页

（本页内容见下图。）

![第214页](./rendering_inside/rendering_inside_page-0214.jpg)
---

## 第 215 页

（本页内容见下图。）

![第215页](./rendering_inside/rendering_inside_page-0215.jpg)
---

## 第 216 页

（本页内容见下图。）

![第216页](./rendering_inside/rendering_inside_page-0216.jpg)
---

## 第 217 页

（本页内容见下图。）

![第217页](./rendering_inside/rendering_inside_page-0217.jpg)
---

## 第 218 页

（本页内容见下图。）

![第218页](./rendering_inside/rendering_inside_page-0218.jpg)