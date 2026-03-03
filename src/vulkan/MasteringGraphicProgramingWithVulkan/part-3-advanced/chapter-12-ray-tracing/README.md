# 第 12 章：光追入门（Getting Started with Ray Tracing）

本章将**光追（ray tracing）**引入渲染管线。借助现代 GPU 的硬件光追支持，已能在实时渲染中集成光追技术。光追的配置与传统渲染管线不同，因此我们单独用一章搭建光追管线：详细说明如何设置 **shader binding table**，以在射线相交测试成功或失败时告诉 API 调用哪些 shader；接着说明如何创建**底层加速结构（BLAS）**与**顶层加速结构（TLAS）**，二者用于加速场景射线遍历、保证交互式光追。

本章主要内容：
- Vulkan 中的光追介绍
- 构建 BLAS 与 TLAS
- 定义与创建光追 pipeline

## 技术需求

本章代码见：https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter12

## Vulkan 中的光追介绍（Introduction to ray tracing in Vulkan）

硬件光追于 2018 年随 Nvidia RTX 系列首次出现。Vulkan 中最初仅通过 Nvidia 扩展支持，后由 Khronos 扩展标准化，供多厂商实现。我们单独用一章讲解光追管线搭建，因其需要光追专用的新结构。与传统管线的首要区别是：场景必须组织成**加速结构（Acceleration Structures，AS）**，以加速遍历并跳过射线不可能相交的整块 mesh。加速结构通常实现为**包围体层次（BVH）**：将场景与各 mesh 划分为包围盒并组织成树；叶节点才包含几何数据，父节点定义包含子节点的体积位置与范围。Figure 12.1 – 左：场景示例；右：其 BVH 表示（来源：Wikipedia）。Vulkan 进一步区分 **TLAS** 与 **BLAS**：BLAS 存放单个 mesh 定义，可被多次加入 TLAS，通过变换矩阵在场景中放置同一 mesh 的多个实例。Figure 12.2 – 每个 BLAS 可以不同着色与变换多次加入 TLAS（来源：Vulkan spec）。有了加速结构后，可转向**光追 pipeline**：其核心变化是 shader 内可调用其它 shader，通过 **shader binding table** 实现；表中每个槽对应一种 shader 类型：**Ray generation**：传统光追管线的入口，从此发射射线；后文也会从 fragment/compute shader 发射。**Intersection**：用于实现自定义几何图元；Vulkan 中仅支持三角形与 **AABB**。**Any-hit**：在 intersection 触发后执行，用于决定该命中是否继续处理或忽略。**Closest hit**：射线首次命中图元时触发。**Miss**：射线未命中任何图元时触发。**Callable**：可从现有 shader 内调用的 shader。流程见 Figure 12.3 – 光追管线的 shader 流程（来源：Vulkan spec）。本节概述了 Vulkan 中光追的实现方式；下一节详述如何创建加速结构。

## 构建 BLAS 与 TLAS（Building the BLAS and TLAS）

