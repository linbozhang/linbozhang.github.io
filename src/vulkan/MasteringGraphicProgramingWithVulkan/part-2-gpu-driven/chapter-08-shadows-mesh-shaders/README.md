# Chapter 8: Adding Shadows Using Mesh Shaders

# 8



# Adding Shadows Using Mesh Shaders


In the previous chapter, we added support for multiple lights using clustered deferred techniques with the latest innovations.

We added a hard limit of 256 maximum lights, with the possibility for each one to be dynamic and unique in its properties.

In this chapter, we will add the possibility for each of these lights to cast shadows to further enhance the visuals of any asset displayed in Raptor Engine, and we will exploit the possibilities given by mesh shaders of having many of these lights cast shadows and still be in a reasonable frame time.

We will also have a look at using sparse resources to improve shadow map memory usage, moving the possibility of having many shadow-casting lights from something almost impossible to something possible and performant with current hardware.

In this chapter, we’re going to cover the following main topics:

- A brief history of shadow techniques


- Implementing shadow mapping using mesh shaders


- Improving shadow memory with Vulkan’s sparse resources





# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter8](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter8)

# A brief history of shadow techniques


Shadows are one of the biggest additions to any rendering framework as they really enhance the perception of depth and volume across a scene. Being a phenomenon linked to lights, they have been studied in graphics literature for decades, but the problem is still far from being solved.

The most used shadow technique right now is shadow mapping, but recently, thanks to hardware-enabled ray tracing, ray traced shadows are becoming popular as a more realistic solution.

There were some games—especially *Doom 3*—that also used shadow volumes as a solution to make lights cast shadows, but they are not used anymore.

## Shadow volumes


Shadow volumes are an old concept, already proposed by Frank Crow in 1977. They are defined as the projection of each vertex of a triangle along the light direction and toward infinity, thus creating a volume.

The shadows are sharp, and they require each triangle and each light to process accordingly. The most recent implementation uses the stencil buffer, and this change enabled it to be used in real time.

The problem with shadow volumes is that they require a lot of geometry work and become fill-rate intensive, and in this case, shadow maps are a clear winner.

## Shadow mapping


The most used technique of all, first appearing around 1978, shadow mapping is the industry standard in both real-time and offline rendering. The idea behind shadow mapping is to render the scene from the perspective of the light and save the depth of each pixel.

After that, when rendering the scene from the camera point of view, the pixel position can be converted to the shadow coordinate system and tested against the corresponding pixel in the shadow map to see whether the current pixel is in shadow or not.

The resolution of a shadow map is very important, as well as what type of information is saved inside it. With time, filters started to appear, using mathematical tools to add the possibility to soften the shadows, or adding calculations to harden the shadows the closer they are to the blocker geometry.

Shadow mapping suffers from a lot of issues as well, but being the de facto standard, many techniques are used to alleviate them. Some problems that can be encountered are aliasing, shadow acne, and Peter Panning.

Finding a robust shadow solution is one of the most intricate steps of a rendering engine and normally requires a lot of trial and error and custom solutions tailored to different scenes and situations.

## Raytraced shadows


In the last few years, raytracing—a technique that uses rays to trace any kind of rendering information—got hardware support on customer GPUs, enabling rendering programmers to use a different scene representation to trace rays and enhance the look of different rendering phenomena.

We will look at raytracing toward the end of the book, but for now, it is sufficient to say that using this special representation of the scene (different from mesh and meshlets we already use), it is possible to trace, for each pixel on the screen, one ray toward each light affecting the pixel and calculate the final shadow contribution to that pixel.

It is the most advanced and realistic form of a shadow, but still, performance-wise—despite the hardware support—it can be slow, and the diffusion of GPUs supporting it is not as elevated as needed to make it the new standard.

That is why shadow mapping is still the standard—any hardware, including mobile phones, can render shadow maps, and they can still achieve a convincing look. Based on this consideration, we chose to implement shadow mapping as the main shadow technique for Raptor Engine.

# Implementing shadow mapping using mesh shaders


Now that we have looked at the different ways to render a shadow, we will describe the algorithm and the implementation’s detail used to render many shadow maps at once leveraging the mesh shader power.

## Overview


本节将give an overview of the algorithm. What we are trying to achieve is to render shadows using meshlets and mesh shaders, but this will require some compute work to generate commands to actually draw the meshlets.

We will draw shadows coming from point lights, and we will use cubemaps as textures to store the necessary information. We will talk about cubemaps in the following section.

Back to the algorithm, the first step will be to cull mesh instances against lights. This is done in a compute shader and will save a per-light list of visible mesh instances. Mesh instances are used to retrieve associated meshes later on, and per-meshlet culling will be performed using task shaders later on.

The second step is to write indirect draw meshlet arguments to perform the actual rendering of meshlets into shadow maps, again in a compute shader. There is a caveat here that will be explained in the *A note about multiview **rendering* section.

The third step is to draw meshlets using indirect mesh shaders, drawing into the actual shadow maps.

We will use a layered cubemap shadow texture as we are drawing, with each layer corresponding to each light.

The fourth and final step is to sample the shadow texture when lighting the scene.

We will render shadows with almost no filtering, as the focus of this chapter is on mesh shader-driven shadows, but we will give links to filtering options at the end of the chapter.

Here is a visual overview of the algorithm:



 ![Figure 8.1 – Algorithm overview](image/B18395_08_01.jpg)


Figure 8.1 – Algorithm overview

下一节将talk about cubemap shadows, used to store shadows from point lights.

## Cubemap shadows


**Cubemaps** are a general way of mapping a 3D direction (*x*, *y*, *z*) with six faces containing image information.

They are used not only for shadow rendering but in general to draw environments as well (such as sky boxes, or far distant landscapes), and they are so standardized that even hardware contains support for cubemap sampling and filtering.

Each direction of the cubemap has normally a name and an orientation and a single texture associated with it:

