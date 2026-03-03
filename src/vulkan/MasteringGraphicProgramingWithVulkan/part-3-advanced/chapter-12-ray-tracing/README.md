Getting Started with Ray Tracing
In this chapter, we are introducing ray tracing into our rendering
pipeline. Thanks to the addition of hardware support for ray tracing in
modern GPUs, it’s now possible to integrate ray tracing techniques into
real-time rendering.
Ray tracing requires a different setup compared to the traditional
rendering pipeline, which is why we are dedicating a whole chapter to
setting up a ray tracing pipeline. We are going to cover in detail how to
set up a shader binding table to tell the API which shaders to invoke
when an intersection test for a given ray succeeds or fails.
Next, we are going to explain how to create the Bottom Level
Acceleration Structure (BLAS) and Top Level Acceleration Structure
(TLAS). These Acceleration Structures (AS) are needed to speed up
scene ray traversal and ensure that ray tracing can be performed at an
interactive rate.
In this chapter, we’ll cover the following main topics:
• Introduction to ray tracing in Vulkan
• Building the BLAS and TLAS
• Defining and creating a ray tracing pipeline
Technical requirements
The code for this chapter can be found at the following URL: https://
github.com/PacktPublishing/Mastering-Graphics-Programming-with-
Vulkan/tree/main/source/chapter12.
Introduction to ray tracing in
Vulkan
Ray tracing support in hardware was first introduced in 2018 with the
NVidia RTX series. Originally, ray tracing support in Vulkan was only
available through an NVidia extension, but later, the functionality was
ratified through a Khronos extension to allow multiple vendors to
support the ray tracing API in Vulkan. We are dedicating a full chapter
just to the setup of a ray tracing pipeline, as it requires new constructs
that are specific to ray tracing.
The first departure from the traditional rendering pipeline is the need to
organize our scene into Acceleration Structures. These structures are
needed to speed up scene traversal, as they allow us to skip entire
meshes that the ray has no chance to intersect with.
These Acceleration Structures are usually implemented as a Bounded
Volume Hierarchy (BVH). A BVH subdivides the scene and individual
meshes into bounding boxes and then organizes them into a tree. Leaf
nodes of this tree are the only nodes containing geometry data, while
parent nodes define the position and extent of the volume that
encompasses the children.
A simple scene and its BVH representation is illustrated by the following
image:
Figure 12.1 – A scene example on the left and its BVH representation on
the right (source: Wikipedia)
The Vulkan API makes a further distinction between a TLAS and BLAS.
A BLAS contains individual mesh definitions. These can then be
grouped into a TLAS, where multiple instances of the same mesh can be
placed in the scene by defining their transform matrices.
This organization is pictured in the following figure:
Figure 12.2 – Each BLAS can be added multiple times to a TLAS with
different shading and transform details (source: Vulkan spec)
Now that we have defined our Acceleration Structures, we can turn our
attention to the ray tracing pipeline. The major change introduced with
ray tracing pipelines is the ability to call other shaders within a shader.
This is achieved by defining shader binding tables. Each slot in these
tables defines one of the following shader types:
• Ray generation: In a traditional ray tracing pipeline, this is the
entry point from which rays are generated. As we will see in later
chapters, rays can also be spawned from fragments and compute
shaders.
• Intersection: This shader allows the application to implement
custom geometry primitives. In Vulkan, we can only define
triangles and Axis-Aligned Bounding Boxes (AABB).
• Any-hit: This is executed after an intersection shader is triggered.
Its main use is to determine whether the hit should be processed
further or ignored.
• Closest hit: This shader is triggered the first time a ray hits a
primitive.
• Miss: This shader is triggered if the ray doesn’t hit any primitive.
• Callable: These are shaders that can be called from within an
existing shader.
The flow is summarized in the following figure:
Figure 12.3 – The shader flow of a ray tracing pipeline (source: Vulkan
spec)
In this section, we have provided an overview of how ray tracing is
implemented in the Vulkan API. In the next section, we are going to
have a better look at how to create Acceleration Structures.
Building the BLAS and TLAS
As we mentioned in the previous section, ray tracing pipelines require
geometry to be organized into Acceleration Structures to speed up the
ray traversal of the scene. In this section, we are going to explain how
to accomplish this in Vulkan.
We start by creating a list of VkAccelerationStructureGeometryKHR
when parsing our scene. For each mesh, this data structure is defined as
follows:
VkAccelerationStructureGeometryKHR geometry{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR };
geometry.geometryType = VK_GEOMETRY_TYPE_TRIANGLES_KHR;
geometry.flags = mesh.is_transparent() ? 0 :
VK_GEOMETRY_OPAQUE_BIT_KHR;
Each geometry structure can define three types of entries: triangles,
AABBs, and instances. We are going to use triangles here, as that’s how
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
Geometry data is defined as it normally would be for traditional draws:
we need to provide a vertex and index buffer, a vertex stride, and a
vertex format. The primitive count is defined in the next structure.
Finally, we also need to fill a
VkAccelerationStructureBuildRangeInfoKHR structure to store the
primitive definition for our mesh:
VkAccelerationStructureBuildRangeInfoKHR build_range_info{ };
build_range_info.primitiveCount = vertex_count;
build_range_info.primitiveOffset = mesh.index_offset;
Now that we have the details for our meshes, we can start building the
BLAS. This is a two-step process. First, we need to query how much
memory our AS requires. We do so by defining a
VkAccelerationStructureBuildGeometryInfoKHR structure:
VkAccelerationStructureBuildGeometryInfoKHR as_info{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD
_GEOMETRY_INFO_KHR };
as_info.type =
VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
as_info.mode =
VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
as_info.geometryCount = scene->geometries.size;
as_info.pGeometries = scene->geometries.data;
These flags tell the Vulkan API that this BLAS could be updated or
compacted in the future:
as_info.flags =
VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR |
VK_BUILD_ACCELERATION_STRUCTURE_ALLOW
_COMPACTION_BIT_KHR;
When querying the size of the AS, we need to provide a list with the
maximum number of primitives for each geometry entry:
for ( u32 range_index = 0; range_index < scene->
geometries.size; range_index++ ) {
max_primitives_count[ range_index ] = scene->
 build_range_infos[ range_index ].primitiveCount;
}
We are now ready to query the size of our AS:
VkAccelerationStructureBuildSizesInfoKHR as_size_info{
VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD
_SIZES_INFO_KHR };
vkGetAccelerationStructureBuildSizesKHR( gpu.vulkan_device,
VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
&as_info, max_primitives_count.data, &as_size_info );
When building an AS, we need to provide two buffers: one for the
actual AS data, and one for a scratch buffer that is used in the building
process. The two buffers are created as follows:
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
This is similar to the code for creating buffers that we have used many
times before, but there are two key differences that we want to
highlight:
• The AS buffer needs to be created with the
VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR
usage flag
• The scratch buffer needs to be created with
VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_KHR. The
ray tracing extension also requires the
VK_KHR_buffer_device_address extension. This allows us to
query the GPU virtual address for a given buffer, but it has to be
created with this usage flag.
Now we have everything we need to create our BLAS. First, we retrieve
a handle for our AS:
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
At this point, scene->blas is only a handle. To build our acceleration,
we populate the remaining fields of our
VkAccelerationStructureBuildGeometryInfoKHR structure:
as_info.dstAccelerationStructure = scene->blas;
as_info.scratchData.deviceAddress =
gpu.get_buffer_device_address(
blas_scratch_buffer_handle );
VkAccelerationStructureBuildRangeInfoKHR* blas_ranges[] = {
scene->build_range_infos.data
};
Finally, we record the command to build the AS:
vkCmdBuildAccelerationStructuresKHR( gpu_commands->
vk_command_buffer, 1, &as_info, blas_ranges );
gpu.submit_immediate( gpu_commands );
Notice that we submit this command immediately. This is required
because it’s not possible to build a BLAS and TLAS on the same
submission, as the TLAS depends on a fully constructed BLAS.
The next and final step it to build the TLAS. The process is similar to the
one we just described for the BLAS and we are going to highlight the
differences. The TLAS is defined by specifying instances to multiple
BLASes, where each BLAS can have its own transform. This is very
similar to traditional instancing: we define our geometry once and it
can be rendered multiple times by simply changing its transform.
We start by defining a VkAccelerationStructureInstanceKHR
structure:
VkAccelerationStructureInstanceKHR tlas_structure{ };
tlas_structure.transform.matrix[ 0 ][ 0 ] = 1.0f;
tlas_structure.transform.matrix[ 1 ][ 1 ] = 1.0f;
tlas_structure.transform.matrix[ 2 ][ 2 ] = 1.0f;
tlas_structure.mask = 0xff;
tlas_structure.flags = VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
tlas_structure.accelerationStructureReference =
blas_address;
As mentioned previously, we provide a BLAS reference and its
transform. We then need to create a buffer to hold this data:
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
Notice the
VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR
usage flag, which is required for buffers that are going to be used
during the AS build.
Next, we define a VkAccelerationStructureGeometryKHR structure:
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
Now that we have defined the structure of our TLAS, we need to query
its size. We won’t repeat the full code, but here are the differences in
the VkAccelerationStructureBuildGeometryInfoKHR structure
compared to when creating a BLAS:
as_info.type =
VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
as_info.geometryCount = 1;
as_info.pGeometries = &tlas_geometry;
After creating the data and scratch buffer for the TLAS, we are ready to
get the TLAS handle:
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
Finally, we can build our TLAS:
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
As before, we submit this command immediately so that the TLAS is
ready when we start rendering. While it’s not possible to build BLAS
and TLAS in the same submission, it is possible to create multiple BLAS
and TLAS in parallel.
Our Acceleration Structures are now ready to be used for ray tracing!
In this section, we have detailed the steps required to create BLASes and
TLASes. We started by recording the triangle primitives for our
geometry. We then used this data to create a BLAS instance, which was
then used as part of a TLAS.
In the next section, we are going to define a ray tracing pipeline that
makes use of these Acceleration Structures.
Defining and creating a ray
tracing pipeline
Now that we have defined our Acceleration Structures, we can turn our
attention to ray tracing pipelines. As we mentioned previously, ray
tracing shaders work differently compared to traditional graphics and
compute shaders. Ray tracing shaders are setup to call other shaders
according to the shader binding table setup.
If you are familiar with C++, you can think of this setup as a simple
form of polymorphism: the interface of a ray tracing pipeline is always
the same, but we can dynamically override which shaders (methods) get
called at runtime. We don’t have to define all the entry points though.
In this example, for instance, we are going to define only a ray
generation, the closest hit, and the miss shader. We are ignoring any-hit
and intersection shaders for now.
As the name implies, the shader binding table can be represented in
table form. This is the binding table we are going to build in our
example:
The order in the table is important, as that’s the order used by the
driver to tell the GPU which shader to invoke according to the stage
that has been triggered.
Before we start building our pipeline, let’s have a look at three example
shaders we are going to use. We start with the ray generation shader,
which is responsible for spawning the rays to traverse our scene. First,
we have to enable the GLSL extension for ray tracing:
#extension GL_EXT_ray_tracing : enable
Next, we have to define a variable that is going to be populated by
other shaders:
layout( location = 0 ) rayPayloadEXT vec4 payload;
We then define a uniform variable that will contain a reference to our
AS:
layout( binding = 1, set = MATERIAL_SET ) uniform
accelerationStructureEXT as;
Finally, we define the parameters for our ray generation call:
{layout( binding = 2, set = MATERIAL_SET ) uniform rayParams
uint sbt_offset;
uint sbt_stride;
uint miss_index;
uint out_image_index;
};
sbt_offset is the offset into our shader binding table, which can be used
in case multiple shaders of the same type are defined within a shader
binding table. In our case, this will be 0, as we only have one entry for
each shader.
sbt_stride is the size of each entry in the binding table. This value has
to be queried for each device by passing a
VkPhysicalDeviceRayTracingPipelinePropertiesKHR structure to
vkGetPhysicalDeviceProperties2.
miss_index is used to compute the index of the miss shader. This can be
used if multiple miss shaders are present within a binding table. It will
be 0 in our use case.
Finally, out_image_index is the index of the image in our bindless
image array to which we are going to write.
Now that we have defined the inputs and outputs of our ray generation
shader, we can invoke the function to trace rays into the scene!
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
The first parameter is the TLAS we want to traverse. Since this is a
parameter to the traceRayEXT function, we could cast rays into
multiple Acceleration Structures in the same shader.
rayFlags is a bit mask that determines which geometry is going to
trigger a callback to our shaders. In this case, we are only interested in
geometry that has the opaque flag.
cullMask is used to match only the entries in the AS that have the same
mask value defined. This allows us to define a single AS that can be
used for multiple purposes.
Finally, the payload determines the location index of the ray tracing
payload we have defined here. This allows us to invoke traceRayEXT
multiple times, with each invocation using a different payload variable.
The other fields are self-explanatory or have been explained previously.
Next, we are going to have a better look at how ray directions are
computed:
vec3 compute_ray_dir( uvec3 launchID, uvec3 launchSize) {
Ray tracing shaders are very similar to compute shaders, and, like
compute shaders, each invocation has an ID. For a ray tracing shader
this is defined in the gl_LaunchIDEXT variable. Likewise,
gl_LaunchSizeEXT defines the total invocation size. This is akin to the
workgroup size for compute shaders.
In our case, we have one invocation per pixel in the image. We compute
x and y in normalized device coordinates (NDCs) as follows:
float x = ( 2 * ( float( launchID.x ) + 0.5 ) / float(
launchSize.x ) - 1.0 );
float y = ( 1.0 - 2 * ( float( launchID.y ) + 0.5 ) /
float( launchSize.y ) );
Notice that we have to invert y, as otherwise, our final image will be
upside-down.
Finally, we compute our world space direction by multiplying the
coordinates by the inverse_view_projection matrix:
vec4 dir = inverse_view_projection * vec4( x, y, 1, 1 );
dir = normalize( dir );
return dir.xyz;
}
Once traceRayEXT returns, the payload variable will contain the value
computed through the other shaders. The final step of the ray
generation is to save the color for this pixel:
imageStore( global_images_2d[ out_image_index ], ivec2(
gl_LaunchIDEXT.xy ), payload );
We are now going to have a look at an example of a closest hit shader:
layout( location = 0 ) rayPayloadInEXT vec4 payload;
void main() {
payload = vec4( 1.0, 0.0, 0.0, 1.0 );
}
The main difference from the ray generation shader is that the payload
is now defined with the rayPayloadInEXT qualifier. It’s also important
that the location matches the one defined in the ray generation shader.
The miss shader is identical, except we use a different color to
distinguish between the two.
Now that we have defined our shader code, we can start building our
pipeline. Compiling ray tracing shader modules works in the same way
as other shaders. The main difference is the shader type. For ray
tracing, these enumerations have been added:
• VK_SHADER_STAGE_RAYGEN_BIT_KHR
• VK_SHADER_STAGE_ANY_HIT_BIT_KHR
• VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR
• VK_SHADER_STAGE_MISS_BIT_KHR
• VK_SHADER_STAGE_INTERSECTION_BIT_KHR
• VK_SHADER_STAGE_CALLABLE_BIT_KHR
For a ray tracing pipeline, we have to populate a new
VkRayTracingShaderGroupCreateInfoKHR structure:
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
In this example, we are defining a general shader, which can be a
generation, miss, or callable shader. In our case, we are defining our ray
generation shader. As you can see, it’s also possible to define other
shaders within the same group entry. We have decided to have
individual entries for each shader type as it allows us more flexibility in
building our shader binding table.
Other shader types are defined similarly, and we are not going to repeat
them here. As a quick example, here is how we define a closest hit
shader:
shader_group_info.type =
VK_RAY_TRACING_SHADER_GROUP_TYPE
_TRIANGLES_HIT_GROUP_KHR;
shader_group_info.closestHitShader = stage_index;
Now that we have our shader groups defined, we can create our
pipeline object:
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
Notice the maxPipelineRayRecursionDepth field. It determines the
maximum number of call stacks in case we have a recursive call to the
rayTraceEXT function. This is needed by the compiler to determine
how much memory could be used by this pipeline at runtime.
We have omitted the pLibraryInfo and pLibraryInterface fields, as we
are not using them. Multiple ray tracing pipelines can be combined to
create a larger program, similar to how you link multiple objects in C+
+. This can help reduce compile times for ray tracing pipelines, as
individual components need to be compiled only once.
The last step is to create our shader binding table. We start by
computing the size required for our table:
u32 group_handle_size =
ray_tracing_pipeline_properties.shaderGroupHandleSize;
sizet shader_binding_table_size = group_handle_size *
shader_state_data->active_shaders;
We simply multiply the handle size by the number of entries in our
table.
Next, we call vkGetRayTracingShaderGroupHandlesKHR to get the
handles of the groups in the ray tracing pipeline:
Array<u8> shader_binding_table_data{ };
shader_binding_table_data.init( allocator,
shader_binding_table_size, shader_binding_table_size );
vkGetRayTracingShaderGroupHandlesKHR( vulkan_device,
pipeline->vk_pipeline, 0, shader_state_data->
active_shaders, shader_binding_table_size,
shader_binding_table_data.data );
Once we have the shader group handles, we can combine them to create
individual tables for each shader type. They are stored in separate
buffers:
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
We only have one entry per table, so we simply copy each group handle
into its buffer. Notice that the buffer has to be created with the
VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR usage flag.
This completes our ray tracing pipeline creation. All that’s left is to
actually use it to generate an image! This is accomplished by the
following code:
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
We define VkStridedDeviceAddressRegionKHR for each shader
binding table. We use the table buffers we previously created. Notice
that we still need to define a table for callable shaders, even if we are
not using them. The width, height, and depth parameters determine
the invocation size of our ray tracing shader.
In this section, we have illustrated how to create and use a ray tracing
pipeline. We started by defining the organization of our shader binding
table. Next, we looked at a basic ray generation and closest hit shader.
We then showed how to create a ray tracing pipeline object and how to
retrieve shader group handles.
These handles were then used to populate the buffers of our shader
binding tables. Finally, we demonstrated how to combine all these
components to invoke our ray tracing pipeline.
Summary
In this chapter, we have provided the details on how to use ray tracing
in Vulkan. We started by explaining two fundamental concepts:
• Acceleration Structures: These are needed to speed up scene
traversal. This is essential to achieve real-time results.
• Shader binding tables: Ray tracing pipelines can invoke multiple
shaders, and these tables are used to tell the API which shaders to
use for which stage.
In the next section, we provided the implementation details to create
TLASes and BLASes. We first record the list of geometries that compose
our mesh. Next, we use this list to create a BLAS. Each BLAS can then
be instanced multiple times within a TLAS, as each BLAS instance
defines its own transform. With this data, we can then create our TLAS.
In the third and final section, we explained how to create a ray tracing
pipeline. We started with the creation of individual shader types. Next,
we demonstrated how to combine these individual shaders into a ray
tracing pipeline and how to generate a shader binding table from a
given pipeline.
Next, we have shown how to write a simple ray generation shader used
in combination with a closest hit shader and a miss shader. Finally, we
demonstrate how to combine all these pieces to trace rays in our scene.
In the next chapter, we are going to leverage all the knowledge from
this chapter to implement ray-traced shadows!
Further reading
As always, we have only provided the most relevant details on how to
use the Vulkan API. We recommend you read the Vulkan specification
for more details. Here is the list of the most relevant sections:
• https://registry.khronos.org/vulkan/specs/1.3-extensions/html/
vkspec.html#pipelines-ray-tracing
• https://registry.khronos.org/vulkan/specs/1.3-extensions/html/
vkspec.html#interfaces-raypipeline
• https://registry.khronos.org/vulkan/specs/1.3-extensions/html/
vkspec.html#acceleration-structure
• https://registry.khronos.org/vulkan/specs/1.3-extensions/html/
vkspec.html#ray-tracing
This website provides more details on Acceleration Structures: https://
www.scratchapixel.com/lessons/3d-basic-rendering/introduction-
acceleration-structure/introduction.
There are plenty of resources online about real-time ray tracing. It’s still
a novel field and subject to ongoing research. A good starting point is
provided by these two freely available books:
• http://www.realtimerendering.com/raytracinggems/rtg/
index.html
• http://www.realtimerendering.com/raytracinggems/rtg2/
index.html