上节提到，光追管线需将几何组织成加速结构以加速场景射线遍历。本节说明在 Vulkan 中的具体做法。解析场景时先创建 `VkAccelerationStructureGeometryKHR` 列表。对每个 mesh，该结构定义如下：
VkAccelerationStructureGeometryKHR geometry{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR };
geometry.geometryType = VK_GEOMETRY_TYPE_TRIANGLES_KHR;
geometry.flags = mesh.is_transparent() ? 0 :
VK_GEOMETRY_OPAQUE_BIT_KHR;
Each geometry structure can define three types of entries: triangles,
AABBs, and instances. We are going to use triangles here, as that's how
our meshes are defined. We are going to use instances later when
defining the TLAS.
The following code demonstrates how the triangles structure is used:
geometry.geometry.triangles.sType =
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY
_TRIANGLES_DATA_KHR;
geometry.geometry.triangles.vertexFormat =
VK_FORMAT_R32G32B32_SFLOAT;
geometry.geometry.triangles.vertexData.deviceAddress =
renderer->gpu->get_buffer_device_address(
mesh.position_buffer ) + mesh.position_offset;
geometry.geometry.triangles.vertexStride = sizeof( float )
* 3;
geometry.geometry.triangles.maxVertex = vertex_count;
geometry.geometry.triangles.indexType = mesh.index_type;
geometry.geometry.triangles.indexData.deviceAddress =
renderer->gpu->get_buffer_device_address(
mesh.index_buffer );
几何数据与传统绘制类似：需提供顶点与索引缓冲、顶点步长与格式；图元数量在下一结构中定义。最后填充 `VkAccelerationStructureBuildRangeInfoKHR` 存放该 mesh 的图元定义：
VkAccelerationStructureBuildRangeInfoKHR build_range_info{ };
build_range_info.primitiveCount = vertex_count;
build_range_info.primitiveOffset = mesh.index_offset;
有了各 mesh 的几何信息后即可构建 BLAS，分两步。先查询 AS 所需内存，通过填充 `VkAccelerationStructureBuildGeometryInfoKHR` 实现：
VkAccelerationStructureBuildGeometryInfoKHR as_info{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD
_GEOMETRY_INFO_KHR };
as_info.type =
VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
as_info.mode =
VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
as_info.geometryCount = scene->geometries.size;
as_info.pGeometries = scene->geometries.data;
下列标志表示该 BLAS 日后可更新或压缩：
as_info.flags =
VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR |
VK_BUILD_ACCELERATION_STRUCTURE_ALLOW
_COMPACTION_BIT_KHR;
查询 AS 大小时需提供各几何条目的最大图元数列表：
for ( u32 range_index = 0; range_index < scene->
geometries.size; range_index++ ) {
max_primitives_count[ range_index ] = scene->
 build_range_infos[ range_index ].primitiveCount;
}
然后查询 AS 大小：
VkAccelerationStructureBuildSizesInfoKHR as_size_info{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD
_SIZES_INFO_KHR };
vkGetAccelerationStructureBuildSizesKHR( gpu.vulkan_device,
VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
&as_info, max_primitives_count.data, &as_size_info );
构建 AS 需要两个 buffer：一个存 AS 数据，一个作构建用的 scratch buffer。创建如下：
as_buffer_creation.set(
VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR,
ResourceUsageType::Immutable,
as_size_info.accelerationStructureSize )
.set_device_only( true )
.set_name( "blas_buffer" );
scene->blas_buffer = gpu.create_buffer(
as_buffer_creation );
as_buffer_creation.set(
VK_BUFFER_USAGE_STORAGE_BUFFER_BIT |
VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_KHR,
ResourceUsageType::Immutable,
as_size_info.buildScratchSize )
.set_device_only( true )
.set_name( "blas_scratch_buffer" );
BufferHandle blas_scratch_buffer_handle =
gpu.create_buffer( as_buffer_creation );
与以往创建 buffer 类似，但有两点不同：AS buffer 需带 `VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR`；scratch buffer 需带 `VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_KHR`，光追扩展还依赖 `VK_KHR_buffer_device_address`，以便查询 buffer 的 GPU 虚拟地址。准备好后先创建 AS 并取得句柄：
VkAccelerationStructureCreateInfoKHR as_create_info{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE
_CREATE_INFO_KHR };
as_create_info.buffer = blas_buffer->vk_buffer;
as_create_info.offset = 0;
as_create_info.size =
as_size_info.accelerationStructureSize;
as_create_info.type =
VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
vkCreateAccelerationStructureKHR( gpu.vulkan_device,
&as_create_info, gpu.vulkan_allocation_callbacks,
&scene->blas );
此时 `scene->blas` 仅是句柄。为执行构建，补全 `VkAccelerationStructureBuildGeometryInfoKHR` 的其余字段：
as_info.dstAccelerationStructure = scene->blas;
as_info.scratchData.deviceAddress =
gpu.get_buffer_device_address(
blas_scratch_buffer_handle );
VkAccelerationStructureBuildRangeInfoKHR* blas_ranges[] = {
scene->build_range_infos.data
};
最后录制构建 AS 的命令：
vkCmdBuildAccelerationStructuresKHR( gpu_commands->
vk_command_buffer, 1, &as_info, blas_ranges );
gpu.submit_immediate( gpu_commands );
注意此处**立即提交**该命令：BLAS 与 TLAS 不能在同一提交中构建，因为 TLAS 依赖已构建完成的 BLAS。下一步是构建 TLAS，流程与 BLAS 类似，仅强调差异。TLAS 通过为多个 BLAS 指定实例来定义，每个实例可有自己的变换，与传统 **instancing** 类似：几何只定义一次，通过变换多次渲染。先定义 `VkAccelerationStructureInstanceKHR`：
VkAccelerationStructureInstanceKHR tlas_structure{ };
tlas_structure.transform.matrix[ 0 ][ 0 ] = 1.0f;
tlas_structure.transform.matrix[ 1 ][ 1 ] = 1.0f;
tlas_structure.transform.matrix[ 2 ][ 2 ] = 1.0f;
tlas_structure.mask = 0xff;
tlas_structure.flags = VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
tlas_structure.accelerationStructureReference =
blas_address;
如前所述，提供 BLAS 引用与其变换；再创建存放该数据的 buffer：
as_buffer_creation.reset().set(
VK_BUFFER_USAGE_ACCELERATION_STRUCTURE
_BUILD_INPUT_READ_ONLY_BIT_KHR | VK_BUFFER_USAGE_
SHADER_DEVICE_ADDRESS_BIT,
ResourceUsageType::Immutable, sizeof(
VkAccelerationStructureInstanceKHR ) )
.set_data( &tlas_structure )
.set_name( "tlas_instance_buffer" );
BufferHandle tlas_instance_buffer_handle =
gpu.create_buffer( as_buffer_creation );
注意 `VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR` 标志，用于在 AS 构建期间被读取的 buffer。接着定义 `VkAccelerationStructureGeometryKHR`：
VkAccelerationStructureGeometryKHR tlas_geometry{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR };
tlas_geometry.geometryType =
VK_GEOMETRY_TYPE_INSTANCES_KHR;
tlas_geometry.geometry.instances.sType =
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE
_GEOMETRY_INSTANCES_DATA_KHR;
tlas_geometry.geometry.instances.arrayOfPointers = false;
tlas_geometry.geometry.instances.data.deviceAddress =
gpu.get_buffer_device_address(
tlas_instance_buffer_handle );
TLAS 结构定义好后查询其大小；不重复完整代码，仅给出相对 BLAS 时 `VkAccelerationStructureBuildGeometryInfoKHR` 的差异：
as_info.type =
VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
as_info.geometryCount = 1;
as_info.pGeometries = &tlas_geometry;
创建 TLAS 的数据与 scratch buffer 后，取得 TLAS 句柄：
as_create_info.buffer = tlas_buffer->vk_buffer;
as_create_info.offset = 0;
as_create_info.size =
 as_size_info.accelerationStructureSize;