- Positive *x*


- Negative *x*


- Positive *y*


- Negative *y*


- Positive *z*


- Negative *z*




When rendering to a face, we need to provide matrices that will look in the correct direction.

When reading, a single vector will be translated (behind the scenes) to the corresponding image. For shadows, the process will be manual, as we will provide for each face a view projection matrix that will be read by the meshlets to direct the rendering to the correct face.

A caveat for that also is that we will need to duplicate the drawing commands for each face, as one vertex can be rendered only to one image view associated with each face.

There are some extensions that can associate a vertex with more than one image, as we will see in the next section, but their support in mesh shaders at the time of writing is still limited.

Another important aspect of the proposed shadow rendering is that we will use an array of cubemaps so that we can both read and write every shadow using layered rendering.

Here is the unrolled cubemap shadow rendering for one point light, with a texture for each cubemap face:



 ![Figure 8.2 – The six cubemap faces rendered from the light point of view](image/B18395_08_02.jpg)


Figure 8.2 – The six cubemap faces rendered from the light point of view

As we can see, only the positive *Z* is rendering something. We will provide some culling mechanisms to avoid rendering meshlets in empty cubemap faces.

## A note about multiview rendering


As written in the previous section, there is an extension that helps with rendering a vertex on more than a cubemap face: Multiview Rendering. This extension is widely used in virtual reality applications to render a vertex in both the views of a stereographic projection and can be used as well with cubemaps.

At the time of writing, mesh shaders don’t have a proper extension supported, so we are using the NVIDIA Vulkan extension, and this is not supporting Multiview Rendering properly, thus we are manually generating commands for each face and drawing using those commands.

We are aware that a multi-vendor extension is on the way, so we will update the code accordingly, but the core algorithm does not change, as multiview rendering is more of an optimization.

We are now ready to see the algorithm steps.

## Per-light mesh instance culling


The first step in preparing for shadow rendering is a coarse grain culling done in a compute shader. In Raptor, we have both mesh and meshlet representations, thus we can use meshes and their bounding volumes as a *higher hierarchy* linked to meshlets.

We will perform a very simple light sphere to mesh sphere intersection, and if intersecting, we will add the corresponding meshlets. The first thing to know is that we will dispatch this compute shader using mesh instances and light together, so we will calculate for each light and for each mesh instance if the light influences the mesh instance.

We will then output a list of per-light meshlet instances, defined as both a mesh instance and global meshlet index combined. We will also write the per-light meshlet instances count, to skip empty lights and to correctly read the indices.

The first step is thus to reset the per-light counts:

```
layout (local_size_x = 32, local_size_y = 1, local_size_z =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1) in;
void main() {
&#160;&#160;&#160;&#160;if (gl_GlobalInvocationID.x == 0 ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;for ( uint i = 0; i < NUM_LIGHTS; ++i ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;per_light_meshlet_instances[i * 2] = 0;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;per_light_meshlet_instances[i * 2 + 1] = 0;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;global_shader_barrier();
```


We will then skip threads that will work on out-of-bounds lights. When we dispatch, we round up the numbers after dividing by 32, so some threads can be working on empty lights.

The dispatch of this compute will be done by linking each mesh instance with each light, like so:



 ![Figure 8.3 – Organization of the command buffer to render the cubemaps for multiple lights using a single draw call](image/B18395_08_03.jpg)


Figure 8.3 – Organization of the command buffer to render the cubemaps for multiple lights using a single draw call

Here is the early out and light index calculation:

```
&#160;&#160;&#160;&#160;uint light_index = gl_GlobalInvocationID.x %
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;active_lights;
&#160;&#160;&#160;&#160;if (light_index >= active_lights) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;return;
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;const Light = lights[light_index];
```


In a similar way, we calculate the mesh instance index, and *early out* again if the dispatch rounding up is too much:

```
&#160;&#160;&#160;&#160;uint mesh_instance_index = gl_GlobalInvocationID.x /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;active_lights;
&#160;&#160;&#160;&#160;if (mesh_instance_index >= num_mesh_instances) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;return;
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;uint mesh_draw_index = mesh_instance_draws
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;[mesh_instance_index].
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;mesh_draw_index;
&#160;&#160;&#160;&#160;// Skip transparent meshes
&#160;&#160;&#160;&#160;MeshDraw mesh_draw = mesh_draws[mesh_draw_index];
&#160;&#160;&#160;&#160;if ( ((mesh_draw.flags & (DrawFlags_AlphaMask |
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;DrawFlags_Transparent)) != 0 ) ){
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;return;
&#160;&#160;&#160;&#160;}
```


We can finally gather the bounding sphere of the mesh instance and the model and simply calculate the world space bounding sphere:

```
&#160;&#160;&#160;&#160;vec4 bounding_sphere = mesh_bounds[mesh_draw_index];
&#160;&#160;&#160;&#160;mat4 model = mesh_instance_draws
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;[mesh_instance_index].model;
&#160;&#160;&#160;&#160;// Calculate mesh instance bounding sphere
&#160;&#160;&#160;&#160;vec4 mesh_world_bounding_center = model * vec4
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(bounding_sphere.xyz, 1);
&#160;&#160;&#160;&#160;float scale = length( model[0] );
&#160;&#160;&#160;&#160;float mesh_radius = bounding_sphere.w * scale * 1.1;
&#160;&#160;&#160;&#160;// Artificially inflate bounding sphere
&#160;&#160;&#160;&#160;// Check if mesh is inside light
&#160;&#160;&#160;&#160;const bool mesh_intersects_sphere =
&#160;&#160;&#160;&#160;sphere_intersect(mesh_world_bounding_center.xyz,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;mesh_radius, light.world_position, light.radius )
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;|| disable_shadow_meshes_sphere_cull();
&#160;&#160;&#160;&#160;if (!mesh_intersects_sphere) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;return;
&#160;&#160;&#160;&#160;}
```


