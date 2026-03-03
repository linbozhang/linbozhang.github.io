# Chapter 7: Rendering Many Lights with Clustered Deferred Rendering

# 7



# Rendering Many Lights with Clustered Deferred Rendering


Until now, our scene has been lit by a single point light. While this has worked fine so far as we focused our attention more on laying the foundations of our rendering engine, it’s not a very compelling and realistic use case. Modern games can have hundreds of lights in a given scene, and it’s important that the lighting stage is performed efficiently and within the budget of a frame.

In this chapter, we will first describe the most common techniques that are used both in deferred and forward shading. We will highlight the pros and cons of each technique so that you can determine which one best fits your needs.

Next, we are going to provide an overview of our G-buffer setup. While the G-buffer has been in place from the very beginning, we haven’t covered its implementation in detail. This is a good time to go into more detail, as the choice of a deferred renderer will inform our strategy for clustered lighting.

Finally, we are going to describe our clustering algorithm in detail and highlight the relevant sections of the code. While the algorithm itself is not too complex, there are a lot of details that are important to get a stable solution.

In this chapter, we’re going to cover the following main topics:

- A brief history of clustered lighting


- Our G-buffer setup and implementation


- Implementing clustered lighting using screen tiles and Z-binning





# 技术需求
By the end of the chapter you will have a solid understanding of our G-buffer implementation. You will also learn how to implement a state of the art light clustering solution that can handle hundreds of lights.

本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter7](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter7).

# A brief history of clustered lighting


In this section, we are going to explore the background of how clustered lighting came to be and how it has evolved over the years.

In real-time applications, until the early 2000s, the most common way to handle lighting was by using the so-called **forward rendering**, a technique that renders each object on the screen with all the information needed, including light information. The problem with this approach is that it would limit the number of lights that could be processed to a low number, such as 4 or 8, a number that in the early 2000s would be enough.

The concept of Deferred Rendering, and more specifically, shading the same pixel only once, was already pioneered by Michael Deering and colleagues in a seminal paper called *The triangle processor and normal vector shader: a VLSI system for high performance graphics* in 1988, even though the term *deferred* was still not used.

Another key concept, the **G-buffer**, or **geometric buffer**, was pioneered by Takafumi Saito and Tokiichiro Takahashi in another pioneering paper, *Comprehensible Rendering of 3D Shapes*. In this paper, the authors cache depth and normals for each pixel to post-process the image – in this case, to add visual aids and comprehensibility to the image.

