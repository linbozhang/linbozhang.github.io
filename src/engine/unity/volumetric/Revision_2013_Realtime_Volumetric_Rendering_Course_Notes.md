# 实时体积渲染 (Real-Time Volumetric Rendering)

**By Patapom / Bomb!（2013 年春季，Revision Demo Party 课程笔记）**

---

## 第 1 页 · 引言与参与介质

在演示场景 (demoscene) 里，几乎人人都在用距离场做光线步进 (ray-marching)，却很少见到用它来做体积渲染。那么，何不用光线步进来实现它最初的目的：**渲染参与介质 (participating medium)**？

### 什么是参与介质？(What's a participating medium?)

⇨ **它是这样一个体积（介质）：折射、密度和/或反照率在局部发生变化。**

事实上，所有介质在某种尺度上都是参与介质，取决于我们考虑的距离。但在短距离内，有些介质可以视为**均匀的 (homogeneous)**。

**短距离内的均匀介质（空气、水、玻璃）：**

- 图示：左侧为装水的玻璃杯（折射、模糊）；右侧为抽象的一束光穿过介质。
- 大多数情况下我们仍须考虑**非均匀介质 (heterogeneous medium)**，其特性会有或快或慢的变化。
- 当这些特性发生变化时，**光子通量 (flux of photons)** 会怎样？

![第1页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0001.jpg)

---

## 第 2 页 · 吸收、散射与光子通量

### 吸收 (Absorption)

吸收可能随波长变化，例如在水中传播很长距离后会呈现偏蓝着色。图示：水下深蓝场景；橙色光束随距离变短、变淡，表示衰减。

### 散射 (Scattering)

光子在粒子表面向各个方向反弹；依粒子密度与类型，散射或更随机或更频繁。

- **主要是方向性散射 (Mainly directional scattering)**：多数光子仍沿原方向前进。
- **几次散射后主要为漫反射 (Mainly diffuse after a few events)**：多次碰撞后向各方向扩散。

### 小结：光子通量会发生的事件

- **吸收 (Absorption)**：主光流变窄。
- **向外散射 (Out-Scattering)**：一部分光子从主光路分出。
- **向内散射 (In-Scattering)**：从其他方向散射进主光路的光子。

![第2页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0002.jpg)

---

## 第 3 页 · 散射与消光 (Scattering & Extinction)

（作者注：稍后会回到另一种事件：发射 emission。）

考虑**单个粒子**（分子、尘埃、水滴等）：光子会与它相互作用并从其「表面」反弹。以云为例，想象一个微观水滴：它会折射或反射光线，几乎不吸收——因此云很亮，反照率 (albedo) 接近 100%。若光在充满大量此类粒子的体积中传播呢？本质上是一个**概率问题**：在走过 N 米后击中粒子的概率是多少？

**粒子截面 (Particle Cross-Section)**：\( a = \pi r_e^2 \) (m²)，\( r_e \) 为有效半径（云中水滴典型约 2–20 µm）。

**吸收/散射截面**：\( \sigma = a N_0 \) (m⁻¹) ——(1)。\( N_0 \) 为液滴密度（云中约 10⁸–10⁹ /m³），故 \( \sigma \) 典型值约 10⁻²–10⁻¹ m⁻¹。

**NOTE：** 光击中粒子时可能被吸收或散射，净效果是**能量损失（消光 extinction）**。因此 (1) 中的 \( \sigma \) 实际是两个系数之和：

**消光系数** \( \sigma_t = \sigma_a + \sigma_s \)，其中 \( \sigma_a \) 为吸收系数，\( \sigma_s \) 为散射系数。

![第3页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0003.jpg)

---

## 第 4 页 · 消光与内散射

### 消光 (Extinction)

**消光函数**是渲染参与介质最重要的方程之一，即**比尔-朗伯定律 (Beer-Lambert law)**：

\[ \tau(d) = e^{-\sigma_t \cdot d} \quad \text{(2)} \]