At this point, we know that the mesh instance is influenced by the light, so increase the per-light meshlet count and add all the indices necessary to draw the meshlets:

```
&#160;&#160;&#160;&#160;uint per_light_offset =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;atomicAdd(per_light_meshlet_instances[light_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;mesh_draw.meshlet_count);
&#160;&#160;&#160;&#160;// Mesh inside light, add meshlets
&#160;&#160;&#160;&#160;for ( uint m = 0; m < mesh_draw.meshlet_count; ++m ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint meshlet_index = mesh_draw.meshlet_offset + m;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_instances[light_index *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;per_light_max_instances + per_light_offset
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;+ m] = uvec2( mesh_instance_index,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_index );
&#160;&#160;&#160;&#160;}
}
```


We will end up writing both the mesh instance index—to retrieve the world matrix—and the global meshlet index—to retrieve meshlet data in the following task shader. But before that, we need to generate an indirect draw commands list, and we will see that in the next section.

Also, based on the scene, we have a maximum number of meshlet instances, and we allocate them upfront for each light.

## Indirect draw commands generation


This compute shader will generate a list of indirect commands for each light. We will use the last element of the per-light meshlet instances’ **Shader Storage Buffer Object** (**SSBO**) to atomically count the number of indirect commands.

As before, reset **atomic int** used for the indirect commands count:

```
layout (local_size_x = 32, local_size_y = 1, local_size_z =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1) in;
void main() {
&#160;&#160;&#160;&#160;if (gl_GlobalInvocationID.x == 0 ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Use this as atomic int
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;per_light_meshlet_instances[NUM_LIGHTS] = 0;
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;global_shader_barrier();
```


We will early out execution for rounded-up light indices:

```
&#160;&#160;&#160;&#160;// Each thread writes the command of a light.
&#160;&#160;&#160;&#160;uint light_index = gl_GlobalInvocationID.x;
&#160;&#160;&#160;&#160;if ( light_index >= active_lights ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;return;
&#160;&#160;&#160;&#160;}
```


We can finally write the indirect data and the packed light index, only if the light contains visible meshes.

Note that we write six commands, one for each cubemap face:

```
&#160;&#160;&#160;&#160;// Write per light shadow data
&#160;&#160;&#160;&#160;const uint visible_meshlets =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;per_light_meshlet_instances[light_index];
&#160;&#160;&#160;&#160;if (visible_meshlets > 0) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const uint command_offset =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;atomicAdd(per_light_meshlet_instances[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;NUM_LIGHTS], 6);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint packed_light_index = (light_index & 0xffff)
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;<< 16;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_draw_commands[command_offset] =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uvec4( ((visible_meshlets + 31) / 32), 1, 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;packed_light_index | 0 );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_draw_commands[command_offset + 1] =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uvec4( ((visible_meshlets + 31) / 32), 1, 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;packed_light_index | 1 );
&#160;&#160;&#160;... same for faces 2 to 5.
&#160;&#160;&#160;&#160;}
}
```


We now have a list of indirect drawing commands, six for each light. We will perform further culling in the task shader, shown in the next section.

## Shadow cubemap face culling


In the indirect drawing task shader, we will add a mechanism to cull a meshlet against a cubemap to optimize the rendering. To do that, we have a utility method that will calculate, given a cubemap and an axis-aligned bounding box, which face will be visible in the cubemap. It is using cubemap face normals to calculate whether the center and extents are enclosed in the four planes used to define one of the six cubemap faces:

```
uint get_cube_face_mask( vec3 cube_map_pos, vec3 aabb_min,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 aabb_max ) {
&#160;&#160;&#160;&#160;vec3 plane_normals[] = {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(-1, 1, 0), vec3(1, 1, 0), vec3(1, 0, 1),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(1, 0, -1), vec3(0, 1, 1), vec3(0, -1, 1)
&#160;&#160;&#160;&#160;};
&#160;&#160;&#160;&#160;vec3 abs_plane_normals[] = {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(1, 1, 0), vec3(1, 1, 0), vec3(1, 0, 1),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(1, 0, 1), vec3(0, 1, 1), vec3(0, 1, 1) };
&#160;&#160;&#160;&#160;vec3 aabb_center = (aabb_min + aabb_max) * 0.5f;
&#160;&#160;&#160;&#160;vec3 center = aabb_center - cube_map_pos;
&#160;&#160;&#160;&#160;vec3 extents = (aabb_max - aabb_min) * 0.5f;
&#160;&#160;&#160;&#160;bool rp[ 6 ];
&#160;&#160;&#160;&#160;bool rn[ 6 ];
&#160;&#160;&#160;&#160;for ( uint&#160;&#160;i = 0; i < 6; ++i ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float dist = dot( center, plane_normals[ i ] );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float radius = dot( extents, abs_plane_normals[ i ]
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;rp[ i ] = dist > -radius;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;rn[ i ] = dist < radius;
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;uint fpx = (rn[ 0 ] && rp[ 1 ] && rp[ 2 ] && rp[ 3 ] &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_max.x > cube_map_pos.x) ? 1 : 0;
&#160;&#160;&#160;&#160;uint fnx = (rp[ 0 ] && rn[ 1 ] && rn[ 2 ] && rn[ 3 ] &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_min.x < cube_map_pos.x) ? 1 : 0;
&#160;&#160;&#160;&#160;uint fpy = (rp[ 0 ] && rp[ 1 ] && rp[ 4 ] && rn[ 5 ] &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_max.y > cube_map_pos.y) ? 1 : 0;
&#160;&#160;&#160;&#160;uint fny = (rn[ 0 ] && rn[ 1 ] && rn[ 4 ] && rp[ 5 ] &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_min.y < cube_map_pos.y) ? 1 : 0;
&#160;&#160;&#160;&#160;uint fpz = (rp[ 2 ] && rn[ 3 ] && rp[ 4 ] && rp[ 5 ] &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_max.z > cube_map_pos.z) ? 1 : 0;
&#160;&#160;&#160;&#160;uint fnz = (rn[ 2 ] && rp[ 3 ] && rn[ 4 ] && rn[ 5 ] &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_min.z < cube_map_pos.z) ? 1 : 0;
&#160;&#160;&#160;&#160;return fpx | ( fnx << 1 ) | ( fpy << 2 ) | ( fny << 3 )
&#160;&#160;&#160;&#160;| ( fpz << 4 ) | ( fnz << 5 );
}
```


