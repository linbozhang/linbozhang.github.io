# Rendering Inside（《Inside》渲染技术）

Playdead 出品游戏 **Inside**（及 Limbo）所用渲染技术的分享文稿，涉及体积雾、辉光与氛围光等。Unity 引擎。

---

## 第 2 页 · Playdead / Inside

**PLAYDEAD**：左侧为《Limbo》风格截图（黑白、雾中小船与水面）；右侧为《Inside》截图（工业室内、红色「INSIDE」标题、穿白衣的人形队列、Unity 标志）。  
Trailer: http://playdead.com/inside/

![第2页](./rendering_inside/rendering_inside_page-0002.jpg)

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

## 第 13 页 · HDR 辉光 (HDR Glow)

**第二遍辉光，针对高亮发光物体。**  
**从遮罩物体产生的窄辉光**（橙色强调）：仅**自发光材质**（写入 alpha 通道）；遮罩值将 RGB 重映射到非线性强度 [1; 约 7]。  
中间 HDR 值编码为 [0;1] 定点：\( x/(x+1) \)。  
右图：上方为场景中多处红点发光与辉光；下方为仅发光点的遮罩视图。

![第13页](./rendering_inside/rendering_inside_page-0013.jpg)

---

## 其余页面（按页码）

以下为原稿其余页面（第 14–218 页），图片文件位于 `rendering_inside/` 目录，文件名为 `rendering_inside_page-XXXX.jpg`（XXXX 为四位页码，如 0014、0218）。