表示光沿长度 \( d \) 的路径穿过介质且**不撞击粒子**的概率，也即介质的**透明度 (transmittance)**。

图示：云状体积，View 从左向右、Light 从右向左；光束从 In 进入、Out 离开，沿途衰减。

在距离 \( \Delta x \) 处进入的**辐射度 (radiance)** 会减弱：

\[ L(\mathbf{x}, \omega) = e^{-\sigma_t \Delta x} \, L(\mathbf{x} + \Delta x\,\omega, \omega) \quad \text{(3)} \]

其中 \( \omega \) 为观察方向，\( \mathbf{x} \) 为光线离开体积的位置（Out），\( \Delta x \) 为 In 到 Out 的距离（故 \( \mathbf{x} + \Delta x\,\omega \) 为 In）。**NOTE：** 当 \( \sigma_t \) 视为常数（均匀介质）时 (3) 成立。

### 内散射 (In-Scattering)

光撞击分子与粒子会损失能量，同时也有从其他方向散射到观察方向的光进入视线；内散射会增加能量，有时甚至能补偿消光损失（例如放大镜将光弯曲并汇聚到一点）。

![第4页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0004.jpg)

---

## 第 5 页 · 相位函数 (The Phase Function)

我们需要估计光从某一方向散射到另一方向（尤其是观察方向）的概率。

**相位函数**与材质的 **BRDF** 很类似：

- 一个「黑盒」，描述光与材质的相互作用；
- 与 BRDF 的区别：通常只考虑**一个角度**（两方向间的相位角），且在整个方向球面上积分为 1。

\[ \int_{\Omega_{4\pi}} p(\omega_i, \omega_o) \, d\omega_o = 1 \quad \forall \omega_i \]

其中 \( \theta = \omega_i \cdot \omega_o \) 为入射与出射方向夹角，\( \Omega_{4\pi} \) 为所有方向的球面。

**平均余弦 (average cosine)** \( g \)：相位函数的「平均余弦」给出优先散射方向 \( g \in [-1, +1] \)：-1 为后向散射（光返回光源），+1 为前向散射（光几乎不受影响）。

\[ g = \int_{\Omega_{4\pi}} p(\theta) \cos(\theta) \, d\omega_o \]

存在一些简单的**解析相位函数模型**。

### 瑞利相位函数 (Rayleigh Phase Function)

当粒子足够小时发生**瑞利散射**，相位函数呈**花生形 (peanut-shaped)**：

\[ p(\theta) = \frac{3}{16\pi} \bigl(1 + \cos^2(\theta)\bigr) \]

![第5页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0005.jpg)

---

## 第 6 页 · 散射强度与 Henyey-Greenstein

分子尺度与波长相近时，散射强度 \( I_{\text{scattered}} \propto 1/\lambda^4 \)，即 400 nm 的散射约为 700 nm 的约 9 倍——这也是天空呈蓝色的主要原因（短波蓝光更易被散射）。

### Henyey-Greenstein 相位函数 (Henyey-Greenstein Phase Function)

对**较大粒子**（污染物、气溶胶、尘埃、水滴）须使用**米氏散射 (Mie scattering)**。米氏理论难以掌握，大气成分形状与行为多样，相位函数往往很难处理。例如，**云的平均统计相位函数**大致如下：

- 图表特征：**窄前向峰 (Narrow forward peak)**、**宽前向峰 (Wide forward peak)**、**雾虹 (Fogbow)**、**光晕 (Glory)** 等；对数坐标下 P(Θ) 随角度变化。
- 通常不直接使用该复杂相位函数，而是用多个更简单的 **Henyey-Greenstein** 相位函数的**组合**来近似。

![第6页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0006.jpg)

---

## 第 7 页 · HG 相位函数、Schlick 近似与加权和

**Henyey-Greenstein 相位函数：**

\[ p_{HG}(\theta) = \frac{1 - g^2}{4\pi\,(1 + g^2 - 2g\cos\theta)^{3/2}} \]

其中 \( g \)  again 为优先散射方向，\( g \in [-1, +1] \)。

