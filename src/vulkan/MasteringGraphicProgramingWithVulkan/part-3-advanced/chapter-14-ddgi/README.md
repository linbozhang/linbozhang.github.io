# 第14章 用光线追踪实现动态漫反射全局光照（Adding Dynamic Diffuse Global Illumination with Ray Tracing）

本书到目前为止，光照都来自点光源的直接光。本章将通过添加间接光照（在游戏语境中常称为全局光照，global illumination）来增强光照。

这类光照模拟的是光的传播行为。不深入量子物理与光学的话，我们只需知道：光在物体表面反射若干次直至能量耗尽。

在电影与游戏中，全局光照一直是光照的重要一环，但往往无法实时实现。电影中单帧渲染曾需要数分钟甚至数小时，直到全局光照被提出；游戏受此启发，如今也纷纷加入全局光照。

本章将围绕以下主题介绍如何实现实时的全局光照：

- 间接光照简介
- 动态漫反射全局光照（DDGI）简介
- 实现 DDGI

各主题下会有子节便于展开。

下图展示了本章代码对间接光照的贡献：

Figure 14.1 – Indirect lighting output

在图 14.1 中，场景左侧有一个点光源。可以看到光源的绿色从左侧窗帘反射到地板和右侧柱体、窗帘上；远处地板上能看到天空颜色对墙面的影响，拱门因其可见性带来的遮挡而只受到很少的光照。

## 技术需求（Technical requirements）

本章代码可在以下地址找到：https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter14。

## 间接光照简介（Introduction to indirect lighting）

回到直接光与间接光：直接光只体现光与物质的第一次相互作用，而光会继续在空间中传播并发生反射。

从渲染角度，我们用 G-buffer 信息计算从视点可见的物体表面的第一次光照，但对视野外的信息掌握很少。

下图表示直接光照：

Figure 14.2 – Direct lighting

图 14.2 描述了当前的光照设置：发光光线与表面相交，光从这些表面反射后被相机捕获，成为像素颜色。这是对现象的极简描述，但已包含我们所需的基本要素。

对于间接光照，仅依赖相机视角是不够的，我们还需要计算视野外、却仍能影响可见区域的光源与几何体对可见表面的贡献。在这方面，光线追踪是最合适的工具：它能在空间上查询场景，计算不同反射次数对给定片段最终颜色的贡献。

下图展示间接光照：

Figure 14.3 – Indirect lighting

图 14.3 中，间接光线在表面间反射直至再次进入相机。图中标出了两条光线：一条从不可见表面反射到蓝色地板再进入相机；另一条从另一表面反射、再经红色墙面反射后进入相机。间接光照要捕捉的，正是光在可见与不可见表面上的反射现象。例如在此场景中，红蓝表面之间会有光线互相反射，使彼此靠近的部分带上对方颜色。

在光照中加入间接光照能提升真实感与画面质量，但如何实现？下一节将介绍我们选择的方案：动态漫反射全局光照（Dynamic Diffuse Global Illumination, DDGI），主要由 Nvidia 研究人员提出，并正迅速成为 3A 游戏中最常用的方案之一。

## 动态漫反射全局光照（DDGI）简介（Introduction to Dynamic Diffuse Global Illumination (DDGI)）

本节解释 DDGI 背后的算法。DDGI 基于两个主要工具：光照探针（light probes）和辐照体积（irradiance volumes）：

- **光照探针**是空间中的点，用球体表示，用于编码光照信息。
- **辐照体积**是包含三维网格化光照探针的空间，探针间距固定。

规则布局便于采样，后续我们也会看到对探针布局的改进。探针使用八面体映射（octahedral mapping）编码，即把球面映射到正方形的一种方式；延伸阅读中给出了八面体映射的数学链接。

DDGI 的核心思想是：用光线追踪**动态更新**探针——对每个探针发射若干光线，在三角形交点处计算辐亮度（radiance）。辐亮度由引擎中的动态光源计算，可实时响应光源与几何体的变化。

相对屏幕像素，网格分辨率较低，因此只能表现漫反射光照。下图是算法概览，展示了着色器（绿色矩形）与纹理（黄色椭圆）之间的关系与顺序：

Figure 14.4 – Algorithm overview

在展开每一步之前，先快速概括算法：

1. 对每个探针做光线追踪，计算辐亮度与距离。
2. 用计算得到的辐亮度更新所有探针的辐照度（irradiance），并施加一定的滞后（hysteresis）。
3. 用光线追踪得到的距离更新所有探针的可见性数据，同样施加滞后。
4. （可选）根据光线追踪距离计算每个探针的偏移位置。
5. 通过读取更新后的辐照度、可见性与探针偏移计算间接光照。

