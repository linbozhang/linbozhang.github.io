# Chapter 6: GPU-Driven Rendering

# 6



# GPU-Driven Rendering


In this chapter, we will upgrade the geometry pipeline to use the latest available technology: **mesh shaders** and **meshlets**. The idea behind this technique is to move the flow of mesh rendering from the CPU to the GPU, moving culling and draw command generation into different shaders.

We will first work on the mesh structure on the CPU, by separating it into different *meshlets* that are groups of up to 64 triangles, each with an individual bounding sphere. We will then use compute shaders to perform culling and write a list of commands to draw the meshlets in the different passes. Finally, we will use the mesh shaders to render the meshlets. There will also be a compute version provided, as mesh shaders are still available only on Nvidia GPUs for now.

Traditionally, geometry culling has been performed on the CPU. Each mesh on the scene is usually represented by an **axis aligned bounding box** (**AABB**). An AABB can easily be culled against the camera frustum, but with the increase in scene complexity, a large portion of frame time could be spent on the culling step.

This is usually the first step in a rendering pipeline, as we need to determine which meshes to submit for drawing. This means it’s hard to find other work that could be done in parallel. Another pain point of doing frustum culling on the CPU is that it’s hard to determine which objects are occluded and don’t need to be drawn.

At every frame, we need to re-sort all elements based on the camera position. When there are hundreds of thousands of elements in the scene, this is usually unfeasible. Finally, some meshes, terrain, for example, are organized in large areas that end up always being drawn, even if only a small part of them is visible.

Thankfully, we can move some of this computation to the GPU and take advantage of its parallel capabilities. The techniques we are going to present in this chapter will allow us to perform frustum and occlusion culling on the GPU. To make the process as efficient as possible, we are going to generate the list of draw commands directly on the GPU.

In this chapter, we’re going to cover the following main topics:

- Breaking down large meshes into meshlets


- Processing meshlets using task and mesh shaders to perform back-face and frustum culling


- Performing efficient occlusion culling using compute shaders


- Generating draw commands on the GPU and using indirect drawing functions





# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter6](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter6).

# Breaking down large meshes into meshlets


In this chapter, we are going to focus primarily on the geometry stage of the pipeline, the one before the shading stage. Adding some complexity to the geometry stage of the pipeline will pay dividends in later stages as we’ll reduce the number of pixels that need to be shaded.

说明

When we refer to the geometry stage of the graphics pipeline, we don’t mean geometry shaders. The geometry stage of the pipeline refers to **input assembly** (**IA**), vertex processing, and **primitive assembly** (**PA**). Vertex processing can, in turn, run one or more of the following shaders: vertex, geometry, tessellation, task, and mesh shaders.

Content geometry comes in many shapes, sizes, and complexity. A rendering engine must be able to deal with meshes from small, detailed objects to large terrains. Large meshes (think terrain or buildings) are usually broken down by artists so that the rendering engine can pick out the different levels of details based on the distance from the camera of these objects.

Breaking down meshes into smaller chunks can help cull geometry that is not visible, but some of these meshes are still large enough that we need to process them in full, even if only a small portion is visible.

Meshlets have been developed to address these problems. Each mesh is subdivided into groups of vertices (usually 64) that can be more easily processed on the GPU.

The following image illustrates how meshes can be broken down into meshlets:



 ![Figure 6.1 – A meshlet subdivision example](image/B18395_06_01.jpg)


Figure 6.1 – A meshlet subdivision example

