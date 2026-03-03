# Chapter 11: Temporal Anti-Aliasing

# 11



# Temporal Anti-Aliasing


In this chapter, we will expand on a concept touched on in the previous one when we talked about temporal reprojection. One of the most common ways to improve image quality is to sample more data (super-sampling) and filter it down to the needed sampling frequency.

The primary technique used in rendering is **Multi-Sample Anti-Aliasing**, or **MSAA**. Another technique used for super-sampling is temporal super-sampling or using the samples from two or more frames to reconstruct a higher-quality image.

In the Volumetric Fog technique, a similar approach is used to remove banding given by the low resolution of the Volume Texture in a very effective way. We will see how we can achieve better image quality using **Temporal ****Anti-Aliasing** (**TAA**).

This technique has become widely used in recent years after more and more games started using Deferred Rendering at their core and because of the difficulty in applying MSAA on it. There were various attempts to make MSAA and Deferred Rendering work together, but performance (both time- and memory-wise) has always been proven to not be feasible at the time and thus alternative solutions started to be developed.

Enter **Post-Process Anti-Aliasing** and its plethora of acronyms. The first one to be widely used was **Morphological Anti-Aliasing**, or **MLAA**, developed by Alexander Reshetov, working at Intel at the time, and presented at High-Performance Graphics in 2009.

The algorithm was developed to work on the CPU using Intel’s **Streaming SIMD Extensions** (**SSE**) instructions and introduced some interesting solutions to find and improve geometrical edge rendering, which fueled successive implementations. Later, Sony Santa Monica adopted MLAA for God of War III using the Cell **Synergisic Processing Unit** (**SPUs**) to be performed with real-time performances.

Post-Process Anti-Aliasing finally found a GPU implementation developed by Jorge Jimenez and others in 2011, opening a new rendering research field. Various other game studios started developing custom Post Process Anti-Aliasing techniques and sharing their details.

All those techniques were based on geometrical edge recognition and image enhancement.

Another aspect that started to emerge was the reuse of information from previous frames to further enhance visual quality, such as in **Sharp Morphological Anti-Aliasing**, or **SMAA**, which started adding a temporal component to enhance the final image.

The most adopted anti-aliasing technique is TAA, which comes with its own set of challenges but fits nicely within the rendering pipeline and lets other techniques (such as Volumetric Fog) increase their visual quality by reducing banding with the introduction of animated dithering.

TAA is now the standard in most game engines, both commercial and private. It comes with its own challenges, such as handling transparent objects and image blurriness, but we will see how to tackle those problems as well.

In the rest of the chapter, we will first see an overview of the algorithm and then dive into the implementation. We will also create an initial, incredibly simple implementation just to show the basic building blocks of the algorithm, allowing you to understand how to write a custom TAA implementation from scratch. Finally, we will see the different areas of improvement within the algorithm.

Let’s see an example scene and highlight the TAA improvements:



 ![Figure 11.1 – Temporally anti-aliased scene](image/B18395_11_01.jpg)


Figure 11.1 – Temporally anti-aliased scene

The following are a couple of screenshots of the final result, with and without TAA enabled.



 ![Figure 11.2 – Details of Figure 11.1 without (left) and with (right) TAA](image/B18395_11_02.jpg)


Figure 11.2 – Details of Figure 11.1 without (left) and with (right) TAA

In this chapter, we will have a look at the following topics:

- Creating the simplest TAA implementation


- Step-by-step improvement of the technique


- Overview of image-sharpening techniques outside of TAA


- Improving banding in different image areas with noise and TAA





# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter11](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter11).

# Overview


本节将see the algorithm overview of the TAA rendering technique.

TAA is based on the collection of samples over time by applying small offsets to the camera projection matrix and applying some filters to generate the final image, like so:



 ![Figure 11.3 – Frustum jitter](image/B18395_11_03.jpg)


Figure 11.3 – Frustum jitter

There are various numerical sequences that can be used to offset the camera, as we will see in the implementation section. Moving the camera is called **jittering**, and by jittering the camera, we gather additional data that we can use to enhance the image.

The following is an overview of the TAA shader:



 ![Figure 11.4 – TAA algorithm overview](image/B18395_11_04.jpg)


Figure 11.4 – TAA algorithm overview