下面各小节将逐步说明。

### 对每个探针的光线追踪（Ray tracing for each probe）

这是算法的第一步。对每个需要更新的探针的每条光线，使用动态光照对场景进行光线追踪。

在光线追踪的 hit 着色器中，计算命中三角形的世界空间位置与法线，并做简化的漫反射光照计算。也可（代价更高）读取其他辐照探针，为光照计算加入无限次反射，使效果更真实。

纹理布局很重要：每一行代表单个探针的所有光线。若每个探针 128 条光线，则每行 128 个纹素，每列对应一个探针。因此 128 条光线、24 个探针的配置对应 128×24 的纹理尺寸。光照结果以辐亮度存在纹理的 RGB 通道，命中距离存在 Alpha 通道；命中距离将用于减轻光泄漏并计算探针偏移。

### 探针偏移（Probes offsetting）

探针偏移在辐照体积加载到世界或其属性（如间距、位置）改变时执行。利用光线追踪步骤的命中距离，可以判断探针是否被放在物体内部，并为其计算偏移。

偏移量不能超过到相邻探针距离的一半，以保证网格索引与位置之间仍有一定一致性。该步骤只执行少数几次（通常约五次），若持续运行会使探针不断移动，导致闪烁。

偏移计算完成后，每个探针都有最终的世界位置，可显著提升间接光照的视觉质量。下图是计算偏移前后的对比：

Figure 14.5 – Global illumination with (left) and without (right) probe offsets

可以看到，位于几何体内部的探针不仅无法贡献光照，还会产生伪影；通过探针偏移，可以把探针放到更合适的位置。

### 探针辐照度与可见性更新（Probes irradiance and visibility updates）

此时我们已有每条探针、每条光线的动态光照结果。如何编码？如“动态漫反射全局光照简介”一节所述，一种方式是用八面体映射把球面展开成矩形。

由于每个探针的辐亮度以 3D 体积形式存储，需要一张每个探针对应一个矩形的纹理。我们选择创建单张纹理：每行包含一层探针的 M×N 个探针，高度对应其余层。例如 3×2×4 的探针网格，每行 6 个探针（3×2），纹理共 4 行。本步骤执行两次：一次用辐亮度更新辐照度，一次用每个探针的距离更新可见性。

可见性对减少光泄漏至关重要；辐照度与可见性存在不同纹理中，尺寸可以不同。注意：为支持双线性滤波，需要在每个矩形周围多存 1 像素的边界，此处也会一并更新。

着色器会读取新计算的辐亮度与距离，以及上一帧的辐照度与可见性纹理，对数值做混合以避免闪烁，类似体积雾（Volumetric Fog）中时间重投影的简单滞后。若光照条件剧烈变化，可动态调整滞后以抵消滞后导致的更新缓慢；代价是对光源移动的反应会变慢，这是为避免闪烁而不得不接受的。

着色器最后一步是更新双线性滤波所需的边界。双线性滤波需要按特定顺序读取采样，如下图所示：

Figure 14.6 – Bilinear filtering samples. The outer grid copies pixels from the written pixel positions inside each rectangle

图 14.6 展示了复制像素的坐标计算：中心区域完成完整的辐照度/可见性更新，边界从指定坐标的像素复制值。我们将运行两个不同着色器：一个更新探针辐照度，一个更新探针可见性。着色器代码中会看到具体实现。接下来就可以对探针辐照度进行采样，见下一小节。

### 探针采样（Probes sampling）

本步读取辐照探针并计算间接光照贡献。从主相机视角渲染，根据世界位置与方向对最近的八个探针采样；可见性纹理用于减少泄漏并柔化光照结果。

鉴于漫反射间接分量的柔和特性以及性能考虑，我们选择在四分之一分辨率下采样，因此需要特别注意采样位置以避免像素误差。

通过对探针光线追踪、辐照度更新、可见性更新、探针偏移与探针采样的介绍，我们已经覆盖了实现可用 DDGI 的基本步骤。还可以加入其他步骤以加速渲染，例如用距离计算不活跃探针；也可以扩展为级联体积、手放体积等，使 DDGI 在游戏中有更好的灵活性，以应对不同硬件配置对算法的要求。下一节将学习如何实现 DDGI。

## 实现 DDGI（Implementing DDGI）

首先看光线追踪着色器。如第 12 章《光线追踪入门》所述，它们以一组形式出现，包含 ray-generation、ray-hit 与 ray-miss 着色器。

有一组在世界空间与网格索引之间转换的方法会在这里使用，它们随代码一起提供。