as_create_info.type =
VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
vkCreateAccelerationStructureKHR( gpu.vulkan_device,
&as_create_info,
gpu.vulkan_allocation_
callbacks,
&scene->tlas );
最后构建 TLAS：
as_info.dstAccelerationStructure = scene->tlas;
as_info.scratchData.deviceAddress =
gpu.get_buffer_device_address(
tlas_scratch_buffer_handle );
VkAccelerationStructureBuildRangeInfoKHR tlas_range_info{ };
tlas_range_info.primitiveCount = 1;
VkAccelerationStructureBuildRangeInfoKHR* tlas_ranges[] = {
&tlas_range_info
};
vkCmdBuildAccelerationStructuresKHR( gpu_commands->
vk_command_buffer, 1, &as_info, tlas_ranges );
同样立即提交，以便开始渲染时 TLAS 已就绪。BLAS 与 TLAS 不能同次提交构建，但可并行构建多个 BLAS 与 TLAS。加速结构至此可用于光追。本节详述了创建 BLAS 与 TLAS 的步骤：先记录几何的三角形图元，用其创建 BLAS，再作为 TLAS 的实例。下一节定义使用这些加速结构的光追 pipeline。

## 定义与创建光追 pipeline（Defining and creating a ray tracing pipeline）

有了加速结构后，可着手光追 pipeline。如前所述，光追 shader 与传统图形/compute shader 不同，按 shader binding table 的配置调用其它 shader。熟悉 C++ 可将其理解为一种多态：光追管线的接口固定，运行时动态决定调用哪些 shader（方法）。不必定义所有入口；本例仅定义 ray generation、closest hit 与 miss shader，暂不实现 any-hit 与 intersection。Shader binding table 可表示为表格，示例中我们将构建如下表格：表中**顺序**重要，驱动按触发阶段据此决定调用哪个 shader。在构建 pipeline 前，先看将用到的三个示例 shader。从 **ray generation shader** 开始，负责发射遍历场景的射线。先启用 GLSL 光追扩展：
#extension GL_EXT_ray_tracing : enable
接着定义由其它 shader 写入的变量：`layout( location = 0 ) rayPayloadEXT vec4 payload;`。再定义指向 AS 的 uniform：`layout( binding = 1, set = MATERIAL_SET ) uniform accelerationStructureEXT as;`。最后定义 ray generation 调用的参数（rayParams）：`sbt_offset` 为 shader binding table 的偏移，同类型有多个 shader 时使用；本例每类仅一条，为 0。`sbt_stride` 为表中每条目大小，需通过 `VkPhysicalDeviceRayTracingPipelinePropertiesKHR` 传给 `vkGetPhysicalDeviceProperties2` 查询。`miss_index` 用于计算 miss shader 索引，表中有多个 miss 时使用；本例为 0。`out_image_index` 为 bindless 图像数组中要写入的图像索引。定义好 ray generation 的输入输出后，即可调用函数向场景发射射线：
traceRayEXT( as, // top level acceleration structure
gl_RayFlagsOpaqueEXT, // rayFlags
0xff, // cullMask
sbt_offset,
sbt_stride,
miss_index,
camera_position.xyz, // origin
0.0, // Tmin
compute_ray_dir( gl_LaunchIDEXT,
gl_LaunchSizeEXT ),
100.0, // Tmax
0 // payload
);
第一个参数为要遍历的 TLAS；作为 `traceRayEXT` 的参数，同一 shader 中可向多个加速结构发射射线。`rayFlags` 为位掩码，决定哪些几何会触发我们的 shader；此处仅关心带 opaque 标志的几何。`cullMask` 用于只匹配 AS 中具有相同 mask 的条目，从而一个 AS 可多用途使用。最后的 payload 指定此处定义的光追 payload 的 location 索引，便于多次调用 `traceRayEXT` 且每次使用不同 payload。其余参数含义明确或已说明。下面看射线方向如何计算。光追 shader 与 compute 类似，每次调用有 ID（`gl_LaunchIDEXT`），`gl_LaunchSizeEXT` 为总调用规模，类似 compute 的 workgroup 大小。本例每像素一次调用，在 NDC 中计算 x、y 如下：
float x = ( 2 * ( float( launchID.x ) + 0.5 ) / float(
launchSize.x ) - 1.0 );
float y = ( 1.0 - 2 * ( float( launchID.y ) + 0.5 ) /
float( launchSize.y ) );
注意 y 需取反，否则图像会上下颠倒。最后用 `inverse_view_projection` 矩阵乘坐标得到世界空间方向：
vec4 dir = inverse_view_projection * vec4( x, y, 1, 1 );
dir = normalize( dir );
return dir.xyz;
}
`traceRayEXT` 返回后，payload 中为其它 shader 计算的结果。ray generation 的最后一步是将该像素颜色写入：
imageStore( global_images_2d[ out_image_index ], ivec2(
gl_LaunchIDEXT.xy ), payload );
下面看 closest hit shader 示例：payload 改用 `rayPayloadInEXT` 限定符，且 location 须与 ray generation 中一致。Miss shader 结构相同，仅用不同颜色区分。有了 shader 代码后即可构建 pipeline。光追 shader 模块的编译方式与其它 shader 相同，区别在于 shader 类型；光追新增了下列 stage：
• VK_SHADER_STAGE_RAYGEN_BIT_KHR
• VK_SHADER_STAGE_ANY_HIT_BIT_KHR
• VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR
• VK_SHADER_STAGE_MISS_BIT_KHR
• VK_SHADER_STAGE_INTERSECTION_BIT_KHR
• VK_SHADER_STAGE_CALLABLE_BIT_KHR
光追 pipeline 需填充 `VkRayTracingShaderGroupCreateInfoKHR`：
shader_group_info.sType =
VK_STRUCTURE_TYPE_RAY_TRACING_SHADER
_GROUP_CREATE_INFO_KHR;
shader_group_info.type =
VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR;
shader_group_info.generalShader = stage index;
shader_group_info.closestHitShader = VK_SHADER_UNUSED_KHR;
shader_group_info.anyHitShader = VK_SHADER_UNUSED_KHR;
shader_group_info.intersectionShader =
VK_SHADER_UNUSED_KHR;
本例定义的是 general shader（可为 ray generation、miss 或 callable）；这里即 ray generation。同一 group 条目内也可定义其它 shader；我们选择每种类型单独一条目以便更灵活地构建 shader binding table。其它 shader 类型定义方式类似；以 closest hit 为例：
shader_group_info.type =
VK_RAY_TRACING_SHADER_GROUP_TYPE
_TRIANGLES_HIT_GROUP_KHR;
shader_group_info.closestHitShader = stage_index;
定义好 shader group 后创建 pipeline 对象：
VkRayTracingPipelineCreateInfoKHR pipeline_info{
VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_CREATE_INFO_KHR };
pipeline_info.stageCount = shader_state_data->
active_shaders;
pipeline_info.pStages = shader_state_data->
shader_stage_info;
pipeline_info.groupCount = shader_state_data->
active_shaders;
pipeline_info.pGroups = shader_state_data->
shader_group_info;
pipeline_info.maxPipelineRayRecursionDepth = 1;
pipeline_info.layout = pipeline_layout;
vkCreateRayTracingPipelinesKHR( vulkan_device,
VK_NULL_HANDLE, pipeline_cache, 1, &pipeline_info,
vulkan_allocation_callbacks, &pipeline->vk_pipeline );
pipeline->vk_bind_point =
VkPipelineBindPoint::VK_PIPELINE
_BIND_POINT_RAY_TRACING_KHR;
注意 `maxPipelineRayRecursionDepth`：它限定对 `traceRayEXT` 的递归调用最大深度，编译器据此估算 pipeline 运行时内存。我们未使用 `pLibraryInfo` 与 `pLibraryInterface`；多个光追 pipeline 可像 C++ 链接多目标文件一样组合成更大程序，有助于减少编译时间。最后一步是创建 shader binding table，先计算表所需大小：
u32 group_handle_size =
ray_tracing_pipeline_properties.shaderGroupHandleSize;
sizet shader_binding_table_size = group_handle_size *
shader_state_data->active_shaders;
即句柄大小乘以表条目数。接着调用 `vkGetRayTracingShaderGroupHandlesKHR` 获取 pipeline 中各 group 的句柄：
Array<u8> shader_binding_table_data{ };
shader_binding_table_data.init( allocator,
shader_binding_table_size, shader_binding_table_size );
vkGetRayTracingShaderGroupHandlesKHR( vulkan_device,
pipeline->vk_pipeline, 0, shader_state_data->
active_shaders, shader_binding_table_size,
shader_binding_table_data.data );
拿到 shader group 句柄后，按 shader 类型分别建表并存入不同 buffer：
BufferCreation shader_binding_table_creation{ };
shader_binding_table_creation.set(
VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR |
 VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_KHR,
ResourceUsageType::Immutable, group_handle_size
).set_data( shader_binding_table_data.data
).set_name( "shader_binding_table_raygen" );
pipeline->shader_binding_table_raygen = create_buffer(
shader_binding_table_creation );
shader_binding_table_creation.set_data(
shader_binding_table_data.data + group_handle_size )
.set_name( "shader_binding_table_hit" );
pipeline->shader_binding_table_hit = create_buffer(
shader_binding_table_creation );
shader_binding_table_creation.set_data(
shader_binding_table_data.data + ( group_handle_size *
2 ) ).set_name( "shader_binding_table_miss" );
pipeline->shader_binding_table_miss = create_buffer(
shader_binding_table_creation );
每表仅一条目，故将各 group 句柄拷入对应 buffer。Buffer 须带 `VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR`。光追 pipeline 创建至此完成，最后用其生成图像：
u32 shader_group_handle_size = gpu_device->
ray_tracing_pipeline_properties.shaderGroupHandleSize;
VkStridedDeviceAddressRegionKHR raygen_table{ };
raygen_table.deviceAddress = gpu_device->
get_buffer_device_address( pipeline->
shader_binding_table_raygen );
raygen_table.stride = shader_group_handle_size;
raygen_table.size = shader_group_handle_size;
VkStridedDeviceAddressRegionKHR hit_table{ };
hit_table.deviceAddress = gpu_device->
get_buffer_device_address( pipeline->
shader_binding_table_hit );
VkStridedDeviceAddressRegionKHR miss_table{ };
miss_table.deviceAddress = gpu_device->
 get_buffer_device_address( pipeline->
shader_binding_table_miss );
VkStridedDeviceAddressRegionKHR callable_table{ };
vkCmdTraceRaysKHR( vk_command_buffer, &raygen_table,
&miss_table, &hit_table, &callable_table, width,
height, depth );
为每种 shader binding table 定义 `VkStridedDeviceAddressRegionKHR`，使用之前创建的表 buffer。即使不用 callable，也需为其提供表。width、height、depth 决定光追 shader 的调用规模。本节说明了如何创建与使用光追 pipeline：先定义 shader binding table 的组织，再看基础 ray generation 与 closest hit shader，然后创建 pipeline 并获取 shader group 句柄，用其填充各表 buffer，最后组合调用光追管线。