Based on *Figure 11**.4*, we’ve separated the algorithm into steps (blue rectangles) and texture reads (yellow ellipses:.

- We calculate the coordinates to read the velocity from, represented by the **Velocity ****Coordinates** block.




This is normally done by reading a neighborhood of 3x3 pixels around the current pixel position and finding the closest pixel, using the current frame’s **Depth Texture**. Reading from a 3x3 neighborhood has been proven to decrease ghosting and improve edge quality.

- We read the velocity using the newly found coordinates from the **Velocity Texture** block, paying attention to use a linear sampler, as velocity is not just in increments of pixels, but can be in-between pixels.


- We read the color information from the **History Texture** block. This is basically the last frame’s TAA output. We can optionally apply a filter to read the texture to further enhance the quality.


- We will read the current scene color. In this step, we will also cache information again by reading a neighborhood around the current pixel position to constrain the history color we read previously and guide the final resolve phase.


- History constraint. We try to limit the previous frame color inside an area of the current color to reject invalid samples coming from occlusion or disocclusion. Without doing that there would be a lot of ghosting.


- The sixth and final step is **Resolve**. We combine the current color and the constraint history color to generate the final pixel color by applying some additional filters.




The result of the current frame’s TAA will be the next frame history texture, so we simply switch the textures (history and TAA result) every frame without the need to copy the results over, as seen in some implementations.

Now that we have seen an overview of the algorithm, we can start by implementing an initial TAA shader.

# The simplest TAA implementation


The best way to understand this technique is to build a basic implementation missing some important steps and to have a blurry or jittery rendering as it is easy to do.

The basic ingredients for this technique are simple if done correctly, but each must be done in a precise way. We will first add jittering to the camera so that we can render slightly different points of view of the scene and gather additional data.

We will then add motion vectors so that we can read the previous frame color information in the right place. Finally, we will reproject, or simply put, read the history frame color data and combine it with current frame data.

Let us see the different steps.

## Jittering the camera


The objective of this step is to translate the projection camera by a small amount in both the *x* and *y* axes.

We have added some utility code in the **GameCamera** class:

```
void GameCamera::apply_jittering( f32 x, f32 y ) {
&#160;&#160;&#160;&#160;// Reset camera projection
&#160;&#160;&#160;&#160;camera.calculate_projection_matrix();
&#160;&#160;&#160;&#160;// Calculate jittering translation matrix and modify
&#160;&#160;&#160;&#160;&#160;&#160;&#160;projection matrix
&#160;&#160;&#160;&#160;mat4s jittering_matrix = glms_translate_make( { x, y,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;0.0f } );
&#160;&#160;&#160;&#160;camera.projection = glms_mat4_mul( jittering_matrix,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;camera.projection );
&#160;&#160;&#160;&#160;camera.calculate_view_projection();
}
```


Every step is important and error prone, so be careful.

We first want to reset the projection matrix, as we will manually modify it. We then build a translation matrix with the jittering values in **x** and **y**, and we will see later how to calculate them.

Finally, we multiply the projection matrix by the jittering matrix and calculate the new view-projection matrix. Beware of multiplication order, as if this is wrong you will see a jittery blurry mess even when not moving the camera!

Having this working, we can optimize the code by removing the matrix construction and multiplication, having cleaner and less error-prone code, like so:

```
void GameCamera::apply_jittering( f32 x, f32 y ) {
&#160;&#160;&#160;camera.calculate_projection_matrix();
&#160;&#160;&#160;// Perform the same calculations as before, with the
&#160;&#160;&#160;&#160;&#160;&#160;observation that
&#160;&#160;&#160;// we modify only 2 elements in the projection matrix:
&#160;&#160;&#160;camera.projection.m20 += x;
&#160;&#160;&#160;camera.projection.m21 += y;
&#160;&#160;&#160;camera.calculate_view_projection();
}
```



## Choosing jittering sequences


We will now build a sequence of **x** and **y** values to jitter the camera. Normally there are different sequences that are used:

- Halton


- Hammersley


- Martin Robert’s R2


- Interleaved gradients




There are all the implementations for the preceding sequences in the code, and each can give a slightly different look to the image, as it changes how we collect samples over time.

There is plenty of material on using the different sequences that we will provide links to at the end of the chapter; right now what is important is to know that we have a sequence of two numbers that we repeat after a few frames to jitter the camera.

Let us say that we choose the Halton sequence. We first want to calculate the values for **x** and **y**:

```
&#160;&#160;&#160;f32 jitter_x = halton( jitter_index, 2 );
&#160;&#160;&#160;f32 jitter_y = halton( jitter_index, 3 );
```


These values are in the **[0,1]** range, but we want to jitter in both directions, so we map it to the **[-****1.1]** range:

```
&#160;&#160;&#160;&#160;f32 jitter_offset_x = jitter_x * 2 - 1.0f;
&#160;&#160;&#160;&#160;f32 jitter_offset_y = jitter_y * 2 - 1.0f;
```


We now apply them to the apply **jitter** method, with a caveat: we want to add sub-pixel jittering, thus we need to divide these offsets by the screen resolution:

```
game_camera.apply_jittering( jitter_offset_x / gpu.swapchain_width, jitter_offset_y / gpu.swapchain_height );
```


Finally, we have a jitter period to choose after how many frames we repeat the jittering numbers, updated like this:

```
jitter_index = ( jitter_index + 1 ) % jitter_period;
```


A good period is normally four frames, but in the accompanying code, there is the possibility to change this number and see the effect on the rendering image.

Another fundamental thing to do is to cache previous and current jittering values and send them to the GPU, so that motion vectors take into consideration the full movement.

We’ve added **jitter_xy** and **previous_jitter_xy** as variables in the scene uniforms to be accessed in all shaders.

## Adding motion vectors


Now that we correctly jittered the camera and saved the offsets, it is time to add motion vectors to properly read the color data from the previous frame. There are two sources of motion: camera motion and dynamic object motion.

We added a velocity texture with R16G16 format to store the per-pixel velocity. For each frame, we clear that to **(0,0)** and we calculate the different motions. For camera motion, we will calculate the current and previous screen space position, considering the jitter and the motion vector.

We will perform this in a compute shader:

```
layout (local_size_x = 8, local_size_y = 8, local_size_z =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1) in;
void main() {
&#160;&#160;&#160;&#160;ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);
&#160;&#160;&#160;&#160;// Read the raw depth and reconstruct NDC coordinates.
&#160;&#160;&#160;&#160;const float raw_depth = texelFetch(global_textures[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(depth_texture_index)], pos.xy, 0).r;
&#160;&#160;&#160;&#160;const vec2 screen_uv = uv_nearest(pos.xy, resolution);
&#160;&#160;&#160;&#160;vec4 current_position_ndc = vec4(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ndc_from_uv_raw_depth( screen_uv, raw_depth ), 1.0f
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;// Reconstruct world position and previous NDC position
&#160;&#160;&#160;&#160;const vec3 pixel_world_position =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_position_from_depth
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(screen_uv, raw_depth, inverse_view_projection);
&#160;&#160;&#160;&#160;vec4 previous_position_ndc = previous_view_projection *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4(pixel_world_position, 1.0f);
&#160;&#160;&#160;&#160;previous_position_ndc.xyz /= previous_position_ndc.w;
&#160;&#160;&#160;&#160;// Calculate the jittering difference.
&#160;&#160;&#160;&#160;vec2 jitter_difference = (jitter_xy –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;previous_jitter_xy)* 0.5f;
&#160;&#160;&#160;&#160;// Pixel velocity is given by the NDC [-1,1] difference
&#160;&#160;&#160;&#160;&#160;&#160;&#160;in X and Y axis
&#160;&#160;&#160;&#160;vec2 velocity = current_position_ndc.xy –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;previous_position_ndc.xy;
&#160;&#160;&#160;&#160;// Take in account jittering
&#160;&#160;&#160;&#160;velocity -= jitter_difference;
&#160;&#160;&#160;&#160;imageStore( motion_vectors, pos.xy, vec4(velocity, 0,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;0) );
```


Dynamic meshes need an additional output to be written in the vertex or mesh shaders, with similar calculations done in the camera motion shader:

```
// Mesh shader version
gl_MeshVerticesNV[ i ].gl_Position = view_projection *
&#160;&#160;&#160;&#160;(model * vec4(position, 1));
vec4 world_position = model * vec4(position, 1.0);
vec4 previous_position_ndc = previous_view_projection *
&#160;&#160;&#160;&#160;vec4(world_position, 1.0f);
previous_position_ndc.xyz /= previous_position_ndc.w;
vec2 jitter_difference = (jitter_xy - previous_jitter_xy) *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;0.5f;
vec2 velocity = gl_MeshVerticesNV[ i ].gl_Position.xy –
&#160;&#160;&#160;&#160;previous_position_ndc.xy - jitter_difference;
vTexcoord_Velocity[i] = velocity;
```


And after this, just writing the velocity to its own render target will be all that is needed.

Now that we have the motion vectors, we can finally see the implementation of an extremely basic TAA shader.

## First implementation code


We again run a compute shader to calculate TAA. The implementation of the simplest possible shader is the following:

```
vec3 taa_simplest( ivec2 pos ) {
&#160;&#160;&#160;&#160;const vec2 velocity = sample_motion_vector( pos );
&#160;&#160;&#160;&#160;const vec2 screen_uv = uv_nearest(pos, resolution);
&#160;&#160;&#160;&#160;const vec2 reprojected_uv = screen_uv - velocity;
&#160;&#160;&#160;&#160;vec3 current_color = sample_color(screen_uv.xy).rgb;
&#160;&#160;&#160;&#160;vec3 history_color =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sample_history_color(reprojected_uv).rgb;
&#160;&#160;&#160;&#160;// source_weight is normally around 0.9.
&#160;&#160;&#160;&#160;return mix(current_color, previous_color,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;source_weight);
}
```


Going through the code, the steps are simple:

- Sample the velocity at the pixel position.


- Sample the current color at the pixel position.


- Sample the history color at the previous pixel position, calculated using the motion vectors.


- Mix the colors, taking something like 10% of the current frame colors.




Before moving on to any improvement it is paramount to have this working perfectly.

You should see a blurrier image with a big problem: ghosting when moving the camera or an object. If the camera and the scene are static, there should be no pixel movement. This is fundamental to knowing that jittering and reprojection are working properly.

With this implementation working, we are now ready to see the different improvement areas to have a more solid TAA.

# Improving TAA


There are five areas to improve TAA: reprojection, history sampling, scene sampling, history constraint, and resolve.

Each one has different parameters to be tweaked that can suit the rendering needs of a project – TAA is not exact or perfect, thus some extra care from a visual perspective needs to be taken into account.

Let’s see the different areas in detail so that the accompanying code will be clearer.

## Reprojection


The first thing to do is to improve reprojection and thus calculate the coordinates to read the velocity to drive the *History **sampling* section.

To calculate the history texture pixel coordinates, the most common solution is to get the closest pixel in a 3x3 square around the current pixel, as an idea by Brian Karis. We will read the depth texture and use the depth value as a way to determine the closest pixel, and cache the **x** and **y** position of that pixel:

```
void find_closest_fragment_3x3(ivec2 pixel, out ivec2
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;closest_position, out
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float closest_depth) {
&#160;&#160;&#160;&#160;closest_depth = 1.0f;
&#160;&#160;&#160;&#160;closest_position = ivec2(0,0);
&#160;&#160;&#160;&#160;for (int x = -1; x <= 1; ++x ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;for (int y = -1; y <= 1; ++y ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec2 pixel_position = pixel + ivec2(x, y);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pixel_position = clamp(pixel_position,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec2(0), ivec2(resolution.x - 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resolution.y - 1));
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float current_depth =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texelFetch(global_textures[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(depth_texture_index)],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pixel_position, 0).r;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( current_depth < closest_depth ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;closest_depth = current_depth;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;closest_position = pixel_position;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
}
```


By just using the found pixel position as the read coordinate for the motion vectors, ghosting will be much less visible, and edges will be smoother:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float closest_depth = 1.0f;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec2 closest_position = ivec2(0,0);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;find_closest_fragment_3x3( pos.xy,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;closest_position,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;closest_depth );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const vec2 velocity = sample_motion_vector
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(closest_position.xy);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// rest of the TAA shader
```


There can be other ways of reading the velocity, but this has proven to be the best trade-off between quality and performance. Another way to experiment would be to use the maximum velocity in a similar 3x3 neighborhood of pixels.

There is no perfect solution, and thus experimentation and parametrization of the rendering technique are highly encouraged. After we have calculated the pixel position of the history texture to read, we can finally sample it.

## History sampling


In this case, the simplest thing to do is to just read the history texture at the calculated position. The reality is that we can apply a filter to enhance the visual quality of the read as well.

In the code, we’ve added options to try different filters, and the standard choice here is to use a Catmull-Rom filter to enhance the sampling:

```
&#160;&#160;&#160;// Sample motion vectors.
&#160;&#160;&#160;&#160;const vec2 velocity = sample_motion_vector_point(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;closest_position );
&#160;&#160;&#160;&#160;const vec2 screen_uv = uv_nearest(pos.xy, resolution);
&#160;&#160;&#160;&#160;const vec2 reprojected_uv = screen_uv - velocity;
&#160;&#160;&#160;&#160;// History sampling: read previous frame samples and
&#160;&#160;&#160;&#160;&#160;&#160;&#160;optionally apply a filter to it.
&#160;&#160;&#160;&#160;vec3 history_color = vec3(0);
&#160;&#160;&#160;&#160;history_color = sample_history_color(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;reprojected_uv ).rgb;
&#160;&#160;&#160;&#160;switch (history_sampling_filter) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;case HistorySamplingFilterSingle:
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_color = sample_history_color(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;reprojected_uv ).rgb;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;case HistorySamplingFilterCatmullRom:
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_color = sample_texture_catmull_rom(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;reprojected_uv,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_color_texture_index );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;}
```


After we have the history color, we will sample the current scene color and cache information needed for both the history constraint and the final resolve phase.

Using the history color without further processing would result in ghosting.

## Scene sampling


At this point, ghosting is less noticeable but still present, so with a similar mentality to searching for the closest pixel, we can search around the current pixel to calculate color information and apply a filter to it.

Basically, we are treating a pixel like a signal instead of a simple color. The subject can be quite long and interesting and at the end of the chapter, there will be resources to dive deeper into this. Also, in this step, we will cache information used for the history boundaries used to constrain the color coming from the previous frames.

What we need to know is that we sample another 3x3 area around the current pixel and calculate the information necessary for the constraint to happen. The most valuable information is the minimum and maximum color in this area, and Variance Clipping (which we will look at later on) also requires mean color and square mean color (known as **moments**) to be calculated to aid history constraint. Finally, we will also apply some filtering to the sampling of the color.

Let’s see the code:

```
// Current sampling: read a 3x3 neighborhood and cache
&#160;&#160;&#160;color and other data to process history and final
&#160;&#160;&#160;resolve.
&#160;&#160;&#160;&#160;// Accumulate current sample and weights.
&#160;&#160;&#160;&#160;vec3 current_sample_total = vec3(0);
&#160;&#160;&#160;&#160;float current_sample_weight = 0.0f;
&#160;&#160;&#160;&#160;// Min and Max used for history clipping
&#160;&#160;&#160;&#160;vec3 neighborhood_min = vec3(10000);
&#160;&#160;&#160;&#160;vec3 neighborhood_max = vec3(-10000);
&#160;&#160;&#160;&#160;// Cache of moments used in the constraint phase
&#160;&#160;&#160;&#160;vec3 m1 = vec3(0);
&#160;&#160;&#160;&#160;vec3 m2 = vec3(0);
&#160;&#160;&#160;&#160;for (int x = -1; x <= 1; ++x ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;for (int y = -1; y <= 1; ++y ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec2 pixel_position = pos + ivec2(x, y);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pixel_position = clamp(pixel_position,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec2(0), ivec2(resolution.x - 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resolution.y - 1));
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 current_sample =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sample_current_color_point(pixel_position).rgb;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec2 subsample_position = vec2(x * 1.f, y *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1.f);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float subsample_distance = length(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;subsample_position
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float subsample_weight = subsample_filter(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;subsample_distance );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_sample_total += current_sample *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;subsample_weight;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_sample_weight += subsample_weight;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;neighborhood_min = min( neighborhood_min,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_sample );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;neighborhood_max = max( neighborhood_max,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_sample );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;m1 += current_sample;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;m2 += current_sample * current_sample;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
vec3 current_sample = current_sample_total /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_sample_weight;
```


What all this code does is sample color, filter it, and cache information for the history constraint, and thus we are ready to move on to the next phase.

## The history constraint


Finally, we arrived at the constraint of the history sampled color. Based on previous steps we have created a range of possible color values that we consider valid. If we think of each color channel as a value, we basically created an area of valid colors that we will constraint against.

A constraint is a way of accepting or discarding color information coming from the history texture, reducing ghosting to almost nothing. Over time, different ways to constrain history sampled color were developed in search of better criteria to discard colors.

Some implementations also tried relying on depth or velocity differences, but this seems to be the more robust solution.

We have added four constraints to test:

- RGB clamp


- RGB clip


- Variance clip


- Variance clip with clamped RGB




The best quality is given by variance clip with the clamped RGB, but it is interesting to see the other ones, as they are the ones that were employed in the first implementations.

Here is the code:

```
&#160;&#160;&#160;&#160;switch (history_clipping_mode) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// This is the most complete and robust history
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;clipping mode:
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;case HistoryClippingModeVarianceClipClamp:
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;default: {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Calculate color AABB using color moments m1
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;and m2
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float rcp_sample_count = 1.0f / 9.0f;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float gamma = 1.0f;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 mu = m1 * rcp_sample_count;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 sigma = sqrt(abs((m2 * rcp_sample_count) –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(mu * mu)));
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 minc = mu - gamma * sigma;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 maxc = mu + gamma * sigma;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Clamp to new AABB
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 clamped_history_color = clamp(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_color.rgb,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;neighborhood_min,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;neighborhood_max
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_color.rgb = clip_aabb(minc, maxc,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4(clamped_history_color,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1), 1.0f).rgb;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
```


The **clip_aabb** function is the method that constrains the sampled history color within minimum and maximum color values.

In brief, we are trying to build an AABB in colorspace to limit the history color to be within that range, so that the final color is more plausible compared to the current one.

The last step in the TAA shader is resolve, or combining current and history colors and applying some filters to generate the final pixel color.

## Resolve


Once again, we will apply some additional filters to decide whether the previous pixel is usable or not and by how much.

By default, we start with using just 10% of the current frame pixel and rely on history, so without any of those filters the image will be quite blurry:

```
// Resolve: combine history and current colors for final
&#160;&#160;&#160;pixel color
&#160;&#160;&#160;&#160;vec3 current_weight = vec3(0.1f);
&#160;&#160;&#160;&#160;vec3 history_weight = vec3(1.0 - current_weight);
```


The first filter we will see is the temporal one, which uses the cached neighborhood minimum and maximum colors to calculate how much to blend the current and previous colors:

```
&#160;&#160;&#160;&#160;// Temporal filtering
&#160;&#160;&#160;&#160;if (use_temporal_filtering() ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 temporal_weight = clamp(abs(neighborhood_max –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;neighborhood_min) /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_sample,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(0), vec3(1));
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_weight = clamp(mix(vec3(0.25), vec3(0.85),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;temporal_weight), vec3(0),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(1));
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_weight = 1.0f - history_weight;
&#160;&#160;&#160;&#160;}
```


The next two filters are linked; thus, we have them together.

They both work with luminance, with one used to suppress so-called **fireflies**, or very bright single pixels that can exist in images when there is a strong source of light, while the second uses the difference in luminance to further steer the weight toward either the current or previous colors:

```
&#160;&#160;&#160;&#160;// Inverse luminance filtering
&#160;&#160;&#160;&#160;if (use_inverse_luminance_filtering() ||
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;use_luminance_difference_filtering() ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Calculate compressed colors and luminances
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 compressed_source = current_sample /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(max(max(current_sample.r, current_sample.g),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_sample.b) + 1.0f);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 compressed_history = history_color /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(max(max(history_color.r, history_color.g),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_color.b) + 1.0f);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float luminance_source = use_ycocg() ?
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;compressed_source.r :
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;luminance(compressed_source);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float luminance_history = use_ycocg() ?
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;compressed_history.r :
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;luminance(compressed_history);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( use_luminance_difference_filtering() ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float unbiased_diff = abs(luminance_source –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;luminance_history) / max(luminance_source,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max(luminance_history, 0.2));
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float unbiased_weight = 1.0 - unbiased_diff;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float unbiased_weight_sqr = unbiased_weight *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;unbiased_weight;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float k_feedback = mix(0.0f, 1.0f,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;unbiased_weight_sqr);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_weight = vec3(1.0 - k_feedback);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_weight = vec3(k_feedback);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_weight *= 1.0 / (1.0 + luminance_source);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_weight *= 1.0 / (1.0 + luminance_history);
&#160;&#160;&#160;&#160;}
```


We combine the result using the newly calculated weights, and finally, we output the color:

```
&#160;&#160;&#160;&#160;vec3 result = ( current_sample * current_weight +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_color * history_weight ) /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160; max( current_weight + history_weight,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160; 0.00001 );
&#160;&#160;&#160;&#160;return result;
```


At this point, the shader is complete and ready to be used. In the accompanying demo, there will be many tweaking parameters to learn the differences between the different filters and steps involved.

One of the most common complaints about TAA is the blurriness of the image. We will see a couple of ways to improve that next.

# Sharpening the image


One thing that can be noticed in the most basic implementation, and a problem often linked to TAA, is a decrease in the sharpness of the image.

We have already improved it by using a filter when sampling the scene, but we can work on the final image appearance outside of TAA in different ways. We will briefly discuss three different ways to improve the sharpening of the image.

## Sharpness post-processing


One of the ways to improve the sharpness of the image is to add a simple sharpening shader in the post-process chain.

The code is simple, and it is luminance based:

```
&#160;&#160;&#160;&#160;vec4 color = texture(global_textures[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(texture_id)], vTexCoord.xy);
&#160;&#160;&#160;&#160;float input_luminance = luminance(color.rgb);
&#160;&#160;&#160;&#160;float average_luminance = 0.f;
&#160;&#160;&#160;&#160;// Sharpen
&#160;&#160;&#160;&#160;for (int x = -1; x <= 1; ++x ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;for (int y = -1; y <= 1; ++y ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 sampled_color = texture(global_textures[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(texture_id)], vTexCoord.xy +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec2( x / resolution.x, y /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resolution.y )).rgb;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;average_luminance += luminance( sampled_color
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;average_luminance /= 9.0f;
&#160;&#160;&#160;&#160;float sharpened_luminance = input_luminance –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;average_luminance;
&#160;&#160;&#160;&#160;float final_luminance = input_luminance +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sharpened_luminance *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sharpening_amount;
&#160;&#160;&#160;&#160;color.rgb = color.rgb * (final_luminance /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;input_luminance);
```


Based on this code, when the sharpening amount is **0** the image is not sharpened. The standard value is **1**.

## Negative mip bias


A global way to reduce blurriness is to modify the **mipLodBias** field in the **VkSamplerCreateInfo** structure to be a negative number, such as **–0.25**, thus shifting the texture **mip,** the pyramid of progressively smaller images of a texture to higher values.

This should be done by considering the performance difference, as we are sampling at a higher MIP level, and if the level is too high, we could re-introduce aliasing.

A global engine option to tweak would be a great solution to this.

## Unjitter texture UVs


Another possible fix to sample sharper textures is to calculate the UVs as the camera was without any jittering, like so:

```
vec2 unjitter_uv(float uv, vec2 jitter) {
&#160;&#160;&#160;&#160;return uv - dFdxFine(uv) * jitter.x + dFdyFine(uv) *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;jitter.y;
}
```


I personally did not try this method but found it interesting and something to experiment with. It was written about by Emilio Lopez in his TAA article, linked in the *Reference* section, also citing a colleague named Martin Sobek who came up with the idea.

The combination of TAA and sharpening drastically improves the edges of the image while retaining the details inside the objects.

We need to look at one last aspect of the image: banding.

# Improving banding


Banding is a problem affecting various steps in the rendering of a frame. It affects Volumetric Fog and lighting calculations, for example.



 ![Figure 11.5 – Banding problem detail in Volumetric Fog](image/B18395_11_05.jpg)


Figure 11.5 – Banding problem detail in Volumetric Fog

We can see in *Figure 11**.5* how this can be present in Volumetric Fog if no solution is implemented. A solution to remove banding in visuals is to add some dithering to various passes of the frame, but that also adds visual noise to the image.

Dithering is defined as the intentional addition of noise specifically to remove banding. Different type of noises can be used, as we will see in the accompaining code. Adding temporal reprojection smoothens the noise added, thus becoming one of the best ways to improve the visual quality of the image.

In [*Chapter 10*](B18395_10.xhtml#_idTextAnchor152), *Adding Volumetric Fog*, we saw a very simple temporal reprojection scheme, and we have also added noise to various steps of the algorithm. We have now seen a more complex implementation of a temporal reprojection scheme to enhance the image, and it should be clearer on reasoning behind animated dithering: animating dithering gives effectively more samples, and thanks to temporal reprojection, uses them effectively. Dithering is linked to its own temporal reprojection, thus in the Volumetric Fog steps, the dithering scale can be too large to be cleaned up by TAA.

When applying Volumetric Fog to the scene though, we can add a small, animated dithering that increases the fog visuals while being cleaned up by TAA. Another dithering application is in the lighting shader, again at the per-pixel level and thus eligible to be cleaned up by TAA.

说明

Trying to get a noise-free image is hard as the temporal reprojection uses more than one frame, thus it is not possible to show here in an image what appears banding-free in the accompanying application.

# 小结
In this chapter, we introduced the TAA rendering technique.

We gave an overview of the algorithm by trying to highlight the different shader steps involved. We then moved on to create the simplest possible TAA shader: an exercise to give us a deeper understanding of the technique itself.

Following that, we started enhancing the various steps using filters and information taken from the current scene. We encourage you to add custom filters and tweak parameters and different scenes to understand and develop the technique further.

An idea to experiment with could also be to apply the history constraint to the temporal reprojection phase of the Volumetric Fog, as suggested by my friend Marco Vallario a few months ago.

In the next chapter, we will add support for ray tracing to the Raptor Engine, a recent technological advancement that unlocks high-quality illumination techniques, which we will cover in the following chapters.

# 延伸阅读
We touched on several topics in this chapter, from the history of post-process anti-aliasing to implementations of TAA, to banding and noise.

Thanks to the graphics community, which shares a lot of information on their findings, it is possible to sharpen our knowledge on this subject.

The following are some links to read:

- For an index of the evolution of Post-Process Anti-Aliasing techniques: [http://www.iryoku.com/research-impact-retrospective-mlaa-from-2009-to-2017](http://www.iryoku.com/research-impact-retrospective-mlaa-from-2009-to-2017).


- The first MLAA paper: [https://www.intel.com/content/dam/develop/external/us/en/documents/z-shape-arm-785403.pdf](https://www.intel.com/content/dam/develop/external/us/en/documents/z-shape-arm-785403.pdf).


- An MLAA GPU implementation: [http://www.iryoku.com/mlaa/](http://www.iryoku.com/mlaa/).


- SMAA, an evolution of MLAA: [http://www.iryoku.com/smaa/](http://www.iryoku.com/smaa/).


- The best article on signal processing and anti-aliasing by Matt Pettineo: [https://therealmjp.github.io/posts/msaa-resolve-filters/](https://therealmjp.github.io/posts/msaa-resolve-filters/).


- Temporal Reprojection Anti-Aliasing in Inside, containing the first full documentation of a TAA technique. Includes information about history constraints and AABB clipping: [http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463](http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463).


- High-Quality Temporal Supersampling, Unreal Engine TAA implementation: [https://de45xmedrsdbp.cloudfront.net/Resources/files/TemporalAA_small-59732822.pdf](https://de45xmedrsdbp.cloudfront.net/Resources/files/TemporalAA_small-59732822.pdf).


- An excursion in temporal super-sampling, introducing variance clipping: [https://developer.download.nvidia.com/gameworks/events/GDC2016/msalvi_temporal_supersampling.pdf](https://developer.download.nvidia.com/gameworks/events/GDC2016/msalvi_temporal_supersampling.pdf).


- A TAA article, with tips, such as UV unjittering and Mip bias: [https://www.elopezr.com/temporal-aa-and-the-quest-for-the-holy-trail/](https://www.elopezr.com/temporal-aa-and-the-quest-for-the-holy-trail/).


- Another great TAA article with a full implementation: [https://alextardif.com/TAA.html](https://alextardif.com/TAA.html).


- Banding in games: [https://loopit.dk/banding_in_games.pdf](https://loopit.dk/banding_in_games.pdf).