先定义光线载荷（ray payload），即光线追踪查询后缓存的信息：

```
struct RayPayload {
vec3 radiance;
float distance;
};
```

### 光线生成着色器（Ray-generation shader）

第一个着色器是光线生成。它从探针位置出发，用球面上的球面斐波那契序列（spherical Fibonacci sequences）生成随机方向发射光线。

与 TAA 和体积雾中的抖动类似，使用随机方向与时间累积（在探针更新着色器中完成）能获得更多场景信息，从而提升画面：

```
layout( location = 0 ) rayPayloadEXT RayPayload payload;
void main() {
const ivec2 pixel_coord = ivec2(gl_LaunchIDEXT.xy);
const int probe_index = pixel_coord.y;
const int ray_index = pixel_coord.x;
// Convert from linear probe index to grid probe
indices and then position:
ivec3 probe_grid_indices = probe_index_to_grid_indices(
probe_index );
vec3 ray_origin = grid_indices_to_world(
probe_grid_indices probe_index );
vec3 direction = normalize( mat3(random_rotation) *
spherical_fibonacci(ray_index, probe_rays) );
payload.radiance = vec3(0);
payload.distance = 0;
traceRayEXT(as, gl_RayFlagsOpaqueEXT, 0xff, 0, 0, 0,
ray_origin, 0.0, direction, 100.0, 0);
// Store the result coming from Hit or Miss shaders
 imageStore(global_images_2d[ radiance_output_index ],
pixel_coord, vec4(payload.radiance, payload.distance));
}
```

### 光线命中着色器（Ray-hit shader）

主要计算都在这里完成。

先声明载荷与重心坐标以计算正确的三角形数据：

```
layout( location = 0 ) rayPayloadInEXT RayPayload payload;
hitAttributeEXT vec2 barycentric_weights;
```

若为背面三角形，只存储距离，不计算光照：

```
void main() {
vec3 radiance = vec3(0);
float distance = 0.0f;
if (gl_HitKindEXT == gl_HitKindBackFacingTriangleEXT) {
// Track backfacing rays with negative distance
distance = gl_RayTminEXT + gl_HitTEXT;
distance *= -0.2;
}
```

否则读取网格实例与索引缓冲并计算三角形数据与光照：

```
else {
```

读取 mesh 实例数据与索引缓冲：

```
uint mesh_index = mesh_instance_draws[
gl_GeometryIndexEXT ].mesh_draw_index;
MeshDraw mesh = mesh_draws[ mesh_index ];
 int_array_type index_buffer = int_array_type(
mesh.index_buffer );
int i0 = index_buffer[ gl_PrimitiveID * 3 ].v;
int i1 = index_buffer[ gl_PrimitiveID * 3 + 1 ].v;
int i2 = index_buffer[ gl_PrimitiveID * 3 + 2 ].v;
```

从 mesh 缓冲读取顶点并计算世界空间位置：

```
float_array_type vertex_buffer = float_array_type(
mesh.position_buffer );
vec4 p0 = vec4(vertex_buffer[ i0 * 3 + 0 ].v,
vertex_buffer[ i0 * 3 + 1 ].v,
vertex_buffer[ i0 * 3 + 2 ].v, 1.0 );
// Calculate p1 and p2 using i1 and i2 in the same
way.
```

计算世界位置：

```
const mat4 transform = mesh_instance_draws[
gl_GeometryIndexEXT ].model;
vec4 p0_world = transform * p0;
// calculate as well p1_world and p2_world
```

与顶点位置类似，读取 UV 缓冲并计算三角形最终 UV：

```
float_array_type uv_buffer = float_array_type(
mesh.uv_buffer );
vec2 uv0 = vec2(uv_buffer[ i0 * 2 ].v, uv_buffer[
i0 * 2 + 1].v);
// Read uv1 and uv2 using i1 and i2
float b = barycentric_weights.x;
float c = barycentric_weights.y;
float a = 1 - b - c;
vec2 uv = ( a * uv0 + b * uv1 + c * uv2 );
```

读取漫反射纹理（也可读较低 MIP 以提升性能）：

```
vec3 diffuse = texture( global_textures[
nonuniformEXT( mesh.textures.x ) ], uv ).rgb;
```

读取三角形法线并计算最终法线（无需读法线贴图，因为缓存结果尺度小，细节会丢失）：

```
float_array_type normals_buffer =
float_array_type( mesh.normals_buffer );
vec3 n0 = vec3(normals_buffer[ i0 * 3 + 0 ].v,
normals_buffer[ i0 * 3 + 1 ].v,
normals_buffer[ i0 * 3 + 2 ].v );
// Similar calculations for n1 and n2 using i1 and
i2
vec3 normal = a * n0 + b * n1 + c * n2;
const mat3 normal_transform = mat3(mesh_instance_draws
[gl_GeometryIndexEXT ].model_inverse);
normal = normal_transform * normal;
```