These methods return a bitmask with each of the six bits set as **1** when the current axis-aligned bounding box is visible in that face.

## Meshlet shadow rendering – task shader


Now that we have this utility method in place, we can look at the task shader. We changed some things with the other task shaders to accommodate the indirect drawing and to use layered rendering to write on different cubemaps.

We will pass **uint** to the mesh shader that packs a light and a face index to retrieve the corresponding cubemap view projection matrix and write to the correct layer:

```
out taskNV block {
&#160;&#160;&#160;&#160;uint meshlet_indices[32];
&#160;&#160;&#160;&#160;&#160;uint light_index_face_index;
};
void main() {
&#160;&#160;&#160;&#160;uint task_index = gl_LocalInvocationID.x;
&#160;&#160;&#160;&#160;&#160;uint meshlet_group_index = gl_WorkGroupID.x;
```


The meshlet calculation is tricky, as indices need to be calculated globally. We first calculate the meshlet index global to the indirect draw:

```
&#160;&#160;&#160;&#160;// Calculate meshlet and light indices
&#160;&#160;&#160;&#160;const uint meshlet_index = meshlet_group_index * 32 +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;task_index;
```


We then extrapolate the light index and the read offset in the meshlet instances written in the culling compute shader:

```
&#160;&#160;&#160;&#160;uint packed_light_index_face_index =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_draw_commands[gl_DrawIDARB].w;
&#160;&#160;&#160;&#160;const uint light_index =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;packed_light_index_face_index >> 16;
&#160;&#160;&#160;&#160;const uint meshlet_index_read_offset =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_index * per_light_max_instances;
```


We can finally read the correct meshlet and mesh instance indices:

```
uint global_meshlet_index =
&#160;&#160; meshlet_instances[meshlet_index_read_offset +
&#160;&#160; meshlet_index].y;
&#160;&#160;&#160;uint mesh_instance_index =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_instances[meshlet_index_read_offset +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_index].x;
```


Now, we calculate the face index, and we can start the culling phase:

```
&#160;&#160;&#160;&#160;const uint face_index = (packed_light_index_face_index
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;& 0xf);
&#160;&#160;&#160;&#160;mat4 model = mesh_instance_draws[mesh_instance_index]
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.model;
```


Culling is performed similarly to previous task shaders, but we added also per-face culling:

```
&#160;&#160;&#160;&#160;vec4 world_center = model * vec4(meshlets
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;[global_meshlet_index].center, 1);
&#160;&#160;&#160;&#160;float scale = length( model[0] );
&#160;&#160;&#160;&#160;float radius = meshlets[global_meshlet_index].radius *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scale * 1.1;&#160;&#160;&#160;// Artificially inflate
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;bounding sphere
vec3 cone_axis =
&#160;&#160; mat3( model ) * vec3(int(meshlets
&#160;&#160; [global_meshlet_index].cone_axis[0]) / 127.0,
&#160;&#160; int(meshlets[global_meshlet_index].
&#160;&#160; cone_axis[1]) / 127.0,
&#160;&#160; int(meshlets[global_meshlet_index].
&#160;&#160; cone_axis[2]) / 127.0);
&#160;&#160;&#160;float cone_cutoff = int(meshlets[global_meshlet_index].
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;cone_cutoff) / 127.0;
&#160;&#160;&#160;&#160;bool accept = false;
&#160;&#160;&#160;&#160;const vec4 camera_sphere = camera_spheres[light_index];
&#160;&#160;&#160;&#160;// Cone cull
&#160;&#160;&#160;&#160;accept = !coneCull(world_center.xyz, radius, cone_axis,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;cone_cutoff, camera_sphere.xyz) ||
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;disable_shadow_meshlets_cone_cull();
&#160;&#160;&#160;&#160;// Sphere culling
&#160;&#160;&#160;&#160;if ( accept ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accept = sphere_intersect( world_center.xyz,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;radius, camera_sphere.xyz,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;camera_sphere.w) ||
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;disable_shadow_meshlets_sphere_cull();
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;// Cubemap face culling
&#160;&#160;&#160;&#160;if ( accept ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint visible_faces =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;get_cube_face_mask( camera_sphere.xyz,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_center.xyz - vec3(radius),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_center.xyz + vec3(radius));
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;switch (face_index) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;case 0:
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accept = (visible_faces & 1) != 0;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;case 1:
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accept = (visible_faces & 2) != 0;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
...same for faces 2 to 5.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accept = accept || disable_shadow_meshlets_cubemap
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_face_cull();
&#160;&#160;&#160;&#160;}
```


At this point of the shader we write each visible meshlet:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uvec4 ballot = subgroupBallot(accept);
&#160;&#160;&#160;&#160;uint index = subgroupBallotExclusiveBitCount(ballot);
&#160;&#160;&#160;&#160;if (accept)
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshlet_indices[index] = global_meshlet_index;
&#160;&#160;&#160;&#160;uint count = subgroupBallotBitCount(ballot);
&#160;&#160;&#160;&#160;if (task_index == 0)
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gl_TaskCountNV = count;
```


And finally, we write the packed light and face index:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_index_face_index =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;packed_light_index_face_index;
}
```


Next, we will see the mesh shader.

## Meshlet shadow rendering – mesh shader


In this mesh shader, we will need to retrieve the layer index in the cubemap array to write to, and the light index to read the correct view-projection transform.

It’s important to note that each face has its own transform, as we effectively render to each face separately.