These vertices can make up an arbitrary number of triangles, but we usually tune this value according to the hardware we are running on. In Vulkan, the recommended value is **126** (as written in [https://developer.nvidia.com/blog/introduction-turing-mesh-shaders/](https://developer.nvidia.com/blog/introduction-turing-mesh-shaders/), the number is needed to reserve some memory for writing the primitive count with each meshlet).

说明

At the time of writing, mesh and task shaders are only available on Nvidia hardware through its extension. While some of the APIs described in this chapter are specific to this extension, the concepts can be generally applied and implemented using generic compute shaders. A more generic version of this extension is currently being worked on by the Khronos committee so that mesh and task shaders should soon be available from other vendors!

Now that we have a much smaller number of triangles, we can use them to have much finer-grained control by culling meshlets that are not visible or are being occluded by other objects.

Together with the list of vertices and triangles, we also generate some additional data for each meshlet that will be very useful later on to perform back-face, frustum, and occlusion culling.

One additional possibility (that will be added in the future) is to choose the **level of detail** (**LOD**) of a mesh and, thus, a different subset of meshlets based on any wanted heuristic.

The first of this additional data represents the bounding sphere of a meshlet, as shown in the following screenshot:



 ![Figure 6.2 – A meshlet bounding spheres example; some of the larger spheres have been hidden for clarity](image/B18395_06_02.jpg)


Figure 6.2 – A meshlet bounding spheres example; some of the larger spheres have been hidden for clarity

Some of you might ask: why not AABBs? AABBs require at least two **vec3** of data: one for the center and one for the half-size vector. Another encoding could be to store the minimum and maximum corners. Instead, spheres can be encoded with a single **vec4**: a **vec3** for the center plus the radius.

Given that we might need to process millions of meshlets, each saved byte counts! Spheres can also be more easily tested for frustum and occlusion culling, as we will describe later in the chapter.

The next additional piece of data that we’re going to use is the meshlet cone, as shown in the following screenshot:



 ![Figure 6.3 – A meshlet cone example; not all cones are displayed for clarity](image/B18395_06_03.jpg)


Figure 6.3 – A meshlet cone example; not all cones are displayed for clarity

The cone indicates the direction a meshlet is facing and will be used for back-face culling.

Now we have a better understanding of why meshlets are useful and how we can use them to improve the culling of larger meshes, let’s see how we generate them in code!

## Generating meshlets


We are using an open source library, called **MeshOptimizer** ([https://github.com/zeux/meshoptimizer](https://github.com/zeux/meshoptimizer)) to generate the meshlets. An alternative library is **meshlete** ([https://github.com/JarkkoPFC/meshlete](https://github.com/JarkkoPFC/meshlete)) and we encourage you to try both to find the one that best suits your needs.

After we have loaded the data (vertices and indices) for a given mesh, we are going to generate the list of meshlets. First, we determine the maximum number of meshlets that could be generated for our mesh and allocate memory for the vertices and indices arrays that will describe the meshlets:

```
const sizet max_meshlets = meshopt_buildMeshletsBound(
&#160;&#160;&#160;&#160;indices_accessor.count, max_vertices, max_triangles );

Array<meshopt_Meshlet> local_meshlets;
local_meshlets.init( temp_allocator, max_meshlets,
&#160;&#160;&#160;&#160;max_meshlets );

Array<u32> meshlet_vertex_indices;
meshlet_vertex_indices.init( temp_allocator, max_meshlets *
&#160;&#160;&#160;&#160;max_vertices, max_meshlets* max_vertices );
Array<u8> meshlet_triangles;
meshlet_triangles.init( temp_allocator, max_meshlets *
&#160;&#160;&#160;&#160;max_triangles * 3, max_meshlets* max_triangles * 3 );
```


Notice the types for the indices and triangle arrays. We are not modifying the original vertex or index buffer, but only generating a list of indices in the original buffers. Another interesting aspect is that we only need 1 byte to store the triangle indices. Again, saving memory is very important to keep meshlet processing efficient!

The next step is to generate our meshlets:

```
const sizet max_vertices = 64;
const sizet max_triangles = 124;
const f32 cone_weight = 0.0f;

sizet meshlet_count = meshopt_buildMeshlets(
&#160;&#160;&#160;&#160;local_meshlets.data,
&#160;&#160;&#160;&#160;meshlet_vertex_indices.data,
&#160;&#160;&#160;&#160;meshlet_triangles.data, indices,
&#160;&#160;&#160;&#160;indices_accessor.count,
&#160;&#160;&#160;&#160;vertices,
&#160;&#160;&#160;&#160;position_buffer_accessor.count,
&#160;&#160;&#160;&#160;sizeof( vec3s ),
&#160;&#160;&#160;&#160;max_vertices,
&#160;&#160;&#160;&#160;max_triangles,
&#160;&#160;&#160;&#160;cone_weight );
```


As mentioned in the preceding step, we need to tell the library the maximum number of vertices and triangles that a meshlet can contain. In our case, we are using the recommended values for the Vulkan API. The other parameters include the original vertex and index buffer, and the arrays we have just created that will contain the data for the meshlets.

Let’s have a better look at the data structure of each meshlet:

```
struct meshopt_Meshlet
{
unsigned int vertex_offset;
unsigned int triangle_offset;

unsigned int vertex_count;
unsigned int triangle_count;
};
```


Each meshlet is described by two offsets and two counts, one for the vertex indices and one for the indices of the triangles. Note that these offsets refer to **meshlet_vertex_indices** and **meshlet_triangles** that are populated by the library, not the original vertex and index buffers of the mesh.

Now that we have the meshlet data, we need to upload it to the GPU. To keep the data size to a minimum, we store the positions at full resolution while we compress the normals to 1 byte for each dimension and UV coordinates to half-float for each dimension. In pseudocode, this is as follows:

```
meshlet_vertex_data.normal = ( normal + 1.0 ) * 127.0;
meshlet_vertex_data.uv_coords = quantize_half( uv_coords );
```


The next step is to extract the additional data (bounding sphere and cone) for each meshlet:

```
for ( u32 m = 0; m < meshlet_count; ++m ) {
&#160;&#160;&#160;&#160;meshopt_Meshlet& local_meshlet = local_meshlets[ m ];

&#160;&#160;&#160;&#160;meshopt_Bounds meshlet_bounds =
&#160;&#160;&#160;&#160;meshopt_computeMeshletBounds(
&#160;&#160;&#160;&#160;meshlet_vertex_indices.data +
&#160;&#160;&#160;&#160;local_meshlet.vertex_offset,
&#160;&#160;&#160;&#160;meshlet_triangles.data +
&#160;&#160;&#160;&#160;local_meshlet.triangle_offset,
&#160;&#160;&#160;&#160;local_meshlet.triangle_count,
&#160;&#160;&#160;&#160;vertices,
&#160;&#160;&#160;&#160;position_buffer_accessor
&#160;&#160;&#160;&#160;.count,
&#160;&#160;&#160;&#160;sizeof( vec3s ) );

&#160;&#160;&#160;&#160;...
}
```


We loop over all the meshlets and we call the MeshOptimizer API that computes the bounds for each meshlet. Let’s see in more detail the structure of the data that is returned:

```
struct meshopt_Bounds
{
&#160;&#160;&#160;&#160;float center[3];
&#160;&#160;&#160;&#160;float radius;

&#160;&#160;&#160;&#160;float cone_apex[3];
&#160;&#160;&#160;&#160;float cone_axis[3];
&#160;&#160;&#160;&#160;float cone_cutoff;

&#160;&#160;&#160;&#160;signed char cone_axis_s8[3];
&#160;&#160;&#160;&#160;signed char cone_cutoff_s8;
};
```


The first four floats represent the bounding sphere. Next, we have the cone definition, which is comprised of the cone direction (**cone_axis**) and the cone angle (**cone_cutoff**). We are not using the **cone_apex** value as it makes the back-face culling computation more expensive. However, it can lead to better results.

Once again, notice that quantized values (**cone_axis_s8** and **cone_cutoff_s8**) help us reduce the size of the data required for each meshlet.

Finally, meshlet data is copied into GPU buffers and it will be used during the execution of task and mesh shaders.

For each processed mesh, we will also save an offset and count of meshlets to add a coarse culling based on the parent mesh: if the mesh is visible, then its meshlets will be added.

In this section, we have described what meshlets are and why they are useful to improve the culling of geometry on the GPU. Next, we showed the data structures that are used in our implementation. Now that our data is ready, it’s time for it to be consumed by task and mesh shaders. That’s the topic of the next section!

# Understanding task and mesh shaders


Before we begin, we should mention that mesh shaders can be used without task shaders. If, for instance, you wanted to perform culling or some other pre-processing step on the meshlets on the CPU, you are free to do so.

Also, note that task and mesh shaders replace vertex shaders in the graphics pipeline. The output of mesh shaders is going to be consumed by the fragment shader directly.

The following diagram illustrates the differences between the traditional geometry pipeline and the mesh shader pipeline:



 ![Figure 6.4 – The difference between traditional and mesh pipeline﻿](image/B18395_06_04.jpg)


Figure 6.4 – The difference between traditional and mesh pipeline

In this section, we are going to provide an overview of how task and mesh shaders work and then use this information to implement back-face and frustum culling using task shaders.

Both task and mesh shaders use the same execution model of compute shaders, with some minor changes. The output of task shaders is consumed directly by a mesh shader, and for both types, we can specify the thread group size.

Task shaders (sometimes also referred to as amplification shaders) can be thought of as filters. We submit all meshlets for processing when invoking a task shader, and the task shader will output the meshlets that have passed the filter.

The following diagram provides an example of meshlets that are processed by the task shader. The meshlets that are rejected won’t be processed further.



 ![Figure 6.5 – The task shader determines which meshlets to cull. The culled meshlets won’t be processed by the mesh shader](image/B18395_06_05.jpg)


Figure 6.5 – The task shader determines which meshlets to cull. The culled meshlets won’t be processed by the mesh shader

The mesh shader then takes the active meshlets and performs the final processing as you normally would in a vertex shader.

While this is only a high-level overview of task and mesh shaders, there isn’t much more to it. We will provide more resources in the *Further reading* section if you’d like to know more about the inner workings of this feature.

Next, we are going to explain how to implement task and mesh shaders in Vulkan!

## Implementing task shaders


As we mentioned previously, task and mesh shaders are available through an extension of the Vulkan API. We have shown how to check for extensions before, so we are not duplicating the code in this chapter. Please refer to the code for more details.

The extension also introduces two new pipeline stages, **VK_PIPELINE_STAGE_TASK_SHADER_BIT_NV** and **VK_PIPELINE_STAGE_MESH_SHADER_BIT_NV**, that can be used to place pipeline barriers to ensure data used by these stages is synchronized correctly.

Task shaders can be treated like any compute shader: we create a pipeline that includes an (optional) task shader module, a mesh shader, and a fragment shader. Invoking a task shader is done with the following API:

```
vkCmdDrawMeshTasksNV( vk_command_buffer, task_count,
&#160;&#160;&#160;&#160;first_task );
```


Think of **task_count** as the workgroup size of a compute shader. There is also an indirect variant that can read the invocation details for multiple draws from a buffer:

```
vkCmdDrawMeshTasksIndirectCountNV( vk_command_buffer,
&#160;&#160;&#160;&#160;mesh_draw_buffer, 0, draw_count, stride );
```


We use this variant in our code as it allows us to have only one draw call per scene and give the GPU full control over which meshlets will be drawn.

With indirect rendering, we write the commands in a GPU program as we would do on the CPU, and we additionally read a buffer to know how many commands are there. We will see command writing in the *GPU culling using compute* section of this chapter.

We now turn our attention to the shader implementation. Task and mesh shaders require that their GLSL extension be enabled, otherwise, the compiler might treat the code as a regular compute shader:

```
#extension GL_NV_mesh_shader: require
```


Since we are using an indirect command to invoke our shader, we need to enable another extension that will let us access the **draw** ID for the current shader invocation:

```
#extension GL_ARB_shader_draw_parameters : enable
```


Note that this extension is enabled in the **platform.h** header and not directly in the shader code. As we mentioned, task shaders are akin to compute shaders. In fact, the first directive in our shader is to determine the thread group size:

```
layout(local_size_x = 32) in;
```


Here, **local_size_y** and **local_size_z** will be ignored even if specified. We can now move to the main body of the shader. We start by determining which mesh and meshlet we need to process:

```
uint thread_index = gl_LocalInvocationID.x;
uint group_index = gl_WorkGroupID.x;
uint meshlet_index = group_index * 32 + thread_index;

uint mesh_instance_index = draw_commands[ gl_DrawIDARB ]
&#160;&#160;&#160;&#160;.drawId;
```


The **gl_DrawIDARB** draw index comes from the invocation of each **vkCmdDrawMeshTasksNV** through the commands written in the indirect buffer.

Next, we load the data for the current meshlet. First, we determine the world position and the size of the meshlet bounding sphere:

```
vec4 center = model * vec4(meshlets[mi].center, 1);
float scale = length( model[0] );
float radius = meshlets[mi].radius * scale;
```


Next, we restore the **cone_axis** value (remember, they are stored as a single byte) and **cone_cutoff**:

```
vec3 cone_axis = mat3( model ) *
&#160;&#160;&#160;vec3(int(meshlets[mi].cone_axis[0]) / 127.0,
&#160;&#160;&#160;int(meshlets[mi].cone_axis[1]) / 127.0,
&#160;&#160;&#160;int(meshlets[mi].cone_axis[2]) / 127.0);
float cone_cutoff = int(meshlets[mi].cone_cutoff) / 127.0;
```


We now have all of the data we need to perform back-face and frustum culling:

```
accept = !coneCull(center.xyz, radius, cone_axis,
&#160;&#160;&#160;&#160;cone_cutoff, eye.xyz);
```


Next, **coneCull** is implemented as follows:

```
bool coneCull(vec3 center, float radius, vec3 cone_axis,
float cone_cutoff, vec3 camera_position)
{
&#160;&#160;&#160;&#160;return dot(center - camera_position, cone_axis) >=
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;cone_cutoff * length(center - camera_position) +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;radius;
}
```


This code first computes the cosine of the angle between the cone axis and the vector toward the camera from the center of the bounding sphere. Then it scales the cone cutoff (which is the cosine of the cut-off half angle) by the distance between the camera and the center of the bounding sphere and adds the radius of the bounding sphere.

This determines whether the cone is pointing away from the camera, and should be culled or, if it’s pointing toward the camera, it should be kept.

The next step is to perform frustum culling. First, we transform the center of the bounding sphere into camera space:

```
center = world_to_camera * center;
```


Next, we check against the six frustum planes to determine whether the bounding sphere is inside the frustum:

```
for ( uint i = 0; i < 6; ++i ) {
&#160;&#160;&#160;&#160;frustum_visible = frustum_visible &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(dot( frustum_planes[i], center) > -radius);
}
```


We accept the meshlet if it’s both visible and not considered back facing:

```
accept = accept && frustum_visible;
```


The final step is to write out the indices of the visible meshlets and their number. The output data structure is defined as follows:

```
out taskNV block
{
&#160;&#160;&#160;&#160;uint meshletIndices[32];
};
```


We use the subgroup instructions of GLSL for this step, and it’s worth going through line by line if it’s the first time you have seen this syntax. To access these instructions, the following extension must be enabled:

```
#extension GL_KHR_shader_subgroup_ballot: require
```


First, we set a bit for the active shader invocation depending on whether the meshlet is considered visible or not:

```
uvec4 ballot = subgroupBallot(accept);
```


Next, we determine which bit was set by the previous call and use it to store the active meshlet index:

```
uint index = subgroupBallotExclusiveBitCount(ballot);

if (accept)
&#160;&#160;&#160;&#160;meshletIndices[index] = meshlet_index;
```


Finally, we count all the bits set across this thread group and store them in the **gl_TaskCountNV** variable:

```
uint count = subgroupBallotBitCount(ballot);

if (ti == 0)
&#160;&#160;&#160;&#160;gl_TaskCountNV = count;
```


The **gl_TaskCountNV** variable is used by the GPU to determine how many mesh shader invocations are needed to process the meshlets that have not been occluded. The **if** is needed so that we write **TaskCount** only once per meshlet.

This concludes our implementation of task shaders. Next, we are going to look at our mesh shader implementation.

## Implementing mesh shaders


After performing meshlet culling in the task shader, we need to process the active meshlets. This is similar to a regular vertex shader, however, there are some important differences that we’d like to point out.

Like task shaders, mesh shaders can be considered compute shaders, and the first directive is to determine the thread group size:

```
layout(local_size_x = 32) in;
```


We then have to read the data that has been written by the task shader:

```
in taskNV block
{
&#160;&#160;&#160;&#160;uint meshletIndices[32];
};
```


Next, we define the data we are going to output. We first determine the maximum number of vertices and primitives (triangles in our case) that we could write:

```
layout(triangles, max_vertices = 64, max_primitives = 124) out;
```


We follow with the same data we might usually output from a vertex shader:

```
layout (location = 0) out vec2 vTexcoord0[];
layout (location = 1) out vec4 vNormal_BiTanX[];
layout (location = 2) out vec4 vTangent_BiTanY[];
layout (location = 3) out vec4 vPosition_BiTanZ[];
layout (location = 4) out flat uint mesh_draw_index[];
```


Notice, though, that we are using an array of values, as we can output up to 64 vertices per invocation.

Now that we have our input and output values, we can move to the shader implementation. Like before, we first determine our mesh and meshlet index:

```
uint ti = gl_LocalInvocationID.x;
uint mi = meshletIndices[gl_WorkGroupID.x];

MeshDraw mesh_draw = mesh_draws[ meshlets[mi].mesh_index ];
uint mesh_instance_index = draw_commands[gl_DrawIDARB +
total_count].drawId;
```


Next, we determine the vertex and index offset and count for the active meshlet:

```
uint vertexCount = uint(meshlets[mi].vertexCount);
uint triangleCount = uint(meshlets[mi].triangleCount);
uint indexCount = triangleCount * 3;

uint vertexOffset = meshlets[mi].dataOffset;
uint indexOffset = vertexOffset + vertexCount;
```


We then process the vertices for the active meshlet:

```
for (uint i = ti; i < vertexCount; i += 32)
{
&#160;&#160;&#160;&#160;uint vi = meshletData[vertexOffset + i];

vec3 position = vec3(vertex_positions[vi].v.x,
&#160;&#160;&#160;vertex_positions[vi].v.y,
&#160;&#160;&#160;vertex_positions[vi].v.z);

&#160;&#160;&#160;&#160;// normals, tangents, etc.

&#160;&#160;&#160;&#160;gl_MeshVerticesNV[ i ].gl_Position = view_projection *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(model * vec4(position, 1));

&#160;&#160;&#160;&#160;mesh_draw_index[ i ] = meshlets[mi].mesh_index;
}
```


Notice we are writing to the **gl_MeshVerticesNV** variable. This variable is used by the GPU to keep track of the vertices we output and their index. This data will then be used by the rasterizer to draw the resulting triangles on the screen.

Next, we write out the indices:

```
uint indexGroupCount = (indexCount + 3) / 4;

for (uint i = ti; i < indexGroupCount; i += 32)
{
&#160;&#160;&#160;&#160;writePackedPrimitiveIndices4x8NV(i * 4,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshletData[indexOffset + i]);
}
```


The **writePackedPrimitiveIndices4x8NV** instruction has been introduced specifically for mesh shaders and it allows them to write four indices at once. As we mentioned previously, indices require only 1 byte to be stored, as we can’t have values greater than 64. They are packed into **meshletData**, which is an unsigned **int** array.

If indices were stored in a different format, we would need to write them out individually to the **gl_PrimitiveIndicesNV** variable.

Finally, we write the primitive count in the appropriate variable:

```
if (ti == 0)
&#160;&#160;&#160;&#160;gl_PrimitiveCountNV = uint(meshlets[mi].triangleCount);
```


This concludes our mesh shader implementation.

In this section, we have given an overview of how task and mesh shaders work and how they relate to compute shaders. Next, we provided a walk-through of our task and mesh shader implementation and highlighted the main differences from regular vertex shaders.

In the next section, we are going to extend our implementation by adding occlusion culling.

# GPU culling using compute


In the previous section, we demonstrated how to perform back-face and frustum culling on meshlets. In this section, we are going to implement frustum and occlusion culling using compute shaders.

Depending on the rendering pipeline, occlusion culling is usually done through a depth pre-pass, where we write only the depth buffer. The depth buffer can then be used during the G-Buffer pass to avoid shading fragments that we already know are occluded.

The downside of this approach is that we have to draw the scene twice and, unless there is other work that can overlap with the depth pre-pass, have to wait for the depth pre-pass to complete before proceeding to the next step.

The algorithm described in this section was first presented at [https://advances.realtimerendering.com/s2015/aaltonenhaar_siggraph2015_combined_final_footer_220dpi.pdf](https://advances.realtimerendering.com/s2015/aaltonenhaar_siggraph2015_combined_final_footer_220dpi.pdf).

Here’s how it works:

- Using the depth buffer from the previous frame, we render the visible objects in the scene and perform mesh and meshlet frustum and occlusion culling. This could lead to false negatives, for example, meshes or meshlets that are visible in this frame but were not visible before. We store the list of these objects so that any false positives can be resolved in the next phase.


- The previous step generates a list of draw commands directly in a compute shader. This list will be used to draw the visible objects using an indirect draw command.


- We now have an updated depth buffer, and we update the depth pyramid as well.


- We can now re-test the objects that have been culled in the first phase and generate a new draw list to remove any false positives.


- We draw the remaining objects and generate our final depth buffer. This will then be used as the starting point for the next frame, and the process will repeat.




Now that we have a better understanding of the steps of the occlusion algorithm, let’s see in detail how it is implemented.

## Depth pyramid generation


When describing the occlusion algorithm, we mentioned the use of the depth buffer. However, we are not using the depth buffer directly. What we use instead is called a **depth pyramid**. You can think of it as the mipmap of the depth buffer.

The main difference from traditional mipmaps is that we can’t use bi-linear interpolation to compute the lower level. If we were to use regular interpolation, we would compute depth values that don’t exist in the scene.

说明

As we’ll see later in the book, this applies in general to sampling depth textures. You should either use nearest neighbor sampling or specific samplers with min/max compare operations. Check out [https://www.khronos.org/registry/vulkan/specs/1.3-extensions/man/html/VkSamplerReductionMode.html](https://www.khronos.org/registry/vulkan/specs/1.3-extensions/man/html/VkSamplerReductionMode.html) for more info.

Instead, we read the four fragments we want to reduce and pick the maximum value. We pick the maximum because our depth value goes from **0** to **1** and we need to make sure we cover the full range of values. If you are using **inverted-z**, the depth values go from **1** to **0** and the minimum value has to be used instead.

We perform this step using a compute shader. We start by transitioning the depth texture to a read state:

```
util_add_image_barrier( gpu, gpu_commands->
&#160;&#160;&#160;&#160;vk_command_buffer, depth_texture,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;RESOURCE_STATE_SHADER_RESOURCE, 0, 1, true );
```


Then, we loop over the levels of the depth pyramid:

```
u32 width = depth_pyramid_texture->width;
u32 height = depth_pyramid_texture->
&#160;&#160;&#160;&#160;height for ( u32 mip_index = 0; mip_index <
&#160;&#160;&#160;&#160;depth_pyramid_texture->mipmaps; ++mip_index ) {
&#160;&#160;&#160;&#160;util_add_image_barrier( gpu, gpu_commands->
&#160;&#160;&#160;&#160;vk_command_buffer, depth_pyramid_texture->
&#160;&#160;&#160;&#160;vk_image, RESOURCE_STATE_UNDEFINED,
&#160;&#160;&#160;&#160;RESOURCE_STATE_UNORDERED_ACCESS,
&#160;&#160;&#160;&#160;mip_index, 1, false );
```


The barrier in the preceding example is needed to ensure the image we are writing to is correctly set up. Next, we compute the group size for this level and invoke the compute shader:

```
&#160;&#160;&#160;&#160;u32 group_x = ( width + 7 ) / 8;
&#160;&#160;&#160;&#160;u32 group_y = ( height + 7 ) / 8;

&#160;&#160;&#160;&#160;gpu_commands->dispatch( group_x, group_y, 1 );
```


As we’ll see in a moment, the thread group size of the compute shader is set to 8x8. We have to take this into account to compute the right group size.

Finally, we transition the image of the current level so that we can safely read from it at the next iteration:

```
&#160;&#160;&#160;&#160;util_add_image_barrier( gpu, gpu_commands->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vk_command_buffer, depth_pyramid_texture->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vk_image, RESOURCE_STATE_UNORDERED_ACCESS,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;RESOURCE_STATE_SHADER_RESOURCE, mip_index,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1, false );

&#160;&#160;&#160;&#160;width /= 2;
&#160;&#160;&#160;&#160;height /= 2;
}
```


We also update the width and height to match the size of the next level. The compute shader implementation is relatively simple:

```
ivec2 texel_position00 = ivec2( gl_GlobalInvocationID.xy )
&#160;&#160;&#160;&#160;* 2;
ivec2 texel_position01 = texel_position00 + ivec2(0, 1);
ivec2 texel_position10 = texel_position00 + ivec2(1, 0);
ivec2 texel_position11 = texel_position00 + ivec2(1, 1);
```


We first compute the positions for the texels we want to reduce. Next, we read the depth value for these texels:

```
float color00 = texelFetch( src, texel_position00, 0 ).r;
float color01 = texelFetch( src, texel_position01, 0 ).r;
float color10 = texelFetch( src, texel_position10, 0 ).r;
float color11 = texelFetch( src, texel_position11, 0 ).r;
```


Finally, we compute the maximum value and store it in the right position of the next level in the pyramid:

```
float result = max( max( max( color00, color01 ),
&#160;&#160;&#160;&#160;color10 ), color11 );
imageStore( dst, ivec2( gl_GlobalInvocationID.xy ),
&#160;&#160;&#160;&#160;vec4( result, 0, 0, 0 ) );
```


The **max** operation is needed because the depth goes from **0** (close to the camera) to **1** (far from the camera). When using **inverse-depth**, it should be set to **min**. When down-sampling, we want the farthest of the four samples to avoid over-occluding.

Now that we have computed the depth pyramid, let’s see how it’s going to be used for occlusion culling.

## Occlusion culling


The implementation of this step is done entirely in a compute shader. We are going to highlight the main sections of the code. We start by loading the current mesh:

```
uint mesh_draw_index =
&#160;&#160;&#160;mesh_instance_draws[mesh_instance_index]
&#160;&#160;&#160;.mesh_draw_index;

MeshDraw mesh_draw = mesh_draws[mesh_draw_index];

mat4 model =
&#160;&#160;&#160;mesh_instance_draws[mesh_instance_index].model;
```


Next, we compute the bounding sphere position and radius in view space:

```
vec4 bounding_sphere = mesh_bounds[mesh_draw_index];

vec4 world_bounding_center = model *
&#160;&#160;&#160;&#160;vec4(bounding_sphere.xyz, 1);
vec4 view_bounding_center = world_to_camera *
&#160;&#160;&#160;&#160;world_bounding_center;

float scale = length( model[0] );
float radius = bounding_sphere.w * scale;
```


Note that this is the bounding sphere for the full mesh, not the meshlet. We are going to process the meshlets in the same way.

The next step is to perform frustum culling on the bounding sphere. This is the same code we presented in the *Implementing task shaders* section, and we are not going to replicate it here.

If the mesh passes the frustum culling, we check for occlusion culling next. First, we compute the bounding square of the perspective projected sphere. This step is necessary as the projected sphere shape could be an ellipsoid. Our implementation is based on this paper: [https://jcgt.org/published/0002/02/05/](https://jcgt.org/published/0002/02/05/) and the Niagara project ([https://github.com/zeux/niagara/](https://github.com/zeux/niagara/)).

We are going to highlight only the final implementation; we suggest reading the full paper for more details about the theory and derivation.

We start by checking whether the sphere is fully behind the near plane. If that’s the case, no further processing is required:

```
bool project_sphere(vec3 C, float r, float znear,
&#160;&#160;&#160;&#160;float P00, float P11, out vec4 aabb) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if (-C.z - r < znear)
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;return false;
```


Why **–C.z**? Because in our implementation, we look at a negative direction vector, thus the visible pixel’s **z** is always negative.

Next, we compute the minimum and maximum points on the *x* axis. We do so by considering only the **xz** plane, finding the projection of the sphere onto this plane, and computing the minimum and maximum **x** coordinates of this projection:

```
vec2 cx = vec2(C.x, -C.z);
vec2 vx = vec2(sqrt(dot(cx, cx) - r * r), r);
vec2 minx = mat2(vx.x, vx.y, -vx.y, vx.x) * cx;
vec2 maxx = mat2(vx.x, -vx.y, vx.y, vx.x) * cx;
```


We repeat the same procedure for the **y** coordinate (omitted here). The computed points are in world space, but we need their value in perspective-projected space. This is accomplished with the following code:

```
aabb = vec4(minx.x / minx.y * P00, miny.x / miny.y * P11,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;maxx.x / maxx.y * P00, maxy.x / maxy.y * P11);
```


**P00** and **P11** are the first two diagonal values of the view-projection matrix. The final step is to transform these values from screen space to UV space. Operating in UV space will be useful for the next part of the algorithm.

The transformation is performed by the following code:

```
aabb = aabb.xwzy * vec4(0.5f, -0.5f, 0.5f, -0.5f) +
vec4(0.5f);
```


Coordinates in screen space are in the **[-1, 1]** range, while UV coordinates are in the **[0, 1]** range. This transformation performs the mapping from one range to the other. We use a negative offset for **y** as screen space has a bottom-left origin, while UV space has a top-left origin.

Now that we have the 2D bounding box for the mesh sphere, we can check whether it’s occluded. First, we determine which level of the depth pyramid we should use:

```
ivec2 depth_pyramid_size =
&#160;&#160;&#160;textureSize(global_textures[nonuniformEXT
&#160;&#160;&#160;(depth_pyramid_texture_index)], 0);
float width = (aabb.z - aabb.x) * depth_pyramid_size.x ;
float height = (aabb.w - aabb.y) * depth_pyramid_size.y ;

float level = floor(log2(max(width, height)));
```


We simply scale the size of the bounding box in UV coordinates, computed in the previous step, by the size of the top level of the depth pyramid texture. We then take the logarithm of the largest between the width and height to determine which level of the pyramid we should use for the depth value lookup.

With this step, we reduce the bounding box to an individual pixel lookup. Remember, when computing the levels of the pyramid, the reduction step stores the farthest depth value. Thanks to this, we can safely look up an individual fragment to determine whether the bounding box is occluded or not.

This is accomplished with the following code:

```
float depth =
&#160;&#160;&#160;textureLod(global_textures[nonuniformEXT
&#160;&#160;&#160;(depth_pyramid_texture_index)], (aabb.xy + aabb.zw)
&#160;&#160;&#160;0.5, level).r;
```


First, we look up the depth value in the pyramid for the sphere bounding box. Next, we compute the closest depth of the bounding sphere.

We also compute the closest depth for the bounding sphere:

```
float depth_sphere = z_near / (view_bounding_center.z –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;radius);
```


Finally, we determine whether the sphere is occluded by checking its depth against the depth we read from the pyramid:

```
occlusion_visible = (depth_sphere <= depth);
```


If the mesh passes both the frustum and occlusion culling, we add the command to draw it in the command list:

```
draw_commands[draw_index].drawId = mesh_instance_index;
draw_commands[draw_index].taskCount =
&#160;&#160;&#160;&#160;(mesh_draw.meshlet_count + 31) / 32;
draw_commands[draw_index].firstTask =
&#160;&#160;&#160;&#160;mesh_draw.meshlet_offset / 32;
```


We will then use this list of commands to draw the meshlets for the visible meshes (as shown in the *Understanding task and mesh shaders* section) and update the depth pyramid.

The last step will be to rerun the culling for the meshes that were discarded in this first pass. Using the updated depth pyramid, we can generate a new command list to draw any meshes that had been incorrectly culled.

This concludes our implementation of occlusion culling. In this section, we have explained an algorithm for efficient occlusion culling on the GPU. We started by detailing the steps performed by this technique.

We then highlighted the main sections of the code that perform the creation of the depth pyramid, which is used for occlusion culling based on the bounding sphere of each mesh.

Performing culling on the GPU is a powerful technique that has helped developers overcome some of the limitations of the traditional geometry pipeline and allows us to render more complex and detailed scenes.

# 小结
In this chapter, we have introduced the concept of meshlets, a construct that helps us break down large meshes into more manageable chunks and that can be used to perform occlusion computations on the GPU. We have demonstrated how to use the library of our choice (MeshOptimizer) to generate meshlets, and we also illustrated the extra data structures (cones and bounding spheres) that are useful for occlusion operations.

We introduced mesh and task shaders. Conceptually similar to compute shaders, they allow us to quickly process meshlets on the GPU. We demonstrated how to use task shaders to perform back-face and frustum culling, and how mesh shaders replace vertex shaders by processing and generating multiple primitives in parallel.

Finally, we went through the implementation of occlusion culling. We first listed the steps that compose this technique. Next, we demonstrated how to compute a depth pyramid from our existing depth buffer. Lastly, we analyzed the occlusion culling implementation and highlighted the most relevant part of the compute shader. This step also generates a list of commands that can be used with an indirect draw call.

So far, our scene only uses one light. In the next chapter, we are going to implement clustered-deferred lighting, which will allow us to render hundreds of lights in our scene.

# 延伸阅读
As we mentioned in a previous section, task and mesh shaders are only available on Nvidia GPUs. This blog post has more details about their inner workings: [https://developer.nvidia.com/blog/introduction-turing-mesh-shaders/](https://developer.nvidia.com/blog/introduction-turing-mesh-shaders/).

Our implementation has been heavily inspired by the algorithms and techniques described in these resources:

- [https://www.gdcvault.com/play/1023463/contactUs](https://www.gdcvault.com/play/1023463/contactUs)


- [http://advances.realtimerendering.com/s2015/aaltonenhaar_siggraph2015_combined_final_footer_220dpi.pdf](http://advances.realtimerendering.com/s2015/aaltonenhaar_siggraph2015_combined_final_footer_220dpi.pdf)




Our go-to reference implementation for a task and mesh shader has been this project: [https://github.com/zeux/niagara](https://github.com/zeux/niagara), which is also accompanied by a series of videos showing its development: [https://www.youtube.com/playlist?list=PL0JVLUVCkk-l7CWCn3-cdftR0oajugYvd](https://www.youtube.com/playlist?list=PL0JVLUVCkk-l7CWCn3-cdftR0oajugYvd).

These libraries can be used to generate meshlets:

- [https://github.com/zeux/meshoptimizer](https://github.com/zeux/meshoptimizer) (the one we use)


- [https://github.com/JarkkoPFC/meshlete](https://github.com/JarkkoPFC/meshlete)




A more recent development in occlusion culling is the concept of a visibility buffer. The technique is described in detail in these resources:

- [http://www.conffx.com/Visibility_Buffer_GDCE.pdf](http://www.conffx.com/Visibility_Buffer_GDCE.pdf)


- [http://filmicworlds.com/blog/visibility-buffer-rendering-with-material-graphs/](http://filmicworlds.com/blog/visibility-buffer-rendering-with-material-graphs/)


- [https://www.youtube.com/watch?v=eviSykqSUUw](https://www.youtube.com/watch?v=eviSykqSUUw)