计算世界位置与法线后计算直接光照：

```
const vec3 world_position = a * p0_world.xyz + b *
p1_world.xyz + c * p2_world.xyz;
vec3 diffuse = albedo * direct_lighting(world_position,
normal);
// Optional: infinite bounces by samplying previous
frame Irradiance:
diffuse += albedo * sample_irradiance( world_position,
normal, camera_position.xyz ) *
infinite_bounces_multiplier;
```

最后将辐亮度与距离写入载荷：

```
 radiance = diffuse;
distance = gl_RayTminEXT + gl_HitTEXT;
}
```

将结果写入 payload：

```
payload.radiance = radiance;
payload.distance = distance;
}
```

### 光线未命中着色器（Ray-miss shader）

在此着色器中直接返回天空颜色；若有环境立方体贴图也可使用：

```
layout( location = 0 ) rayPayloadInEXT RayPayload payload;
void main() {
payload.radiance = vec3( 0.529, 0.807, 0.921 );
payload.distance = 1000.0f;
}
```

### 更新探针辐照度与可见性的着色器（Updating probes irradiance and visibility shaders）

该计算着色器会读取上一帧的辐照度/可见性与本帧的辐亮度/距离，更新每个探针的八面体表示。该着色器会执行两次：一次更新辐照度，一次更新可见性，并会更新边界以支持双线性滤波。

先判断当前像素是否为边界；若是则切换模式：

```
layout (local_size_x = 8, local_size_y = 8, local_size_z =
1) in;
void main() {
 ivec3 coords = ivec3(gl_GlobalInvocationID.xyz);
const uint probe_with_border_side = probe_side_length +
2;
const uint probe_last_pixel = probe_side_length + 1;
int probe_index = get_probe_index_from_pixels
(coords.xy, int(probe_with_border_side),
probe_texture_width);
// Check if thread is a border pixel
bool border_pixel = ((gl_GlobalInvocationID.x %
probe_with_border_side) == 0) ||
((gl_GlobalInvocationID.x % probe_with_border_side )
== probe_last_pixel );
border_pixel = border_pixel ||
((gl_GlobalInvocationID.y % probe_with_border_side)
== 0) || ((gl_GlobalInvocationID.y %
probe_with_border_side ) == probe_last_pixel );
```

对非边界像素，根据光线方向与八面体坐标编码的球面方向计算权重，辐照度为加权辐亮度之和：

```
if ( !border_pixel ) {
vec4 result = vec4(0);
uint backfaces = 0;
uint max_backfaces = uint(probe_rays * 0.1f);
```

累加每条光线的贡献：

```
for ( int ray_index = 0; ray_index < probe_rays;
++ray_index ) {
ivec2 sample_position = ivec2( ray_index,
probe_index );
vec3 ray_direction = normalize(
mat3(random_rotation) *
spherical_fibonacci(ray_index, probe_rays) );
vec3 texel_direction = oct_decode
(normalized_oct_coord(coords.xy));
float weight = max(0.0, dot(texel_direction,
 ray_direction));
```

读取该光线的距离，若背面过多则提前退出：

```
float distance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
sample_position,
0).w;
if ( distance < 0.0f &&
use_backfacing_blending() ) {
++backfaces;
// Early out: only blend ray radiance into
the probe if the backface threshold
hasn't been exceeded
if (backfaces >= max_backfaces) {
return;
}
continue;
}
```

此处根据是更新辐照度还是可见性做不同计算。对辐照度：

```
if (weight >= EPSILON) {
vec3 radiance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
sample_position, 0).rgb;
radiance.rgb *= energy_conservation;
// Storing the sum of the weights in alpha
temporarily
result += vec4(radiance * weight, weight);
}
```

对可见性，读取并限制距离：

```
 float probe_max_ray_distance = 1.0f * 1.5f;
if (weight >= EPSILON) {
float distance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
sample_position, 0).w;
// Limit distance
distance = min(abs(distance),
probe_max_ray_distance);
vec3 value = vec3(distance, distance *
distance, 0);
// Storing the sum of the weights in alpha
temporarily
result += vec4(value * weight, weight);
}
}
```

最后应用权重：

```
if (result.w > EPSILON) {
result.xyz /= result.w;
result.w = 1.0f;
}
```

读取上一帧的辐照度或可见性，用滞后混合。对辐照度：