Note that each face of the cubemap is considered a layer, thus the first cubemap will be rendered in layers 0-5, the second in layers 6-11, and so on.

Here is the code:

```
void main() {
&#160;&#160;&#160;...
&#160;&#160;&#160;&#160;const uint light_index = light_index_face_index >> 16;
&#160;&#160;&#160;&#160;const uint face_index = (light_index_face_index & 0xf);
&#160;&#160;&#160;&#160;const int layer_index = int(CUBE_MAP_COUNT *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_index + face_index);
&#160;&#160;&#160;&#160;for (uint i = task_index; i < vertex_count; i +=
&#160;&#160;&#160;&#160;&#160;&#160;&#160;32)&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint vi = meshletData[vertexOffset + i];
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 position = vec3(vertex_positions[vi].v.x,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vertex_positions[vi].v.y,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vertex_positions[vi].v.z);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gl_MeshVerticesNV[ i ].gl_Position =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;view_projections[layer_index] *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(model * vec4(position, 1));
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;uint indexGroupCount = (indexCount + 3) / 4;
&#160;&#160;&#160;&#160;for (uint i = task_index; i < indexGroupCount; i += 32) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;writePackedPrimitiveIndices4x8NV(i * 4,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;meshletData[indexOffset + i]);
&#160;&#160;&#160;&#160;}
```


Here, we write the layer index for each primitive. The usage of these offsets is to avoid bank conflict when writing, as seen on previous shaders:

```
&#160;&#160;&#160;&#160;&#160;gl_MeshPrimitivesNV[task_index].gl_Layer =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;layer_index;
&#160;&#160;&#160;&#160;gl_MeshPrimitivesNV[task_index + 32].gl_Layer =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;layer_index;
&#160;&#160;&#160;&#160;gl_MeshPrimitivesNV[task_index + 64].gl_Layer =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;layer_index;
&#160;&#160;&#160;&#160;gl_MeshPrimitivesNV[task_index + 96].gl_Layer =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;layer_index;
&#160;&#160;&#160;&#160;if (task_index == 0) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gl_PrimitiveCountNV =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint(meshlets[global_meshlet_index]
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.triangle_count);
&#160;&#160;&#160;&#160;}
}
```


After this mesh shader rendering of shadows is complete, as there is no fragment shader associated. We can now read the generated shadow texture in the lighting shader, as explained in the next section.

## Shadow map sampling


Given that we are just using hard shadow maps without filtering, the code to sample it is standard cubemap code. We calculate the world-to-light vector and use it to sample the cubemap.

Being a layered cubemap, we need both the 3D direction vector and the layer index, which we saved in the light itself:

```
&#160;&#160;&#160;&#160;vec3 shadow_position_to_light = world_position –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.world_position;
const float closest_depth =
&#160;&#160;&#160;&#160;texture(global_textures_cubemaps_array
&#160;&#160;&#160;&#160;[nonuniformEXT(cubemap_shadows_index)],
&#160;&#160;&#160;&#160;vec4(shadow_position_to_light,
&#160;&#160;&#160;&#160;shadow_light_index)).r;
```


We then convert the depth to raw depth values with the **vector_to_depth_value** utility method, which takes the major axis from the light vector and converts it to raw depth so that we can compare the value read from the cubemap:

```
&#160;&#160;&#160;&#160;const float current_depth = vector_to_depth_value
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(shadow_position_to_light,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.radius);
&#160;&#160;&#160;&#160;float shadow = current_depth - bias < closest_depth ?
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1 : 0;
```


The **vector_to_depth_value** method is shown here:

```
float vector_to_depth_value( inout vec3 Vec, float radius) {
&#160;&#160;&#160;&#160;vec3 AbsVec = abs(Vec);
&#160;&#160;&#160;&#160;float LocalZcomp = max(AbsVec.x, max(AbsVec.y,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;AbsVec.z));
&#160;&#160;&#160;&#160;const float f = radius;
&#160;&#160;&#160;&#160;const float n = 0.01f;
&#160;&#160;&#160;&#160;float NormZComp = -(f / (n - f) - (n * f) / (n - f) /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;LocalZcomp);
&#160;&#160;&#160;&#160;return NormZComp;
}
```


It takes the major axis from the direction vector and converts it to the raw depth using the formula coming from the projection matrix. This value is now usable with any depth value stored in a shadow map.

Here is an example of shadow coming from a point light:



 ![Figure 8.4 – Shadows produced by a single point light in the scene](image/B18395_08_04.jpg)


Figure 8.4 – Shadows produced by a single point light in the scene

As we can see, shadows are a great improvement in rendering, giving the viewer a fundamental visual cue of an object’s relationship with its environment.

Until here, we saw how to implement mesh shader-based shadows, but there is still room for improvement, especially in memory usage. Right now, this solution allocates upfront a single cubemap for each light, and the memory can become big quickly if we consider that we have six textures for each light.

We will look at a solution to lower the shadow map memory using sparse resources in the next section.

# Improving shadow memory with Vulkan’s sparse resources


As we mentioned at the end of the last section, we currently allocate the full memory for each cubemap for all the lights. Depending on the screen size of the light, we might be wasting memory as distant and small lights won’t be able to take advantage of the high resolution of the shadow map.

For this reason, we have implemented a technique that allows us to dynamically determine the resolution of each cubemap based on the camera position. With this information, we can then manage a sparse texture and re-assign its memory at runtime depending on the requirements for a given frame.

Sparse textures (sometimes also referred to as **virtual textures**) can be implemented manually, but luckily, they are supported natively in Vulkan. We are now going to describe how to use the Vulkan API to implement them.

## Creating and allocating sparse textures


Regular resources in Vulkan must be bound to a single memory allocation, and it’s not possible to bind a given resource to a different allocation. This works well for resources that are known at runtime and that we don’t expect to change.

However, when using cubemaps with a dynamic resolution, we need to be able to bind different portions of memory to a given resource. Vulkan exposes two methods to achieve this:

- Sparse resources allow us to bind a resource to non-contiguous memory allocations, but the full resource needs to be bound.


- Sparse residency allows us to partially bind a resource to different memory allocations. This is what we need for our implementation, as we are likely to use only a subsection of each layer of a cubemap.




Both methods allow users to re-bind a resource to different allocations at runtime. The first step needed to start using sparse resources is to pass the right flag when creating resources:

```
VkImageCreateInfo image_info = {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO };
image_info.flags = VK_IMAGE_CREATE_SPARSE_RESIDENCY_BIT |
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_IMAGE_CREATE_SPARSE_BINDING_BIT;
```


Here, we are requesting a resource that supports sparse residency. Once an image is created, we don’t need to immediately allocate memory for it. Instead, we are going to allocate a region of memory from which we will sub-allocate individual pages.

It’s important to note that Vulkan has strict requirements for the size of individual pages. These are the required sizes taken from the Vulkan specification:



 ![Table 8.1 – Sparse block sizes for images](image/B18395_08_Table_01.jpg)


Table 8.1 – Sparse block sizes for images

We will need this information to determine how many pages to allocate for a cubemap of a given size. We can retrieve the details for a given image with the following code:

```
VkPhysicalDeviceSparseImageFormatInfo2 format_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SPARSE_IMAGE_FORMAT
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_INFO_2 };
format_info.format = texture->vk_format;
format_info.type = to_vk_image_type( texture->type );
format_info.samples = VK_SAMPLE_COUNT_1_BIT;
format_info.usage = texture->vk_usage;
format_info.tiling = VK_IMAGE_TILING_OPTIMAL;
```


The information for this structure is already available in our texture data structure. Next, we retrieve the block size for the given image:

```
Array<VkSparseImageFormatProperties2> properties;
vkGetPhysicalDeviceSparseImageFormatProperties2(
&#160;&#160;&#160;&#160;vulkan_physical_device, &format_info, &property_count,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;properties.data );
u32 block_width = properties[ 0 ].properties.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;imageGranularity.width;
u32 block_height = properties[ 0 ].properties.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;imageGranularity.height;
```


With this information, we can now allocate a pool of pages. First, we retrieve the memory requirements for the image:

```
VkMemoryRequirements memory_requirements{ };
vkGetImageMemoryRequirements( vulkan_device, texture->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vk_image,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&memory_requirements );
```


This is the same code we would use for a regular texture; however, **memory_requirements.alignment** will contain the block size for the given image format.

Next, we compute the number of blocks we need to allocate for the given pool size:

```
u32 block_count = pool_size / ( block_width * block_height );
```


The final step is to allocate the pages that we will use later to write into our cubemaps:

```
VmaAllocationCreateInfo allocation_create_info{ };
allocation_create_info.usage = VMA_MEMORY_USAGE_GPU_ONLY;
VkMemoryRequirements page_memory_requirements;
page_memory_requirements.memoryTypeBits =
&#160;&#160;&#160;&#160;memory_requirements.memoryTypeBits;
page_memory_requirements.alignment =
&#160;&#160;&#160;&#160;memory_requirements.alignment;
page_memory_requirements.size =
&#160;&#160;&#160;&#160;memory_requirements.alignment;
vmaAllocateMemoryPages( vma_allocator,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&page_memory_requirements,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&allocation_create_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;block_count, page_pool->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vma_allocations.data, nullptr );
```


The **Vulkan Memory Allocator** (**VMA**) library provides a convenient API, **vmaAllocateMemoryPages**, to allocate multiple pages at once.

Now that we have allocated the memory for our shadow maps, we need to determine the resolution for each cubemap.

## Choosing per-light shadow memory usage


To determine the resolution of the cubemap for a given light, we need to find how much influence it has on the scene. Intuitively, a more distant light will have less influence, depending on its radius (at least for point lights), but we need to quantify its amount of influence. We have implemented a solution similar to the one proposed in the *More Efficient Virtual Shadow Maps for Many **Lights* paper.

We are going to reuse the concept introduced in the previous chapter: clusters. We subdivide the screen into tiles and *slice* the frustum on the *z* axis. This will give us smaller frustums (approximated by axis-aligned bounding boxes) that we will use to determine which regions are covered by a given light.

Let’s look at the code to achieve this:

- We start by computing the bounding box for each light in camera space:

```
for ( u32 l = 0; l < light_count; ++l ) {
```

```
&#160;&#160;&#160;&#160;Light& light = scene->lights[ l ];
```

```
&#160;&#160;&#160;&#160;vec4s aabb_min_view = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;last_camera.view,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.aabb_min );
```

```
&#160;&#160;&#160;&#160;vec4s aabb_max_view = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;last_camera.view,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.aabb_max );
```

```
&#160;&#160;&#160;&#160;lights_aabb_view[ l * 2 ] = vec3s{
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_min_view.x, aabb_min_view.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_min_view.z };
```

```
&#160;&#160;&#160;&#160;lights_aabb_view[ l * 2 + 1 ] = vec3s{
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_max_view.x, aabb_max_view.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aabb_max_view.z };
```

```
}
```


- Next, we iterate over the tiles and each depth slice to compute each cluster position and size. We start by computing the camera space position of each tile:

```
vec4s max_point_screen = vec4s{ f32( ( x + 1 ) *
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;tile_size ), f32( ( y + 1 ) *
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;tile_size ), 0.0f, 1.0f };
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Top Right
```

```
vec4s min_point_screen = vec4s{ f32( x * tile_size ),
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;f32( y * tile_size ),
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;0.0f, 1.0f }; // Top Right
```

```
vec3s max_point_view = screen_to_view(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_point_screen );
```

```
vec3s min_point_view = screen_to_view(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_screen );
```


- We then need to determine the minimum and maximum depth for each slice:

```
f32 tile_near = z_near * pow( z_ratio, f32( z ) *
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;z_bin_range );
```