Although the first commercial game with a deferred renderer was *Shrek* in 2001 on the original Xbox, it became increasingly popular with the game *Stalker* and its accompanying paper, *Deferred Shading in Stalker* ([https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-9-deferred-shading-stalker](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-9-deferred-shading-stalker)), and exploded in popularity with the CryEngine presentation at Siggraph 2010 called *Reaching the Speed of **Light* ([http://advances.realtimerendering.com/s2010/Kaplanyan-CryEngine3%28SIGGRAPH%202010%20Advanced%20RealTime%20Rendering%20Course%29.pdf](http://advances.realtimerendering.com/s2010/Kaplanyan-CryEngine3%28SIGGRAPH%202010%20Advanced%20RealTime%20Rendering%20Course%29.pdf)).

In the late 2000s/early 2010s, Deferred Rendering was all the rage, and basically, all engines were implementing some variations of it.

Forward rendering made a comeback in 2012 when AMD launched a demo called *Leo* in which, thanks to the new *Compute Shaders* technology, they introduced the light list for each screen space tile and created *Forward+*.

The AMD Leo paper can be found here: [https://takahiroharada.files.wordpress.com/2015/04/forward_plus.pdf](https://takahiroharada.files.wordpress.com/2015/04/forward_plus.pdf).

A few weeks after that paper, the first commercial game to use Forward+ was *Dirt Showdown*, but only the PC version, as consoles still did not have support for APIs that would help in that area: [https://web.archive.org/web/20210621112015/https://www.rage3d.com/articles/gaming/codemaster_dirt_showdown_tech_review/](https://web.archive.org/web/20210621112015/https://www.rage3d.com/articles/gaming/codemaster_dirt_showdown_tech_review/).

With this, the Forward+ technology came back into usage, as the light limitations were gone, and it added a lot of algorithmic exploration in different areas (such as post-process anti-aliasing for a deferred depth prepass).

In the following years, more refined subdivision algorithms were developed, with tiles becoming clusters and moving from simple 2D screen space tiles to fully frustum-shaped 3D clusters.

This became famous with the *Just Cause 3* paper by Emil Persson, [https://www.humus.name/Articles/PracticalClusteredShading.pdf](https://www.humus.name/Articles/PracticalClusteredShading.pdf), and the concept was further enhanced by others for both deferred and forward rendering ([https://www.cse.chalmers.se/~uffe/clustered_shading_preprint.pdf](https://www.cse.chalmers.se/~uffe/clustered_shading_preprint.pdf)).

Clustering has been a great idea, but the memory consumption of having a 3D grid can be big, especially with the increasing rendering resolutions.

The current state of the art of clustering comes from Activision, which is our chosen solution, and we will see it in detail in the *Implementing light clusters* section of this chapter.

Now that we have provided a brief historical overview of real-time light rendering techniques, we are going to go into more depth about the differences between forward and Deferred Rendering in the next section.

## Differences between forward and deferred techniques


After talking about the history of forward and Deferred Rendering techniques, we want to highlight the key differences and talk about their common problem: **light assignment**.

The main advantages of forward rendering are as follows:

- Total freedom when rendering materials


- Same rendering path for opaque and transparent objects


- Support for **Multi Sampled ****Anti-Aliasing** (**MSAA**)


- Lower memory bandwidth within the GPU




The main disadvantages of forward rendering are as follows:

- A depth prepass could be necessary to reduce the number of fragments shaded. Without this preprocessing step, scenes that contain a large number of objects could waste a lot of processing time by shading fragments for objects that are not visible. For this reason, a pass that only writes to the depth buffer is executed at the beginning of a frame.




The **depth-test** function is then set to equal so that only the fragments for the visible objects will be shaded. Depending on the complexity of your scene, this pre-pass could be expensive, and in some cases, simplified geometry is used to reduce the cost of this pass at the expense of slightly less accurate results. You must also be careful and ensure that the Early-Z test is not disabled in the graphics pipeline.

This happens when writing to the depth buffer from a fragment shader or when a fragment shader contains a discard instruction.

- The complexity of shading a scene is the number of objects (*N*) multiplied by the number of lights (*L*). All the lights must be processed for each object as we don’t know in advance which lights affect a given fragment.


- Shaders become increasingly more complex, having to do a lot of operations and thus having a very high GPU register pressure (number of registers used), impacting performance.




Deferred Rendering (sometimes referred to as **deferred shading**) was introduced primarily to decouple the rendering of the geometry and the light computations. In Deferred Rendering, we create multiple render targets. Usually, we have a render target for albedo, normals, PBR parameters (roughness, metalness, and occlusion – see [*Chapter 2*](B18395_02.xhtml#_idTextAnchor030), *Improving Resources Management,* for more details), and depth.

Once these render targets have been created, for each fragment we process the lights in the scene. We still have the same problem as before, since we still don’t know which lights affect a given shader; however, our scene complexity has gone from *N x L* to *N + **L*.

The main advantages of deferred shading are as follows:

- Decreased shading complexity


- No need for a depth pre-pass


- Less complex shaders, as writing information on the G-buffer and processing lights are separate operations




However, there are some disadvantages to this approach, as follows:

- **High memory usage**: We listed three render targets that have to be stored in memory. With increasing resolutions of modern games, these start to add up, especially when more render targets are needed for other techniques – for example, motion vectors for **Temporal Anti-Aliasing** (**TAA**), which will be discussed in a later chapter. For this reason, developers tend to compress some of this data, which helps to reduce the amount of memory required by the G-buffer.


- **Loss of normals precision**: Normals are usually encoded as full floats (or possibly as 16-bit floats) as part of the geometry. To save memory when writing the normals render target, these values get compressed to 8 bits, significantly reducing the accuracy of these values.




To further reduce memory usage, developers take advantage of the fact that normals are normalized. This allows us to store only two values and reconstruct the third. There are other techniques that can be used to compress normals, which will be referenced in the *Further reading* section. We will explain in detail the one we use in the next section.

- Transparent objects need a separate pass and need to be shaded using a forward technique.


- Special materials need to have all their parameters packed into the G-buffer.




As you probably noticed, one problem is common to both techniques: we have to go through all the lights when processing an individual object or fragment. We are now going to describe the two most common techniques that are used to solve this issue: tiles and clusters.

### Light tiles


One approach to reducing the number of lights processed for a given fragment is to create a grid in screen space and determine which lights affect a given tile. When rendering the scene, we determine which tile the fragment we are shading belongs to and we iterate only over the lights that cover that tile.

The following figure shows the debug visualization for a light in the scene (the green sphere) and the screen area that it covers (in yellow). We will use this data to determine which tiles are affected by a given light.



 ![Figure 7.1 – The area covered by a point light in screen space](image/B8395_07_01.jpg)


Figure 7.1 – The area covered by a point light in screen space

Building the tiles can be done on the CPU or with a compute shader on the GPU. Tile data can be stored in a flat array; we will explain this data structure in more detail later in the chapter.

Traditional light tiles require a depth pre-pass to determine the minimum and maximum *Z* values. This approach can suffer from depth discontinuities; however, the final data structure is usually densely packed, meaning we are not wasting memory.

### Light clusters


Light clusters subdivide the frustum in a 3D grid. As for tiles, lights are assigned to each cell, and at render time, we only iterate over the lights that a given fragment belongs to.

The following figure illustrates the shape of the clusters for one of the camera axes. Each cluster is composed of a smaller frustum:



 ![Figure 7.2 – The frustum clusters covered by a point light](image/B8395_07_02.jpg)


Figure 7.2 – The frustum clusters covered by a point light

Lights can be stored in a 3D grid (a 3D texture, for instance) or more complex data structures – for example, a **Bounded Volume Hierarchy** (**BVH**) or octree.

To build light clusters, we don’t need a depth pre-pass. Most implementations build **Axis Aligned Bounding Boxes** (**AABBs**) for each light and project them into clip space. This approach allows easy 3D lookups and, depending on the amount of memory that can be allocated for the data structure, it’s possible to achieve quite accurate results.

In this section, we have highlighted the advantages and disadvantages of both forward and Deferred Rendering. We have introduced tiling and clustering techniques that can help reduce the number of lights that need to be processed for each fragment.

In the next section, we are going to provide an overview of our G-buffer implementation.

# Implementing a G-buffer


From the beginning of this project, we decided we would implement a deferred renderer. It’s one of the more common approaches, and some of the render targets will be needed in later chapters for other techniques:

- The first step in setting up multiple render targets in Vulkan is to create the framebuffers – the textures that will store the G-buffer data – and the render pass.




This step is automated, thanks to the frame graph (see [*Chapter 4*](B18395_04.xhtml#_idTextAnchor064)*, Implementing a Frame Graph*, for details); however, we want to highlight our use of a new Vulkan extension that simplifies render pass and framebuffer creation. The extension is **VK_KHR_dynamic_rendering**.

说明

This extension has become part of the core specification in Vulkan 1.3, so it’s possible to omit the **KHR** suffix on the data structures and API calls.

- With this extension, we don’t have to worry about creating the render pass and framebuffers ahead of time. We’ll start by analyzing the changes required when creating a pipeline:

```
VkPipelineRenderingCreateInfoKHR pipeline_rendering_create_info{
```

```
&#160;&#160;VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR };
```

```
pipeline_rendering_create_info.viewMask = 0;
```

```
pipeline_rendering_create_info.colorAttachmentCount =
```

```
&#160;&#160;&#160;&#160;creation.render_pass.num_color_formats;
```

```
pipeline_rendering_create_info.pColorAttachmentFormats
```

```
&#160;&#160;&#160;&#160;= creation.render_pass.num_color_formats > 0 ?
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;creation.render_pass.color_formats : nullptr;
```

```
pipeline_rendering_create_info.depthAttachmentFormat =
```

```
&#160;&#160;&#160;&#160;creation.render_pass.depth_stencil_format;
```

```
pipeline_rendering_create_info.stencilAttachmentFormat
```

```
&#160;&#160;&#160;&#160;= VK_FORMAT_UNDEFINED;
```

```
pipeline_info.pNext = &pipeline_rendering_create_info;
```




We have to populate a **VkPipelineRenderingCreateInfoKHR** structure with the number of attachments we are going to use and their format. We also need to specify the depth and stencil formats, if used.

Once this structure has been filled, we chain it to the **VkGraphicsPipelineCreateInfo** structure. When using this extension we don’t populate the **VkGraphicsPipelineCreateInfo::renderPass** member.

- At render time, instead of calling **vkCmdBeginRenderPass**, we call a new API, **vkCmdBeginRenderingKHR**. We start by creating an array to hold our **attachments** details:

```
Array<VkRenderingAttachmentInfoKHR> color_attachments_info;
```

```
color_attachments_info.init( device->allocator,
```

```
&#160;&#160;&#160;&#160;framebuffer->num_color_attachments,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;framebuffer->num_color_attachments );
```


- Next, we populate each entry with the details of each attachment:

```
for ( u32 a = 0; a < framebuffer->
```

```
&#160;&#160;&#160;&#160;num_color_attachments; ++a ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;Texture* texture = device->
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;access_texture( framebuffer->
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;color_attachments[a] );
```

```
&#160;&#160;&#160;&#160;VkAttachmentLoadOp color_op = ...;
```

```
VkRenderingAttachmentInfoKHR&
```

```
color_attachment_info = color_attachments_info[ a ];
```

```
color_attachment_info.sType =
```

```
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR;
```

```
color_attachment_info.imageView = texture->
```

```
&#160;&#160;&#160;&#160;vk_image_view;
```

```
color_attachment_info.imageLayout =
```

```
&#160;&#160;&#160;&#160;VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
```

```
color_attachment_info.resolveMode =
```

```
&#160;&#160;&#160;&#160;VK_RESOLVE_MODE_NONE;
```

```
color_attachment_info.loadOp = color_op;
```

```
color_attachment_info.storeOp =
```

```
&#160;&#160;&#160;&#160;VK_ATTACHMENT_STORE_OP_STORE;
```

```
color_attachment_info.clearValue = render_pass->
```

```
&#160;&#160;&#160;&#160;output.color_operations[ a ] ==
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;RenderPassOperation::Enum::Clear ? clears[ 0 ]
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;: VkClearValue{ };
```

```
}
```


- We have to fill a similar data structure for the **depth** attachment:

```
VkRenderingAttachmentInfoKHR depth_attachment_info{
```

```
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR };
```

```
bool has_depth_attachment = framebuffer->
```

```
&#160;&#160;&#160;&#160;depth_stencil_attachment.index != k_invalid_index;
```

```
if ( has_depth_attachment ) {
```

```
&#160;&#160;&#160;&#160;Texture* texture = device->access_texture(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;framebuffer->depth_stencil_attachment );
```

```
&#160;&#160;&#160;&#160;VkAttachmentLoadOp depth_op = ...;
```

```
depth_attachment_info.imageView = texture->
```

```
&#160;&#160;&#160;&#160;vk_image_view;
```

```
depth_attachment_info.imageLayout =
```

```
&#160;&#160;&#160;&#160;VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
```

```
depth_attachment_info.resolveMode =
```

```
&#160;&#160;&#160;&#160;VK_RESOLVE_MODE_NONE;
```

```
depth_attachment_info.loadOp = depth_op;
```

```
depth_attachment_info.storeOp =
```

```
&#160;&#160;&#160;&#160;VK_ATTACHMENT_STORE_OP_STORE;
```

```
depth_attachment_info.clearValue = render_pass->
```

```
&#160;&#160;&#160;&#160;output.depth_operation ==
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;RenderPassOperation::Enum::Clear ? clears[ 1 ]
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;: VkClearValue{ };
```

```
}
```


- Finally, we fill the **VkRenderingInfoKHR** structure that will be passed to **vkCmdBeginRenderingKHR**:

```
VkRenderingInfoKHR rendering_info{
```

```
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_RENDERING_INFO_KHR };
```

```
rendering_info.flags = use_secondary ?
```

```
&#160;&#160;&#160;&#160;VK_RENDERING_CONTENTS_SECONDARY_COMMAND
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_BUFFERS_BIT_KHR : 0;
```

```
rendering_info.renderArea = { 0, 0, framebuffer->
```

```
&#160;&#160;&#160;&#160;width, framebuffer->height };
```

```
rendering_info.layerCount = 1;
```

```
rendering_info.viewMask = 0;
```

```
rendering_info.colorAttachmentCount = framebuffer->
```

```
&#160;&#160;&#160;&#160;num_color_attachments;
```

```
rendering_info.pColorAttachments = framebuffer->
```

```
&#160;&#160;&#160;&#160;num_color_attachments > 0 ?
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;color_attachments_info.data : nullptr;
```

```
rendering_info.pDepthAttachment =
```

```
&#160;&#160;&#160;&#160;has_depth_attachment ? &depth_attachment_info :
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nullptr;
```

```
rendering_info.pStencilAttachment = nullptr;
```




Once we are done rendering, we are going to call **vkCmdEndRenderingKHR** instead of **vkCmdEndRenderPass**.

Now that we have set up our render targets, we are going to describe how they are used in our G-buffer shader. Our G-buffer has four render targets plus the depth buffer. As we mentioned in the previous section, there is no need for a depth pre-pass, although you might notice this was enabled in some of the earlier chapters for testing purposes.

The first step is to declare multiple outputs in the fragment shader:

```
layout (location = 0) out vec4 color_out;
layout (location = 1) out vec2 normal_out;
layout (location = 2) out vec4
&#160;&#160;&#160;&#160;occlusion_roughness_metalness_out;
layout (location = 3) out vec4 emissive_out;
```


The location index must correspond to the order in which the attachments have been specified when calling **vkCmdBeginRenderingKHR** (or when creating the render pass and framebuffer objects). Writing to a given render target is done simply by writing to one of the variables we just declared:

```
colour_out = texture(global_textures[nonuniformEXT
&#160;&#160;&#160;&#160;(albedo_texture)], uv);
```


As we mentioned in the previous section, we must be conscious of memory usage. As you might have noticed, we only store two channels for normals. We use an octahedral encoding that allows storing only two values. We can reconstruct the full normal in the lighting pass.

Here’s the encoding function:

```
vec2 octahedral_encode(vec3 n) {
&#160;&#160;&#160;&#160;// Project the sphere onto the octahedron, and then
&#160;&#160;&#160;&#160;&#160;&#160;&#160;onto the xy plane
&#160;&#160;&#160;&#160;vec2 p = n.xy * (1.0f / (abs(n.x) + abs(n.y) +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;abs(n.z)));
&#160;&#160;&#160;&#160;// Reflect the folds of the lower hemisphere over the
&#160;&#160;&#160;&#160;&#160;&#160;&#160;diagonals
&#160;&#160;&#160;&#160;return (n.z < 0.0f) ? ((1.0 - abs(p.yx)) *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sign_not_zero(p)) : p;
}
```


And here is the decoding function:

```
vec3 octahedral_decode(vec2 f) {
&#160;&#160;&#160;&#160;vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
&#160;&#160;&#160;&#160;float t = max(-n.z, 0.0);
&#160;&#160;&#160;&#160;n.x += n.x >= 0.0 ? -t : t;
&#160;&#160;&#160;&#160;n.y += n.y >= 0.0 ? -t : t;
&#160;&#160;&#160;&#160;return normalize(n);
}
```


The following table illustrates the data arrangement of our G-buffer pass:



 ![Table 7.1 – G-buffer memory layout](image/B18395_07_Table_01.jpg)


Table 7.1 – G-buffer memory layout

Here are the screenshots for our render targets:



 ![Figure 7.3 – From top to bottom: albedo, normals, and combined occlusion (red), roughness (green), and metalness (blue)](image/B8395_07_03.jpg)


Figure 7.3 – From top to bottom: albedo, normals, and combined occlusion (red), roughness (green), and metalness (blue)

We could probably reduce the number of render targets further: we know that in the G-buffer pass, we are only shading opaque objects, so we don’t need the alpha channel. Also, nothing prevents us from mixing data for different render targets – for instance, we could have something like the following:

- **RGBA8**: **r**, **g**, **b**, and **normal_1**


- **RGBA8**: **normal_2**, **roughness**, **metalness**, and **occlusion**


- **RGBA8**: **emissive**




We can also try to use different texture formats (**R11G11B10**, for example) to increase the accuracy of our data. We encourage you to experiment with different solutions and find the one that works best for your use case!

In this section, we have introduced a new Vulkan extension that simplifies the creation and use of the render pass and framebuffer. We also provided details on the implementation of our G-buffer and highlighted potential optimizations. In the next section, we are going to look at the light clustering solution that we have implemented.

# Implementing light clusters


In this section, we are going to describe our implementation of the light clustering algorithm. It’s based on this presentation: [https://www.activision.com/cdn/research/2017_Sig_Improved_Culling_final.pdf](https://www.activision.com/cdn/research/2017_Sig_Improved_Culling_final.pdf). The main (and very smart) idea is to separate the *XY* plane from the *Z* range, combining the advantages of both tiling and clustering approaches. The algorithms are organized as follows:

- We sort the lights by their depth value in camera space.


- We then divide the depth range into bins of equal size, although a logarithmic subdivision might work better depending on your depth range.


- Next, we assign the lights to each bin if their bounding box falls within the bin range. We only store the minimum and maximum light index for a given bin, so we only need 16 bits for each bin, unless you need more than 65,535 lights!


- We then divide the screen into tiles (8x8 pixels, in our case) and determine which lights cover a given tile. Each tile will store a bitfield representation for the active lights.


- Given a fragment that we want to shade, we determine the depth of the fragment and read the bin index.


- Finally, we iterate from the minimum to the maximum light index in that bin and read the corresponding tile to see whether the light is visible, this time using *x* and *y* coordinates to retrieve the tile.




This solution provides a very efficient way to loop through the active lights for a given fragment.

## CPU lights assignment


We’ll now look at the implementation. During each frame, we perform the following steps:

- We start by sorting the lights by their depth value:

```
float z_far = 100.0f;
```

```
for ( u32 i = 0; i < k_num_lights; ++i ) {
```

```
&#160;&#160;&#160;&#160;Light& light = lights[ i ];
```

```
&#160;&#160;&#160;&#160;vec4s p{ light.world_position.x,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.world_position.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.world_position.z, 1.0f };
```

```
&#160;&#160;&#160;&#160;vec3s p_min = glms_vec3_add( light.world_position,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;glms_vec3_scale(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_camera_dir,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;-light.radius ) );
```

```
&#160;&#160;&#160;&#160;vec3s p_max = glms_vec3_add( light.world_position,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;glms_vec3_scale(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_camera_dir,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.radius ) );
```

```
&#160;&#160;&#160;&#160;vec4s projected_p = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_to_camera, p );
```

```
&#160;&#160;&#160;&#160;vec4s projected_p_min = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_to_camera, p_min4 );
```

```
&#160;&#160;&#160;&#160;vec4s projected_p_max = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_to_camera, p_max4 );
```

```
&#160;&#160;&#160;SortedLight& sorted_light = sorted_lights[ i ];
```

```
&#160;&#160;&#160;&#160;sorted_light.light_index = i;
```

```
&#160;&#160;&#160;&#160;sorted_light.projected_z = ( -projected_p.z –
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scene_data.z_near ) / ( z_far –
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scene_data.z_near );
```

```
&#160;&#160;&#160;&#160;sorted_light.projected_z_min = ( -
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;projected_p_min.z - scene_data.z_near ) / (
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;z_far - scene_data.z_near );
```

```
&#160;&#160;&#160;&#160;sorted_light.projected_z_max = ( -
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;projected_p_max.z - scene_data.z_near ) / (
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;z_far - scene_data.z_near );
```

```
}
```




We compute the minimum and maximum point of the light sphere from the camera’s point of view. Notice that we use a closer **far** depth plane to gain precision in the depth range.

- To avoid having to sort the light list, we only sort the light indices:

```
qsort( sorted_lights.data, k_num_lights, sizeof(
```

```
&#160;&#160;&#160;&#160;SortedLight ), sorting_light_fn );
```

```
u32* gpu_light_indices = ( u32* )gpu.map_buffer(
```

```
&#160;&#160;&#160;&#160;cb_map );
```

```
if ( gpu_light_indices ) {
```

```
&#160;&#160;&#160;&#160;for ( u32 i = 0; i < k_num_lights; ++i ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gpu_light_indices[ i ] = sorted_lights[ i ]
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.light_index;
```

```
&#160;&#160;&#160;&#160;}
```

```
&#160;&#160;&#160;&#160;gpu.unmap_buffer( cb_map );
```

```
}
```




This optimization allows us to upload the light array only once, while we only need to update the light indices.

- Next, we proceed with the tile assignment. We start by defining our bitfield array and some helper variables that will be used to compute the index within the array:

```
Array<u32> light_tiles_bits;
```

```
light_tiles_bits.init( context.scratch_allocator,
```

```
&#160;&#160;&#160;&#160;tiles_entry_count, tiles_entry_count );
```

```
float near_z = scene_data.z_near;
```

```
float tile_size_inv = 1.0f / k_tile_size;
```

```
u32 tile_stride = tile_x_count * k_num_words;
```


- We then transform the light position in camera space:

```
for ( u32 i = 0; i < k_num_lights; ++i ) {
```

```
&#160;&#160;&#160;&#160;const u32 light_index = sorted_lights[ i ]
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.light_index;
```

```
&#160;&#160;&#160;&#160;Light& light = lights[ light_index ];
```

```
&#160;&#160;&#160;&#160;vec4s pos{ light.world_position.x,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.world_position.y,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light.world_position.z, 1.0f };
```

```
&#160;&#160;&#160;&#160;float radius = light.radius;
```

```
&#160;&#160;&#160;&#160;vec4s view_space_pos = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;game_camera.camera.view, pos );
```

```
&#160;&#160;&#160;&#160;bool camera_visible = view_space_pos.z - radius <
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;game_camera.camera.near_plane;
```

```
&#160;&#160;&#160;&#160;if ( !camera_visible &&
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;context.skip_invisible_lights ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;continue;
```

```
&#160;&#160;&#160;&#160;}
```




If the light is behind the camera, we don’t do any further processing.

- Next, we compute the corners of the AABB projected to clip space:

```
for ( u32 c = 0; c < 8; ++c ) {
```

```
&#160;&#160;&#160;&#160;vec3s corner{ ( c % 2 ) ? 1.f : -1.f, ( c & 2 ) ?
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1.f : -1.f, ( c & 4 ) ? 1.f : -1.f };
```

```
&#160;&#160;&#160;&#160;corner = glms_vec3_scale( corner, radius );
```

```
&#160;&#160;&#160;&#160;corner = glms_vec3_add( corner, glms_vec3( pos ) );
```

```
&#160;&#160;&#160;&#160;vec4s corner_vs = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;game_camera.camera.view,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;glms_vec4( corner, 1.f ) );
```

```
&#160;&#160;&#160;&#160;corner_vs.z = -glm_max(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;game_camera.camera.near_plane, -corner_vs.z );
```

```
&#160;&#160;&#160;&#160;vec4s corner_ndc = glms_mat4_mulv(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;game_camera.camera.projection, corner_vs );
```

```
&#160;&#160;&#160;&#160;corner_ndc = glms_vec4_divs( corner_ndc,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;corner_ndc.w );
```

```
&#160;&#160;&#160;&#160;aabb_min.x = glm_min( aabb_min.x, corner_ndc.x );
```

```
&#160;&#160;&#160;&#160;aabb_min.y = glm_min( aabb_min.y, corner_ndc.y );
```

```
&#160;&#160;&#160;&#160;aabb_max.x = glm_max( aabb_max.x, corner_ndc.x );
```

```
&#160;&#160;&#160;&#160;aabb_max.y = glm_max( aabb_max.y, corner_ndc.y );
```

```
}
```

```
aabb.x = aabb_min.x;
```

```
aabb.z = aabb_max.x;
```

```
aabb.w = -1 * aabb_min.y;
```

```
aabb.y = -1 * aabb_max.y;
```


- We then proceed to determine the size of the quad in screen space:

```
vec4s aabb_screen{ ( aabb.x * 0.5f + 0.5f ) * (
```

```
&#160;&#160;&#160;&#160;gpu.swapchain_width - 1 ),
```

```
&#160;&#160;&#160;&#160;( aabb.y * 0.5f + 0.5f ) * (
```

```
&#160;&#160;&#160;&#160;gpu.swapchain_height - 1 ),
```

```
&#160;&#160;&#160;&#160;( aabb.z * 0.5f + 0.5f ) * (
```

```
&#160;&#160;&#160;&#160;gpu.swapchain_width - 1 ),
```

```
&#160;&#160;&#160;&#160;( aabb.w * 0.5f + 0.5f ) *
```

```
&#160;&#160;&#160;&#160;( gpu.swapchain_height - 1 ) };
```

```
f32 width = aabb_screen.z - aabb_screen.x;
```

```
f32 height = aabb_screen.w - aabb_screen.y;
```

```
if ( width < 0.0001f || height < 0.0001f ) {
```

```
&#160;&#160;&#160;&#160;continue;
```

```
}
```

```
float min_x = aabb_screen.x;
```

```
float min_y = aabb_screen.y;
```

```
float max_x = min_x + width;
```

```
float max_y = min_y + height;
```

```
if ( min_x > gpu.swapchain_width || min_y >
```

```
&#160;&#160;&#160;&#160;gpu.swapchain_height ) {
```

```
&#160;&#160;&#160;&#160;continue;
```

```
}
```

```
if ( max_x < 0.0f || max_y < 0.0f ) {
```

```
&#160;&#160;&#160;&#160;continue;
```

```
}
```




If the light is not visible on the screen, we move to the next light.

- The final step is to set the bit for the light we are processing on all the tiles it covers:

```
min_x = max( min_x, 0.0f );
```

```
min_y = max( min_y, 0.0f );
```

```
max_x = min( max_x, ( float )gpu.swapchain_width );
```

```
max_y = min( max_y, ( float )gpu.swapchain_height );
```

```
u32 first_tile_x = ( u32 )( min_x * tile_size_inv );
```

```
u32 last_tile_x = min( tile_x_count - 1, ( u32 )(
```

```
&#160;&#160;&#160;&#160;max_x * tile_size_inv ) );
```

```
u32 first_tile_y = ( u32 )( min_y * tile_size_inv );
```

```
u32 last_tile_y = min( tile_y_count - 1, ( u32 )(
```

```
&#160;&#160;&#160;&#160;max_y * tile_size_inv ) );
```

```
for ( u32 y = first_tile_y; y <= last_tile_y; ++y ) {
```

```
&#160;&#160;&#160;&#160;for ( u32 x = first_tile_x; x <= last_tile_x; ++x
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;u32 array_index = y * tile_stride + x;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;u32 word_index = i / 32;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;u32 bit_index = i % 32;
```

```
&#160;&#160;&#160;&#160;light_tiles_bits[ array_index + word_index ] |= (
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1 << bit_index );
```

```
&#160;&#160;&#160;&#160;}
```

```
}
```




We then upload all the light tiles and bin data to the GPU.

At the end of this computation, we will have a bin table containing the minimum and maximum light ID for each depth slice. The following table illustrates an example of the values for the first few slices:



 ![Table 7.2 – Example of the data contained in the depth bins](image/B18395_07_Table_02.jpg)


Table 7.2 – Example of the data contained in the depth bins

The other data structure we computed is a 2D array, where each entry contains a bitfield tracking the active lights for the corresponding screen tile. The following table presents an example of the content of this array:



 ![Table 7.3 – Example of the bitfield values tracking the active lights per tile](image/B18395_07_Table_03.jpg)


Table 7.3 – Example of the bitfield values tracking the active lights per tile

In the preceding example, we have divided the screen into a 4x4 grid, and each tile entry has a bit set for every light that covers that tile. Note that each tile entry can be composed of multiple 32-bit values depending on the number of lights in the scene.

In this section, we provided an overview of the algorithm we have implemented to assign lights to a given cluster. We then detailed the steps to implement the algorithm. In the next section, we are going to use the data we have just obtained to process lights on the GPU.

## GPU light processing


Now that we have all the data we need on the GPU, we can use it in our lighting computation:

- We start by determining which depth bin our fragment belongs to:

```
vec4 pos_camera_space = world_to_camera * vec4(
```

```
&#160;&#160;&#160;&#160;world_position, 1.0 );
```

```
float z_light_far = 100.0f;
```

```
float linear_d = ( -pos_camera_space.z - z_near ) / (
```

```
&#160;&#160;&#160;&#160;z_light_far - z_near );
```

```
int bin_index = int( linear_d / BIN_WIDTH );
```

```
uint bin_value = bins[ bin_index ];
```

```
uint min_light_id = bin_value & 0xFFFF;
```

```
uint max_light_id = ( bin_value >> 16 ) & 0xFFFF;
```


- We extract the minimum and maximum light index, as they are going to be used in the light computation loop:

```
uvec2 position = gl_GlobalInvocationID.xy;
```

```
uvec2 tile = position / uint( TILE_SIZE );
```

```
uint stride = uint( NUM_WORDS ) *
```

```
&#160;&#160;&#160;&#160;( uint( resolution.x ) / uint( TILE_SIZE ) );
```

```
uint address = tile.y * stride + tile.x;
```


- We first determine the address in the tile bitfield array. Next, we check whether there are any lights in this depth bin:

```
if ( max_light_id != 0 ) {
```

```
&#160;&#160;&#160;&#160;min_light_id -= 1;
```

```
&#160;&#160;&#160;&#160;max_light_id -= 1;
```


- If **max_light_id** is **0**, it means we didn’t store any lights in this bin, so no lights will affect this fragment. Next, we loop over the lights for this depth bin:

```
&#160;&#160;&#160;&#160;for ( uint light_id = min_light_id; light_id <=
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max_light_id; ++light_id ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint word_id = light_id / 32;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint bit_id = light_id % 32;
```


- After we compute the word and bit index, we determine which lights from the depth bin also cover the screen tile:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( ( tiles[ address + word_id ] &
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;( 1 << bit_id ) ) != 0 ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint global_light_index =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_indices[ light_id ];
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;Light point_light = lights[
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;global_light_index ];
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;final_color.rgb +=
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;calculate_point_light_contribution
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;( albedo, orm, normal, emissive,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_position, V, F0, NoV,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;point_light );
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
```

```
&#160;&#160;&#160;&#160;}
```

```
}
```




This concludes our light clustering algorithm. The shader code also contains an optimized version that makes use of the subgroup instructions to improve register utilization. There are plenty of comments to explain how it works.

We covered a fair amount of code in this section, so don’t worry if some things were not clear on the first read. We started by describing the steps of the algorithm. We then explained how the lights are sorted in depth bins and how we determine the lights that cover a given tile on the screen. Finally, we showed how these data structures are used in the lighting shader to determine which lights affect a given fragment.

Note that this technique can be used both in forward and Deferred Rendering. Now that we have a performant lighting solution, one element is sorely missing from our scene: shadows! This will be the topic for the next chapter.

# 小结
In this chapter, we have implemented a light clustering solution. We started by explaining forward and Deferred Rendering techniques and their main advantages and shortcomings. Next, we described two approaches to group lights to reduce the computation needed to shade a single fragment.

We then outlined our G-buffer implementation by listing the render targets that we use. We detailed our use of the **VK_KHR_dynamic_rendering** extension, which allows us to simplify the render pass and framebuffer use. We also highlighted the relevant code in the G-buffer shader to write to multiple render targets, and we provided the implementation for our normal encoding and decoding. In closing, we suggested some optimizations to further reduce the memory used by our G-buffer implementation.

In the last section, we described the algorithm we selected to implement light clustering. We started by sorting the lights by their depth value into depth bins. We then proceeded to store the lights that affect a given screen tile using a bitfield array. Finally, we made use of these two data structures in our lighting shader to reduce the number of lights that need to be evaluated for each fragment.

Optimizing the lighting stage of any game or application is paramount to maintaining interactive frame rates. We described one possible solution, but other options are available, and we suggest you experiment with them to find the one that best suits your use case!

Now that we have added many lights, the scene still looks flat as there&apos;s one important element missing: shadows. That&apos;s the topic for the next chapter!

# 延伸阅读
- Some history about the first Deferred Rendering in the *Shrek* game, 2001: [https://sites.google.com/site/richgel99/the-early-history-of-deferred-shading-and-lighting](https://sites.google.com/site/richgel99/the-early-history-of-deferred-shading-and-lighting)


- Stalker Deferred Rendering paper: [https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-9-deferred-shading-stalker](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-9-deferred-shading-stalker)


- This is one of the first papers that introduced the concept of clustered shading: [http://www.cse.chalmers.se/~uffe/clustered_shading_preprint.pdf](http://www.cse.chalmers.se/~uffe/clustered_shading_preprint.pdf)


- These two presentations are often cited as the inspiration for many implementations:
[https://www.activision.com/cdn/research/2017_Sig_Improved_Culling_final.pdf](https://www.activision.com/cdn/research/2017_Sig_Improved_Culling_final.pdf)

- [http://www.humus.name/Articles/PracticalClusteredShading.pdf](http://www.humus.name/Articles/PracticalClusteredShading.pdf)


- In this chapter, we only covered point lights, but in practice, many other types of lights are used (spotlights, area lights, polygonal lights, and a few others). This article describes a way to determine the visibility of a spotlight approximated by a cone:
[https://bartwronski.com/2017/04/13/cull-that-cone/](https://bartwronski.com/2017/04/13/cull-that-cone/)


- These presentations describe variants of the clustering techniques we described in this chapter:
[https://www.intel.com/content/dam/develop/external/us/en/documents/lauritzen-deferred-shading-siggraph-2010-181241.pdf](https://www.intel.com/content/dam/develop/external/us/en/documents/lauritzen-deferred-shading-siggraph-2010-181241.pdf)

- [https://advances.realtimerendering.com/s2016/Siggraph2016_idTech6.pdf](https://advances.realtimerendering.com/s2016/Siggraph2016_idTech6.pdf)

- [https://www.ea.com/frostbite/news/parallel-graphics-in-frostbite-current-future](https://www.ea.com/frostbite/news/parallel-graphics-in-frostbite-current-future)