```
vec4 previous_value = imageLoad( irradiance_image,
coords.xy );
result = mix( result, previous_value, hysteresis );
imageStore(irradiance_image, coords.xy, result);
```

对可见性：

```
vec2 previous_value = imageLoad( visibility_image,
coords.xy ).rg;
 result.rg = mix( result.rg, previous_value,
hysteresis );
imageStore(visibility_image, coords.xy,
vec4(result.rg, 0, 1));
```

非边界像素的着色器逻辑到此结束。等待本地线程组完成后，将像素复制到边界：

```
// NOTE: returning here.
return;
}
```

接着处理边界像素。由于本地线程组大小与每个方块一致，当一组完成后可用已更新的数据复制边界像素。这是一种优化，避免再派发两个着色器并加屏障等待更新完成。实现上述代码后，需等待组内完成：

```
groupMemoryBarrier();
barrier();
```

有了这些屏障，所有组都会完成。辐照度/可见性已写入纹理，可按图 14.6 的顺序复制边界像素以支持双线性采样。先计算源像素坐标：

```
const uint probe_pixel_x = gl_GlobalInvocationID.x %
probe_with_border_side;
 const uint probe_pixel_y = gl_GlobalInvocationID.y %
probe_with_border_side;
bool corner_pixel = (probe_pixel_x == 0 ||
probe_pixel_x == probe_last_pixel) && (probe_pixel_y
== 0 || probe_pixel_y == probe_last_pixel);
bool row_pixel = (probe_pixel_x > 0 && probe_pixel_x <
probe_last_pixel);
ivec2 source_pixel_coordinate = coords.xy;
if ( corner_pixel ) {
source_pixel_coordinate.x += probe_pixel_x == 0 ?
probe_side_length : -probe_side_length;
source_pixel_coordinate.y += probe_pixel_y == 0 ?
probe_side_length : -probe_side_length;
}
else if ( row_pixel ) {
source_pixel_coordinate.x +=
k_read_table[probe_pixel_x - 1];
source_pixel_coordinate.y += (probe_pixel_y > 0) ?
-1 : 1;
}
else {
source_pixel_coordinate.x += (probe_pixel_x > 0) ?
-1 : 1;
source_pixel_coordinate.y +=
k_read_table[probe_pixel_y - 1];
}
```

再将源像素复制到当前边界。对辐照度：

```
vec4 copied_data = imageLoad( irradiance_image,
source_pixel_coordinate );
imageStore( irradiance_image, coords.xy, copied_data );
```

对可见性：

```
 vec4 copied_data = imageLoad( visibility_image,
source_pixel_coordinate );
imageStore( visibility_image, coords.xy, copied_data );
}
```

此时更新后的辐照度与可见性已可供场景采样。

### 间接光照采样（Indirect lighting sampling）

该计算着色器负责读取间接辐照度，供光照使用。它使用工具函数 `sample_irradiance`，该函数也在 ray-hit 着色器内用于模拟无限次反射。

先看计算着色器主体。在使用四分之一分辨率时，遍历 2×2 邻域取最近深度并记录像素索引：

```
layout (local_size_x = 8, local_size_y = 8, local_size_z =
1) in;
void main() {
ivec3 coords = ivec3(gl_GlobalInvocationID.xyz);
int resolution_divider = output_resolution_half == 1 ?
2 : 1;
vec2 screen_uv = uv_nearest(coords.xy, resolution /
resolution_divider);
float raw_depth = 1.0f;
int chosen_hiresolution_sample_index = 0;
if (output_resolution_half == 1) {
float closer_depth = 0.f;
for ( int i = 0; i < 4; ++i ) {
float depth = texelFetch(global_textures
[nonuniformEXT(depth_fullscreen_texture_index)
], (coords.xy) * 2 + pixel_offsets[i], 0).r;
if ( closer_depth < depth ) {
closer_depth = depth;
chosen_hiresolution_sample_index = i;
 }
}
raw_depth = closer_depth;
}
```

用缓存的最近深度索引读取法线：

```
vec3 normal = vec3(0);
if (output_resolution_half == 1) {
vec2 encoded_normal = texelFetch(global_textures
[nonuniformEXT(normal_texture_index)],
(coords.xy) * 2 + pixel_offsets
[chosen_hiresolution_sample_index], 0).rg;
normal = normalize(octahedral_decode(encoded_normal)
);
}
```

得到深度与法线后，反推世界位置并用法线采样辐照度：

```
const vec3 pixel_world_position =
world_position_from_depth(screen_uv, raw_depth,
inverse_view_projection)
vec3 irradiance = sample_irradiance(
pixel_world_position, normal, camera_position.xyz );
imageStore(global_images_2d[ indirect_output_index ],
coords.xy, vec4(irradiance,1));
}
```