```
f32 tile_far&#160;&#160;= z_near * pow( z_ratio, f32( z + 1 ) *
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;z_bin_range );
```


- Finally, we combine both values to retrieve the position and size of the cluster:

```
vec3s min_point_near = line_intersection_to_z_plane(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;eye_pos, min_point_view,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;tile_near );
```

```
vec3s min_point_far&#160;&#160;= line_intersection_to_z_plane(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;eye_pos, min_point_view,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;tile_far );
```

```
vec3s max_point_near = line_intersection_to_z_plane(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;eye_pos, max_point_view,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;tile_near );
```

```
vec3s max_point_far&#160;&#160;= line_intersection_to_z_plane(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;eye_pos, max_point_view,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;tile_far );
```

```
vec3s min_point_aabb_view = glms_vec3_minv( glms_vec3_minv( min_point_near, min_point_far ), glms_vec3_minv( max_point_near, max_point_far ) );
```

```
vec3s max_point_aabb_view = glms_vec3_maxv( glms_vec3_maxv( min_point_near, min_point_far ), glms_vec3_maxv( max_point_near, max_point_far ) );
```




Now that we have obtained the cluster, we iterate over each light to determine whether it covers the cluster and the projection of the cluster onto the light; we’ll clarify what this means in a moment.

- The next step is a box intersection test between the light and the cluster:

```
f32 minx = min( min( light_aabb_min.x,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_aabb_max.x ), min(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.x,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_point_aabb_view.x ) );
```

```
f32 miny = min( min( light_aabb_min.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_aabb_max.y ), min(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_point_aabb_view.y ) );
```

```
f32 minz = min( min( light_aabb_min.z,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_aabb_max.z ), min(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.z,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_point_aabb_view.z ) );
```

```
f32 maxx = max( max( light_aabb_min.x,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_aabb_max.x ), max(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.x,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_point_aabb_view.x ) );
```

```
f32 maxy = max( max( light_aabb_min.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_aabb_max.y ), max(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_point_aabb_view.y ) );
```

```
f32 maxz = max( max( light_aabb_min.z,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_aabb_max.z ), max(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.z,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_point_aabb_view.z ) );
```

```
f32 dx = abs( maxx - minx );
```

```
f32 dy = abs( maxy - miny );
```

```
f32 dz = abs( maxz - minz );
```

```
f32 allx = abs( light_aabb_max.x - light_aabb_min.x )
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;+ abs( max_point_aabb_view.x –
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.x );
```

```
f32 ally = abs( light_aabb_max.y - light_aabb_min.y )
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;+ abs( max_point_aabb_view.y –
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.y );
```

```
f32 allz = abs( light_aabb_max.z - light_aabb_min.z )
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;+ abs( max_point_aabb_view.z –
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;min_point_aabb_view.z );
```

```
bool intersects = ( dx <= allx ) && ( dy < ally ) &&
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;( dz <= allz );
```




If they do intersect, we compute an approximation of the projected area of the light onto the cluster:

```
f32 d = glms_vec2_distance( sphere_screen, tile_center );
f32 diff = d * d - tile_radius_sq;
if ( diff < 1.0e-4 ) {
&#160;&#160;&#160;&#160;continue;
}
f32 solid_angle = ( 2.0f * rpi ) * ( 1.0f - ( sqrtf(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;diff ) / d ) );
f32 resolution = sqrtf( ( 4.0f * rpi * tile_pixels ) /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;( 6 * solid_angle ) );
```


The idea is to take the distance between the light and cluster center in screen space, compute the solid angle subtended by the cluster onto the light position, and compute the resolution of the cubemap using the size in pixels of the cluster. We refer you to the paper for more details.

We keep the maximum resolution, and we will use the computed value to bind the memory for each cubemap.

## Rendering into a sparse shadow map


Now that we have determined the resolution of the cubemaps for a given frame, we need to assign the pre-allocated pages to our textures:

- The first step is to record which pages are assigned to each image:

```
VkImageAspectFlags aspect = TextureFormat::has_depth(
```

```
texture->vk_format ) ? VK_IMAGE_ASPECT_DEPTH_BIT : VK_IMAGE_ASPECT_COLOR_BIT;
```

```
for ( u32 block_y = 0; block_y < num_blocks_y;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;++block_y ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;for ( u32 block_x = 0; block_x < num_blocks_x;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;++block_x ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VkSparseImageMemoryBind sparse_bind{ };
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VmaAllocation allocation =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;page_pool-> vma_allocations
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;[ page_pool->used_pages++ ];
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VmaAllocationInfo allocation_info{ };
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vmaGetAllocationInfo( vma_allocator,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;allocation,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&allocation_info );
```




We start by getting the details for the allocation that we are going to use for a given block, as we need to access the **VkDeviceMemory** handle and the offset into the pool it was allocated from.

- Next, we compute the texture offset for each block:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;i32 dest_x = ( i32 )( block_x * block_width +
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;x );
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;i32 dest_y = ( i32 )( block_y * block_height +
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;y );
```


- Then, we record this information into a **VkSparseImageMemoryBind** data structure that will be used later to update the memory bound to the cubemap texture:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sparse_bind.subresource.aspectMask = aspect;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sparse_bind.subresource.arrayLayer = layer;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sparse_bind.offset = { dest_x, dest_y, 0 };
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sparse_bind.extent = { block_width,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;block_height, 1 };
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sparse_bind.memory =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;allocation_info.deviceMemory;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sparse_bind.memoryOffset =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;allocation_info.offset;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pending_sparse_queue_binds.push( sparse_bind
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
```

```
&#160;&#160;&#160;&#160;}
```

```
}
```




It’s important to note that, as we mentioned previously, we only use one image with many layers. The layer variable determines which layer each allocation will belong to. Please refer to the full code for more details.

- Finally, we record which image these pages will be bound to:

```
SparseMemoryBindInfo bind_info{ };
```

```
bind_info.image = texture->vk_image;
```

```
bind_info.binding_array_offset = array_offset;
```

```
bind_info.count = num_blocks;
```

```
pending_sparse_memory_info.push( bind_info );
```




**array_offset** is an offset into the **pending_sparse_queue_binds** array so that we can store all pending allocations in a single array.

Now that we have recorded the list of allocation updates, we need to submit them to a queue for them to be executed by the GPU.

- First, we populate a **VkSparseImageMemoryBindInfo** structure for each layer:

```
for ( u32 b = 0; b < pending_sparse_memory_info.size;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;++b ) {
```

```
&#160;&#160;&#160;&#160;SparseMemoryBindInfo& internal_info =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pending_sparse_memory_info[ b ];
```

```
&#160;&#160;&#160;&#160;VkSparseImageMemoryBindInfo& info =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sparse_binding_infos[ b ];
```

```
&#160;&#160;&#160;&#160;info.image = internal_info.image;
```

```
&#160;&#160;&#160;&#160;info.bindCount = internal_info.count;
```

```
&#160;&#160;&#160;&#160;info.pBinds = pending_sparse_queue_binds.data +
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;internal_info.binding_array_offset;
```

```
}
```


- Next, we submit all pending binding operations to the main queue:

```
VkBindSparseInfo sparse_info{
```

```
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_BIND_SPARSE_INFO };
```

```
sparse_info.imageBindCount =
```

```
&#160;&#160;&#160;&#160;sparse_binding_infos.size;
```

```
sparse_info.pImageBinds = sparse_binding_infos.data;
```

```
sparse_info.signalSemaphoreCount = 1;
```

```
sparse_info.pSignalSemaphores =
```

```
&#160;&#160;&#160;&#160;&vulkan_bind_semaphore;
```

```
vkQueueBindSparse( vulkan_main_queue, 1, &sparse_info,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_NULL_HANDLE );
```




It’s important to note that it’s the responsibility of the user to make sure this operation is completed before accessing the resources whose allocations we just updated. We achieve this by signaling a semaphore, **vulkan_bind_semaphore**, which will then be waited on by the main rendering work submission.

It’s important to note that the queue we call **vkQueueBindSparse** on must have the **VK_QUEUE_SPARSE_BINDING_BIT** flag.

In this section, we have covered the steps necessary to allocate and use sparse textures. We first explained how sparse textures work and why they are useful for our cubemap use case.

Next, we illustrated the algorithm we used to dynamically determine the resolution of each cubemap based on each light contribution to the scene. Finally, we demonstrated how to use the Vulkan API to bind memory to sparse resources.

# 小结
In this chapter, we extended our lighting system to support many point lights with an efficient implementation. We started with a brief history of shadow algorithms, and their benefits and shortcomings, up until some of the most recent techniques that take advantage of raytracing hardware.

Next, we covered our implementation of shadows for many point lights. We explained how cubemaps are generated for each light and the optimizations we implemented to make the algorithm scale to many lights. In particular, we highlighted the culling method we reused from the main geometry pass and the use of a single indirect draw call for each light.

In the last section, we introduced sparse textures, a technique that allows us to dynamically bind memory to a given resource. We highlighted the algorithm we used to determine the contribution of each point light to the scene and how we use that information to determine the resolution of each cubemap. Finally, we demonstrated how to use sparse resources with the Vulkan API.

While we only covered point lights in this chapter, some of the techniques can be reused with other types of lights. Some steps could also be optimized further: for instance, it’s possible to further reduce the cubemap resolution to account only for the area where geometry is visible.

The cluster computation is currently done on the CPU for clarity and to avoid having to read back the cluster data from the GPU, which could be a slow operation, but it might be worth moving the implementation to the GPU. We encourage you to experiment with the code and add more features!

# 延伸阅读
The book *Real-Time Shadows* provides a good overview of many techniques to implement shadows, many of which are still in use today.

*GPU Pro 360 Guide to Shadows* collects articles from the *GPU Pro* series that are focused on shadows.

An interesting technique described in the book is called tetrahedron shadow mapping: the idea is to project the shadow map to a tetrahedron and then unwrap it to a single texture.

The original concept was introduced in the *Shadow Mapping for Omnidirectional Light Using Tetrahedron Mapping* chapter (originally published in *GPU Pro*) and later expanded in *Tile-based Omnidirectional Shadows* (originally published in *GPU **Pro 6*).

For more details, we refer you to the code provided by the author: [http://www.hd-prg.com/tileBasedShadows.html](http://www.hd-prg.com/tileBasedShadows.html).

Our sparse texture implementation is based on this SIGGRAPH presentation: [https://efficientshading.com/wp-content/uploads/s2015_shadows.pdf](https://efficientshading.com/wp-content/uploads/s2015_shadows.pdf).

This expands on their original paper, found here: [http://newq.net/dl/pub/MoreEfficientClusteredShadowsPreprint.pdf.](http://newq.net/dl/pub/MoreEfficientClusteredShadowsPreprint.pdf&#xd;)

While we haven’t implemented it in this chapter, shadow map caching is an important technique to reduce the cost of computing shadow maps and amortize the shadow map updates over several frames.

A good starting point is this presentation: [https://www.activision.com/cdn/research/2017_DD_Rendering_of_COD_IW.pdf](https://www.activision.com/cdn/research/2017_DD_Rendering_of_COD_IW.pdf).

Our cluster computation closely follows the one presented in this article: [http://www.aortiz.me/2018/12/21/CG.html#part-2.](http://www.aortiz.me/2018/12/21/CG.html#part-2&#xd;)

The Vulkan specification provides many more details on how to use the API for sparse resources: [https://registry.khronos.org/vulkan/specs/1.2-extensions/html/vkspec.html#sparsememory](https://registry.khronos.org/vulkan/specs/1.2-extensions/html/vkspec.html#sparsememory).