## 小结（Summary）

本章介绍了在 Vulkan 中使用光追的要点。先说明两个基础概念：**加速结构**——加速场景遍历，对实时光追至关重要；**Shader binding table**——光追管线可调用多种 shader，表用来指定各阶段使用的 shader。接着给出创建 TLAS 与 BLAS 的实现：先记录组成 mesh 的几何列表，用其创建 BLAS，每个 BLAS 可在 TLAS 中多次实例化（每实例自有变换），再创建 TLAS。第三节说明如何创建光追 pipeline：从各 shader 类型到组合成 pipeline、从 pipeline 生成 shader binding table，并给出了与 closest hit、miss 配合的简单 ray generation shader，以及如何组合这些部分在场景中追踪射线。下一章将用本章知识实现光追阴影。

## 延伸阅读（Further reading）

仅给出 Vulkan API 最相关部分，更多细节请阅规范：
- https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#pipelines-ray-tracing
- https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#interfaces-raypipeline
- https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#acceleration-structure
- https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#ray-tracing
加速结构入门：https://www.scratchapixel.com/lessons/3d-basic-rendering/introduction-acceleration-structure/introduction
实时光追资料很多，仍属较新领域。可参考两本免费书：
- http://www.realtimerendering.com/raytracinggems/rtg/index.html
- http://www.realtimerendering.com/raytracinggems/rtg2/index.html