该着色器的第二部分是 `sample_irradiance`，承担主要计算。先计算偏置向量，使采样略微在几何体前方，以减少泄漏：

```
vec3 sample_irradiance( vec3 world_position, vec3 normal,
vec3 camera_position ) {
 const vec3 V = normalize(camera_position.xyz –
world_position);
// Bias vector to offset probe sampling based on normal
and view vector.
const float minimum_distance_between_probes = 1.0f;
vec3 bias_vector = (normal * 0.2f + V * 0.8f) *
(0.75f minimum_distance_between_probes) *
self_shadow_bias;
vec3 biased_world_position = world_position +
bias_vector;
// Sample at world position + probe offset reduces
shadow leaking.
ivec3 base_grid_indices =
world_to_grid_indices(biased_world_position);
vec3 base_probe_world_position =
grid_indices_to_world_no_offsets( base_grid_indices
);
```

得到采样世界位置（加偏置后）的网格世界位置与索引。再计算采样点在单元内各轴上的相对位置：

```
// alpha is how far from the floor(currentVertex)
position. on [0, 1] for each axis.
vec3 alpha = clamp((biased_world_position –
base_probe_world_position) , vec3(0.0f), vec3(1.0f));
```

然后对采样点周围的八个相邻探针采样：

```
vec3 sum_irradiance = vec3(0.0f);
float sum_weight = 0.0f;
```

对每个探针，从索引计算其世界空间位置：

```
 // Iterate over adjacent probe cage
for (int i = 0; i < 8; ++i) {
// Compute the offset grid coord and clamp to the
probe grid boundary
// Offset = 0 or 1 along each axis
ivec3 offset = ivec3(i, i >> 1, i >> 2) &
ivec3(1);
ivec3 probe_grid_coord = clamp(base_grid_indices +
offset, ivec3(0), probe_counts - ivec3(1));
int probe_index =
probe_indices_to_index(probe_grid_coord);
vec3 probe_pos =
grid_indices_to_world(probe_grid_coord,
probe_index);
```

根据网格单元顶点计算三线性权重，在探针间平滑过渡：

```
vec3 trilinear = mix(1.0 - alpha, alpha, offset);
float weight = 1.0;
```

可见性纹理存储深度与深度平方，对减轻光泄漏很有帮助。该测试基于方差，类似方差阴影贴图（Variance Shadow Map）：

```
vec3 probe_to_biased_point_direction =
biased_world_position - probe_pos;
float distance_to_biased_point =
length(probe_to_biased_point_direction);
probe_to_biased_point_direction *= 1.0 /
distance_to_biased_point;
{
vec2 uv = get_probe_uv
(probe_to_biased_point_direction,
probe_index, probe_texture_width,
probe_texture_height,
 probe_side_length );
vec2 visibility = textureLod(global_textures
[nonuniformEXT(grid_visibility_texture_index)],
uv, 0).rg;
float mean_distance_to_occluder = visibility.x;
float chebyshev_weight = 1.0;
```

若采样点相对探针处于“阴影”中，计算切比雪夫（Chebyshev）权重：

```
if (distance_to_biased_point >
mean_distance_to_occluder) {
float variance = abs((visibility.x *
visibility.x) - visibility.y);
const float distance_diff =
distance_to_biased_point –
mean_distance_to_occluder;
chebyshev_weight = variance / (variance +
(distance_diff * distance_diff));
// Increase contrast in the weight
chebyshev_weight = max((chebyshev_weight *
chebyshev_weight * chebyshev_weight),
0.0f);
}
// Avoid visibility weights ever going all of
the way to zero
chebyshev_weight = max(0.05f, chebyshev_weight);
weight *= chebyshev_weight;
}
```

得到该探针的权重后，应用三线性偏移、读取辐照度并累加贡献：

```
vec2 uv = get_probe_uv(normal, probe_index,
probe_texture_width, probe_texture_height,
probe_side_length );
vec3 probe_irradiance =
 textureLod(global_textures
[nonuniformEXT(grid_irradiance_output_index)],
uv, 0).rgb;
// Trilinear weights
weight *= trilinear.x * trilinear.y * trilinear.z +
0.001f;
sum_irradiance += weight * probe_irradiance;
sum_weight += weight;
}
```

所有探针采样完后，对最终辐照度缩放并返回：

```
vec3 irradiance = 0.5f * PI * sum_irradiance /
sum_weight;
return irradiance;
}
```