图示：极坐标下不同 \( g \)（-0.6, -0.3, 0, 0.3, 0.6）的散射 lobe；\( g=0 \) 为圆（各向同性），\( g>0 \) 向前、\( g<0 \) 向后。

**NOTE：** 因指数 \( 3/2 \)，HG 常被更省成本的 **Schlick 相位函数**替代：

\[ p_{Schlick}(\theta) = \frac{1 - k^2}{4\pi\,(1 + k\cos\theta)^2} \]

**如何使用？**

- 我们**仅对单次散射**使用相位函数：光只弹一次。多次散射非常昂贵，后面会用别的方式近似。
- 相位函数可以**加权累加**，权值和为 1：\( p(\theta) = w_0 p_{HG_0}(\theta) + w_1 p_{HG_1}(\theta) + \cdots \)，\( \sum w_i = 1 \)。
- 因此可用多个简单相位函数的加权和来近似上页复杂的米氏散射。

![第7页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0007.jpg)

---

## 第 8 页 · 光照传输方程 (Radiance Transfer Equation)

**我们开始把这一切写成代码如何？**

在掌握上述知识后，重点转到代码。首先是要处理的方程：

**方程 (4)：**

\[ L(x, \omega) = \int_0^D e^{-\tau(x,x')} \, \sigma_s(x') \, \left[ \int_{\Omega_{4\pi}} p(\omega, \omega') L_i(x', \omega') \, d\omega' \right] dx' \]

- **绿色部分** \( e^{-\tau(x,x')} \)：即之前的**消光 (extinction)**。其中 **光学深度 (Optical Depth)** \( \tau(x, x') = \int_x^{x'} \sigma_t(t)\,dt \) 表示从 \( x \) 到 \( x' \) 路径上累积的消光。若在长度 \( \Delta x \) 上 \( \sigma_t \) 为常数，则简化为 \( \tau = \sigma_t(x)\,\Delta x \)——为此需要把路径分成小段。
- **蓝色部分**：**内散射 (in-scattering)**——相位函数与来自所有方向的光 \( L_i(x', \omega_i) \) 的积分。难点在于 \( L_i(x', \omega_i) \) 本身又要用方程 (4) 计算，这是**递归关系**，每一层递归对应一阶散射。因此**多重散射**非常昂贵，多数时候用简单**环境项 (ambient term)** 近似。（注：这部分相当于全局光照中的**间接光照**。）

![第8页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0008.jpg)

---

## 第 9 页 · 简化：光源分类与简化方程

上图来自 [3]，Bouthors 等人考虑了**最高 20 阶**的散射事件，并说明它们对云的正确外观仍然重要。该图还是 7 天内计算得到的 25GB 数据库压缩后的结果——所以实时场景下可以暂时忘掉这种规模。**漂亮但昂贵！(Nice but expensive!)**

### 让我们简化 (Let's Simplify)

首先将光源分为三类：

- 来自太阳的**直接光照 (Direct Lighting from the Sun)**
- 来自太阳的**间接光照 (Indirect Lighting from the Sun)**
- 来自天空的**间接光照 (Indirect Lighting from the Sky)**

方程 (4) 变为：

\[ L(x, \omega) = \int_0^D e^{-\tau(x,x')} \, \sigma_s(x') \, \Bigl[ P_{sun}(\omega, \omega_{sun}) L_{sun}(x', \omega_{sun}) + p_{amb} L_{amb} \Bigr] \, dx' \]

去掉内层积分后更简洁；复杂性转移到如何为 \( L_{amb} \) 取一个好的值。

该积分可理解为：

1. 计算从太阳和环境到达 \( x' \) 的入射光；
2. 用 \( \sigma_s(x') \) 对其进行散射；
3) 让观察者只感知到一部分光，因为光在 \( x \) 与 \( x' \) 之间发生消光；
4) 为下一个步长 \( dx' \) 重复。

![第9页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0009.jpg)

---

## 第 10 页 · 离散化与递归透射率

图示：光线沿步进 Step 0 → Step 1 → Step 2 衰减，最终被摄像机接收。

将积分离散化：

\[ L(x, \omega) \approx \sum_{i=1}^{N} e^{-\tau(x, x+i\Delta x)} \, \sigma_s(x+i\Delta x) \, \Bigl[ P_{sun}(\cdots) L_{sun}(\cdots) + p_{amb} L_{amb} \Bigr] \, \Delta x \]

其中 \( \Delta x = D/N \)，\( N \) 为步数。

为处理绿色部分，利用：\( e^{-\tau(0,\Delta)} = e^{-\tau(0, \Delta/2)} \, e^{-\tau(\Delta/2, \Delta)} \)。对固定步长 \( \Delta x \) 递归应用：

\[ e^{-\tau(x, x+i\Delta x)} \approx \prod_{j=1}^{i-1} e^{-\sigma_t(x+j\Delta x)\,\Delta x} \]

即**各小段不透光度的乘积**；可在寄存器中维护一个值，每步做乘法。

**着色器中的最终形式 (5)：**

\[ L(x, \omega) \approx \sum_{i=1}^{N} EX_i \, \sigma_s(x+i\Delta x) \, \Bigl[ P_{sun}(\cdots) L_{sun}(\cdots) + p_{amb} L_{amb} \Bigr] \, \Delta x \]

其中：

\[ EX_i = EX_{i-1} \cdot e^{-\sigma_t(x+i\Delta x)\,\Delta x}, \quad EX_0 = 1 \]

![第10页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0010.jpg)

---

## 第 11 页 · 光线步进着色器伪代码

**着色器代码（光线步进器 ray marcher 伪代码）：**

```hlsl
float3 Position = 体积起始位置;
float3 View = 归一化观察方向;

float Extinction = 1.0;   // 初始完全透明
float3 Scattering = 0.0;  // 初始无累积光

for each step
{
    float Density = SampleMediumDensity(Position);           // 采样某种噪声，返回 [0,1]
    float ScatteringCoeff = ScatteringFactor * Density;
    float ExtinctionCoeff = ExtinctionFactor * Density;

    Extinction *= exp(-ExtinctionCoeff * StepSize);         // 累积当前步消光

    float3 SunColor = ComputeSunColor(Position);
    float3 AmbientColor = ComputeAmbientColor(Position, ExtinctionCoeff);
    float3 StepScattering = ScatteringCoeff * StepSize * (PhaseSun * SunColor + PhaseAmbient * AmbientColor);
    Scattering += Extinction * StepScattering;              // 累积经消光衰减的散射

    Position += StepSize * View;
}
return float4(Scattering, Extinction);
```

我们返回带 Alpha 的 `float4`，且散射颜色在循环中已用「Extinction * StepScattering」的方式参与合成，即**颜色已预乘 Alpha**，与背景合成须用**预乘 Alpha 混合** [5]：

`Dst' = Src + SrcAlpha * Dst`

**NOTE：单色消光与波长相关消光**  
本例中消光为单通道；若考虑**瑞利散射**等波长相关现象，消光应为 `float3`，对背景 RGB 分别遮罩，无法再只存一个 Alpha，需使用多渲染目标 (MRT)。

**缺失的部分 (The Missing Parts)**  
算法中仍有一些部分未实现，下文会补全。

![第11页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0011.jpg)

---

## 第 12 页 · 计算密度与太阳颜色

三个核心函数：`SampleMediumDensity(pos)`、`ComputeSunColor(pos)`、`ComputeAmbientColor(pos)`。

### 计算密度 (Computing the Density)

用**分形布朗运动 (FBM, Fractional Brownian Motion)** 类噪声即可，在 demoscene 中很常见（作者尝试过细胞噪声、湍流、分形脊状噪声等），对真实感云渲染最合适。

```hlsl
static const float AMPLITUDE_FACTOR = 0.707f;   // 每八度振幅 × √2/2
static const float FREQUENCY_FACTOR = 2.5789f;

float SampleMediumDensity(float3 _Position)
{
    float3 UVW = _Position * 0.01;
    float Amplitude = 1.0;
    float V = Amplitude * Noise(UVW);
    // V += Amplitude * Noise(UVW); Amplitude *= AMPLITUDE_FACTOR; UVW *= FREQUENCY_FACTOR;
    // … 重复多个八度 …
    return clamp(DensityFactor * V + DensityBias, 0, 1);
}
```

**性能建议**：可将多八度噪声打包进一个 3D 纹理（不要过大以免 cache 失效）；例如低频 32³ 缓慢平铺 + 更大 128³ 叠细节，减少明显平铺。

### 计算太阳颜色 (Computing the Sun's color)

需要**体积内的阴影**：若光用常值、不考虑在体积内的位置，云会很不真实。**自阴影 (self-shadowing)** 很重要，因此需要能存**体积阴影**的**阴影图**。

现有技术：

- **深度阴影图 (Deep Shadow Maps) [6]**：不适于 GPU，需列表与排序；DX11 UAV 可做但非最优。
- **不透明度阴影图 (Opacity Shadow Maps) [7]**：存达到某不透明度时的 Z，精度不足。
- **透射函数图 (Transmittance Function Maps) [8]**：见下页。

![第12页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0012.jpg)

---

## 第 13 页 · 透射函数、体积阴影图与环境光

**紧凑透射函数 (compact transmittance function)**：用 DCT 基、6 个系数加 ZMin/ZMax，存于 2 个渲染目标，即可获得较好精度。

**体积阴影图 (Volumetric Shadow Map)**：从**光源视角**而非摄像机视角做光线步进；只算**消光/透射率 (extinction/transmittance)**，不算散射；在体积内**多个关键点**存储/压缩/编码衰减，而不是只存一个最终值。

**ComputeSunColor 伪代码：**

```hlsl
float3 ComputeSunColor(float3 _Position)
{
    float3 ShadowMapPosition = _Position * World2ShadowMap;
    float2 UV = ShadowMapPosition.xy;
    float Z = ShadowMapPosition.z;
    float Extinction = GetShadowExtinction(UV, Z);   // 采样得 [0,1] 衰减
    return Extinction * SunColor;
}
```

### 计算环境光颜色 (Computing the Ambient color)

单次散射不足以撑起真实感，环境光很重要。技巧：把介质看成**均匀密度的无限平板**，假设有来自顶部/底部的均匀「环境」辐射 \( L_{amb+} \) / \( L_{amb-} \)，太阳光可除以 \( 4\pi \) 当作各向同性贡献，并加一个因子来近似高阶散射损失。

![第13页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0013.jpg)

---

## 第 14 页 · 环境光：顶部半球与厚度

图示：Top / Bottom 之间为体积，中间有一条「Sampling Altitude」线，其上一点向 Top 发出多条射线；从该点到 Top 的垂直距离标为 **Thickness**。

假设有均匀「环境」辐射从各方向半球照到点 P：来自顶部的记为 \( L_{amb+} \)，来自底部的记为 \( L_{amb-} \)。

**来自顶部的各向同性光照：**

\[ L^+(x) = \int_{\Omega_{2\pi}^+} p_{iso} \, L_{amb+} \, e^{-\sigma_t \, H^+ / (\mathbf{n}^+ \cdot \omega)} \, d\omega \]

其中：\( L^+(x) \) 为顶部辐射度，\( \Omega_{2\pi}^+ \) 为顶部半球方向，\( p_{iso} = 1/(4\pi) \) 为各向同性相位函数，\( \mathbf{n}^+ \) 为体积局部法线（指向上）。将 \( + \) 换成 \( - \) 可得平板底部的类似方程。提出常数项并写成球坐标下对半球的二重积分即可进一步化简。

![第14页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0014.jpg)

---

## 第 15 页 · 环境光闭合解与 ComputeAmbientColor

将积分写成球坐标并化简后，有 \( a = \sigma_t \, H_t \) 等形式。该积分有**闭合形式解**，且与**指数积分 (Exponential Integral)** \( Ei \) 有关：

\[ \int_0^{\pi/2} e^{-a/\cos\theta} \sin\theta \, d\theta = e^{-a} + a\,Ei(-a) \]

**伪代码：**

```hlsl
// Exponential Integral (http://en.wikipedia.org/wiki/Exponential_integral)
float Ei(float z)
{
    return 0.5772156649015328606065 + log(1e-4 + abs(z)) + z * (1.0 + z * (0.25 + z * ((1.0/18.0) + z * ((1.0/96.0) + z * (1.0/600.0)))));
}

float3 ComputeAmbientColor(float3 _Position, float _ExtinctionCoeff)
{
    float Hp = VolumeTop - _Position.y;    // 到体积顶部的距离
    float a = -_ExtinctionCoeff * Hp;
    float3 IsotropicScatteringTop = IsotropicLightTop * max(0.0, exp(a) - a * Ei(a));

    float Hb = _Position.y - VolumeBottom; // 到体积底部的距离
    a = -_ExtinctionCoeff * Hb;
    float3 IsotropicScatteringBottom = IsotropicLightBottom * max(0.0, exp(a) - a * Ei(a));

    return IsotropicScatteringTop + IsotropicScatteringBottom;
}
```

`IsotropicLightTop` 来自天空与「太阳做成环境」；`IsotropicLightBottom` 可加入地面反弹的太阳光以模拟**颜色溢出 (color bleeding)**。

![第15页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0015.jpg)

---

## 第 16 页 · 效果对比、自发光与结论

**我们可以在这里看到改进：** 左图云较暗、层次模糊；右图更亮、过渡更自然，渲染质量明显提升。

### 附：自发光介质 (Bonus: Emissive Medium)

除吸收与散射外，还可假设介质**发光**（爆炸、火焰等）。在 ray-marching 循环里给 `StepScattering` 加上一项 `emissive` 即可；该项可与介质温度（黑体辐射）或介质内光源相关。

### 结论 (Conclusion)

渲染参与介质的主要步骤：

1. **渲染带消光体积信息的阴影图**  
   → 需从**光源视角**对体积做光线步进。
2. **通过光线步进渲染体积**  
   → 查询体积阴影图累积光照；沿光线做消光。
3. **用预乘 Alpha 混合 (pre-multiplied alpha blend)** 将结果（散射 + 消光）与背景合成。

**步数建议**：阴影图通常至少 **16 步** ray-marching；体积本身视细节需要 **64 步或更多**。

![第16页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0016.jpg)

---

## 第 17 页 · 展望与参考文献

如今，全屏、高细节的整片天空渲染已可轻松达到**每秒数百帧**，例如作者为 Unity 做的大气渲染器 **Nuaj**。消光与散射背后的物理同样可用于渲染水体、皮肤或半透明物体等介质。希望通过一点练习，你能掌握这些工具，让体积渲染在 demoscene 或游戏业中成为常见做法。

### References

- [1] "Physics and Math of Shading", Naty Hoffman. Siggraph 2012
- [2] "Real-time realistic illumination and shading of stratiform clouds", Bouthors et al., Eurographics Workshop on Natural Phenomena - 2006
- [3] "Interactive multiple anisotropic scattering in clouds", Bouthors et al., ACM Symposium on Interactive 3D Graphics and Games (I3D) - 2008
- [4] "Cloud liquid water content, drop sizes, and number of droplets"
- [5] "Pre-Multiplied Alpha", Tom Forsyth - 2006
- [6] "Deep Shadow Maps", Lokovic & Veach - 2000
- [7] "Opacity Shadow Maps", Kim & Neumann - 2001
- [8] "Transmittance Function Mapping", Delalandre et al., I3D '11 Symposium on Interactive 3D Graphics and Games - 2011

![第17页](./Revision_2013_Realtime_Volumetric_Rendering_Course_Notes/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes_page-0017.jpg)