至此我们看完了辐照度采样的计算着色器与工具函数。还可以对采样施加更多滤波以进一步平滑图像，但这是由可见性数据增强的最基础版本。下面看如何修改 `calculate_lighting` 以加入漫反射间接光。

### 对 calculate_lighting 的修改（Modifications to the calculate_lighting method）

在 `lighting.h` 着色器文件中，在直接光照计算完成后加入：

```
vec3 F = fresnel_schlick_roughness(max(dot(normal, V),
0.0), F0, roughness);
vec3 kS = F;
vec3 kD = 1.0 - kS;
kD *= 1.0 - metallic;
 vec3 indirect_irradiance = textureLod(global_textures
[nonuniformEXT(indirect_lighting_texture_index)],
screen_uv, 0).rgb;
vec3 indirect_diffuse = indirect_irradiance *
base_colour.rgb;
const float ao = 1.0f;
final_color.rgb += (kD * indirect_diffuse) * ao;
```

其中 `base_colour` 来自 G-buffer 的反照率（albedo），`final_color` 为已计入所有直接光照的像素颜色。基础算法到此完整，还剩一个着色器：探针偏移着色器，它根据光线追踪得到的每条光线距离计算每个探针的世界空间偏移，避免探针与几何体相交。

### 探针偏移着色器（Probe offsets shader）

该计算着色器利用光线追踪 pass 的每条光线距离，根据背面与正面命中数量计算偏移。先检查无效探针索引，避免写错内存：

```
layout (local_size_x = 32, local_size_y = 1, local_size_z =
1) in;
void main() {
ivec3 coords = ivec3(gl_GlobalInvocationID.xyz);
// Invoke this shader for each probe
int probe_index = coords.x;
const int total_probes = probe_counts.x *
probe_counts.y * probe_counts.z;
// Early out if index is not valid
if (probe_index >= total_probes) {
return;
}
```

再根据光线追踪得到的距离查找正面与背面命中。先声明所需变量：

```
int closest_backface_index = -1;
float closest_backface_distance = 100000000.f;
int closest_frontface_index = -1;
float closest_frontface_distance = 100000000.f;
int farthest_frontface_index = -1;
float farthest_frontface_distance = 0;
int backfaces_count = 0;
```

对该探针的每条光线读取距离并判断是正面还是背面（命中着色器中对背面存负距离）：

```
// For each ray cache front/backfaces index and
distances.
for (int ray_index = 0; ray_index < probe_rays;
++ray_index) {
ivec2 ray_tex_coord = ivec2(ray_index,
probe_index);
float ray_distance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
ray_tex_coord, 0).w;
// Negative distance is stored for backface hits in
the Ray Tracing Hit shader.
if ( ray_distance <= 0.0f ) {
++backfaces_count;
// Distance is a positive value, thus negate
ray_distance as it is negative already if
// we are inside this branch.
if ( (-ray_distance) <
closest_backface_distance ) {
closest_backface_distance = ray_distance;
closest_backface_index = ray_index;
}
}
else {
 // Cache either closest or farther distance and
indices for this ray.
if (ray_distance < closest_frontface_distance)
{
closest_frontface_distance = ray_distance;
closest_frontface_index = ray_index;
} else if (ray_distance >
farthest_frontface_distance) {
farthest_frontface_distance = ray_distance;
farthest_frontface_index = ray_index;
}
}
}
```

得到该探针的正面与背面索引与距离后，因探针是逐步移动的，读取上一帧的偏移：

```
vec4 current_offset = vec4(0);
// Read previous offset after the first frame.
if ( first_frame == 0 ) {
const int probe_counts_xy = probe_counts.x *
probe_counts.y;
ivec2 probe_offset_sampling_coordinates =
ivec2(probe_index % probe_counts_xy, probe_index
/ probe_counts_xy);
current_offset.rgb = texelFetch(global_textures
[nonuniformEXT(probe_offset_texture_index)],
probe_offset_sampling_coordinates, 0).rgb;
}
```

判断探针是否可视为在几何体内部，并计算沿该方向、但在探针间距限制（即单元）内的偏移：

```
vec3 full_offset = vec3(10000.f);
vec3 cell_offset_limit = max_probe_offset *
probe_spacing;
 // Check if a fourth of the rays was a backface, we can
assume the probe is inside a geometry.
const bool inside_geometry = (float(backfaces_count) /
probe_rays) > 0.25f;
if (inside_geometry && (closest_backface_index != -1))
{
// Calculate the backface direction.
const vec3 closest_backface_direction =
closest_backface_distance * normalize(
mat3(random_rotation) *
spherical_fibonacci(closest_backface_index,
probe_rays) );
```

求单元内使探针移动的最大偏移：

```
const vec3 positive_offset = (current_offset.xyz +
cell_offset_limit) / closest_backface_direction;
const vec3 negative_offset = (current_offset.xyz –
cell_offset_limit) / closest_backface_direction;
const vec3 maximum_offset = vec3(max
(positive_offset.x, negative_offset.x),
max(positive_offset.y, negative_offset.y),
max(positive_offset.z, negative_offset.z));
// Get the smallest of the offsets to scale the
direction
const float direction_scale_factor = min(min
(maximum_offset.x, maximum_offset.y),
maximum_offset.z) - 0.001f;
// Move the offset in the opposite direction of the
backface one.
full_offset = current_offset.xyz –
closest_backface_direction *
direction_scale_factor;
}
```

若没有背面命中，则让探针小幅移动至稳定位置：

```
 else if (closest_frontface_distance < 0.05f) {
// In this case we have a very small hit distance.
// Ensure that we never move through the farthest
frontface
// Move minimum distance to ensure not moving on a
future iteration.
const vec3 farthest_direction = min(0.2f,
farthest_frontface_distance) * normalize(
mat3(random_rotation) *
spherical_fibonacci(farthest_frontface_index,
probe_rays) );
const vec3 closest_direction = normalize(mat3
(random_rotation) * spherical_fibonacci
(closest_frontface_index, probe_rays));
// The farthest frontface may also be the closest
if the probe can only
// see one surface. If this is the case, don't move
the probe.
if (dot(farthest_direction, closest_direction) <
0.5f) {
full_offset = current_offset.xyz +
farthest_direction;
}
}
```

仅当偏移在间距或单元限制内时更新，并写入对应纹理：

```
if (all(lessThan(abs(full_offset), cell_offset_limit)))
{
current_offset.xyz = full_offset;
}
const int probe_counts_xy = probe_counts.x *
probe_counts.y;
const int probe_texel_x = (probe_index %
probe_counts_xy);
const int probe_texel_y = probe_index /
probe_counts_xy;
imageStore(global_images_2d[ probe_offset_texture_index
 ], ivec2(probe_texel_x, probe_texel_y),
current_offset);
}
```

至此探针偏移计算完成。该着色器展示了如何巧妙利用已有信息（此处为每条光线的探针距离）将探针移出与几何体的相交。我们给出的是功能完整的 DDGI 版本，仍可改进和扩展，例如：用分类系统禁用无贡献探针、加入以相机为中心、不同间距级联的移动网格；与手放体积结合可形成完整的漫反射全局光照系统。虽然本技术需要支持光线追踪的 GPU，但可对静态场景预烘焙辐照度与可见性并在老 GPU 上使用。其他改进包括根据探针亮度变化调整滞后、按距离与重要性做交错探针更新等。这些想法都体现了 DDGI 的可配置性，鼓励读者尝试并做出自己的改进。

## 小结（Summary）

本章介绍了 DDGI 技术：先从 DDGI 所实现的全局光照现象讲起，然后概览算法并逐步详解，最后编写并注释了实现中的全部着色器。DDGI 已能增强渲染帧的光照，仍可继续优化。其有用之处在于可配置性：可调整辐照度与可见性纹理分辨率、光线数、探针数与探针间距，以适配不同档次的支持光线追踪的 GPU。下一章将加入另一项提升光照精度的要素：反射。

## 延伸阅读（Further reading）

全局光照在渲染文献中覆盖面极广，此处仅列出与 DDGI 实现更相关的链接。DDGI 的概念主要来自 2017 年 Nvidia 团队，核心思想见：https://morgan3d.github.io/articles/2019-04-01-ddgi/index.html。

DDGI 及其演化的原始文章如下，并附有对实现很有帮助的补充代码：

- https://casual-effects.com/research/McGuire2017LightField/index.html
- https://www.jcgt.org/published/0008/02/01/
- https://jcgt.org/published/0010/02/01/

以下是对支持球谐的 DDGI 的很好综述，并包含双线性插值边界像素复制的唯一图示，还涉及其他有趣话题：https://handmade.network/p/75/monter/blog/p/7288-engine_work__global_illumination_with_irradiance_probes。

Nvidia 的 DDGI 演示：https://developer.download.nvidia.com/video/gputechconf/gtc/2019/presentation/s9900-irradiance-fields-rtx-diffuse-global-illumination-for-local-and-cloud-graphics.pdf。

直观的全局光照入门：https://www.scratchapixel.com/lessons/3d-basic-rendering/global-illumination-path-tracing。

全局光照纲要：https://people.cs.kuleuven.be/~philip.dutre/GI/。

实时渲染综合站：https://www.realtimerendering.com/。
