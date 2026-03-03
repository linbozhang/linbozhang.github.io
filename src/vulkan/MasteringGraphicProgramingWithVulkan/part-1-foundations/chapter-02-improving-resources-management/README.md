# Chapter 2: Improving Resources Management

# 2



# Improving Resources Management


In this chapter, we are going to improve resource management to make it easier to deal with materials that might have a varying number of textures. This technique is usually referred to as bindless, even though it’s not entirely accurate. We are still going to bind a list of resources; however, we can access them by using an index rather than having to specify exactly which resources are going to be used during a particular draw.

The second improvement we are going to make is automating the generation of pipeline layouts. Large projects have hundreds or thousands of shaders, compiled with many different variations depending on the combinations of materials used by a particular application. If developers had to manually update their pipeline layout definitions every time a change is made, very few applications would make it to market. The implementation presented in this chapter relies on the information provided by the SPIR-V binary format.

Finally, we are going to add pipeline caching to our GPU device implementation. This solution improves the creation time of pipeline objects after the first run, and can significantly improve an application’s loading times.

In summary, in this chapter, we’re going to cover the following main topics:

- Unlocking and implementing bindless resources


- Automating pipeline layout generation


- Improving load times with a pipeline cache




学完本章后，你将understand how to enable and use bindless resources in Vulkan. You will also be able to parse SPIR-V binary data to automatically generate pipeline layouts. Finally, you will be able to speed up the loading time of your application by using pipeline caching.

# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter2](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter2).

# Unlocking and implementing bindless rendering


In the previous chapter, we had to manually bind the textures for each material. This also meant that if we wanted to support different types of materials requiring a different number of textures, we would have needed separate shaders and pipelines.

Vulkan provides a mechanism to bind an array of textures that can be used across multiple shaders. Each texture can then be accessed through an index. In the following sections, we are going to highlight the changes we have made to the GPU device implementation to enable this feature and describe how to use it.

在以下各节中，我们将first check that the extensions required to enable bindless resources are available on a given GPU. Then we will show the changes required to the descriptor pool creation and descriptor set update to make use of bindless resources. The last step will be to update our shaders to use indices in our texture array for rendering.

## Checking for support


Most desktop GPUs, even if relatively old, should support the **VK_EXT_descriptor_indexing** extension, provided you have up-to-date drivers. It’s still good practice to verify that the extension is available and, for a production implementation, provide an alternative code path that uses the standard binding model if the extension is not available.

To verify that your device supports this extension, you can use the following code, or you can run the **vulkaninfo** application provided by the Vulkan SDK. See [*Chapter 1*](B18395_01.xhtml#_idTextAnchor016), *Introducing the Raptor Engine and Hydra*, for how to install the SDK.

The first step then is to query the physical device to determine whether the GPU supports this extension. The following code section accomplishes this:

```
VkPhysicalDeviceDescriptorIndexingFeatures indexing
_features{ VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_INDEXING_FEATURES, nullptr };
&#160;&#160;&#160;&#160;VkPhysicalDeviceFeatures2 device_features{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&indexing_features };
&#160;&#160;&#160;&#160;vkGetPhysicalDeviceFeatures2( vulkan_physical_device,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&device_features );
&#160;&#160;&#160;&#160;bindless_supported = indexing_features.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;descriptorBindingPartiallyBound &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;indexing_features.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;runtimeDescriptorArray;
```


We have to populate the **VkPhysicalDeviceDescriptorIndexingFeatures** structure and chain it to the **VkPhysicalDeviceFeatures2** structure. The driver will then populate the **indexing_features** variable members when calling **vkGetPhysicalDeviceFeatures2**. To check that the descriptor indexing extension is supported, we verify that the **descriptorBindingPartiallyBound** and **runtimeDescriptorArray** values are **true**.

Once we have confirmed that the extension is supported, we can enable it when creating the device:

```
VkPhysicalDeviceFeatures2 physical_features2 = {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 };
vkGetPhysicalDeviceFeatures2( vulkan_physical_device,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&physical_features2 );
VkDeviceCreateInfo device_create_info = {};
// same code as chapter 1
device_create_info.pNext = &physical_features2;
if ( bindless_supported ) {
&#160;&#160;&#160;&#160;physical_features2.pNext = &indexing_features;
}
vkCreateDevice( vulkan_physical_device,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&device_create_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&vulkan_device );
```


We have to chain the **indexing_features** variable to the **physical_features2** variable used when creating our device. The rest of the code is unchanged from [*Chapter 1*](B18395_01.xhtml#_idTextAnchor016), *Introducing the Raptor Engine **and Hydra*.

## Creating the descriptor pool


The next step is to create a descriptor pool from which we can allocate descriptor sets that support updating the content of a texture after it is bound:

```
VkDescriptorPoolSize pool_sizes_bindless[] =
{
&#160;&#160;&#160;&#160;{ VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
&#160;&#160;&#160;&#160;&#160;&#160;k_max_bindless_resources },
&#160;&#160;&#160;&#160;&#160;&#160;{ VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
&#160;&#160;&#160;&#160;&#160;&#160;k_max_bindless_resources },
};
pool_info.flags = VK_DESCRIPTOR_POOL_CREATE_UPDATE
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_AFTER_BIND_BIT_EXT;
pool_info.maxSets = k_max_bindless_resources * ArraySize(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pool_sizes_bindless );
pool_info.poolSizeCount = ( u32 )ArraySize(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pool_sizes_bindless );
pool_info.pPoolSizes = pool_sizes_bindless;
vkCreateDescriptorPool( vulkan_device, &pool_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&vulkan_bindless_descriptor_pool);
```


The main difference with the code from [*Chapter 1*](B18395_01.xhtml#_idTextAnchor016), *Introducing the Raptor Engine and Hydra*, is the addition of the **VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT_EXT** flag. This flag is needed to allow the creation of descriptor sets that can be updated after they have been bound.

Next, we have to define the descriptor set layout bindings:

```
const u32 pool_count = ( u32 )ArraySize(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pool_sizes_bindless );
VkDescriptorSetLayoutBinding vk_binding[ 4 ];
VkDescriptorSetLayoutBinding& image_sampler_binding =
&#160;&#160;&#160;&#160;vk_binding[ 0 ];
image_sampler_binding.descriptorType = VK_DESCRIPTOR
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_TYPE_COMBINED
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_IMAGE_SAMPLER;
image_sampler_binding.descriptorCount =
&#160;&#160;&#160;&#160;k_max_bindless_resources;
image_sampler_binding.binding = k_bindless_texture_binding;
VkDescriptorSetLayoutBinding& storage_image_binding =
&#160;&#160;&#160;&#160;vk_binding[ 1 ];
storage_image_binding.descriptorType = VK_DESCRIPTOR
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_TYPE_STORAGE_IMAGE;
storage_image_binding.descriptorCount =
&#160;&#160;&#160;&#160;k_max_bindless_resources;
storage_image_binding.binding = k_bindless_texture_binding
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;+ 1;
```


Notice that **descriptorCount** no longer has a value of **1** but has to accommodate the maximum number of textures we can use. We can now use this data to create a descriptor set layout:

```
VkDescriptorSetLayoutCreateInfo layout_info = {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO };
layout_info.bindingCount = pool_count;
layout_info.pBindings = vk_binding;
layout_info.flags = VK_DESCRIPTOR_SET_LAYOUT_CREATE
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_UPDATE_AFTER_BIND_POOL_BIT_EXT;
VkDescriptorBindingFlags bindless_flags =
&#160;&#160;&#160;&#160;VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT_EXT |
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT_EXT;
VkDescriptorBindingFlags binding_flags[ 4 ];
binding_flags[ 0 ] = bindless_flags;
binding_flags[ 1 ] = bindless_flags;
VkDescriptorSetLayoutBindingFlagsCreateInfoEXT
extended_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_BINDING_FLAGS_CREATE_INFO_EXT, nullptr };
extended_info.bindingCount = pool_count;
extended_info.pBindingFlags = binding_flags;
layout_info.pNext = &extended_info;
vkCreateDescriptorSetLayout( vulkan_device, &layout_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&vulkan_bindless
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_descriptor_layout );
```


The code is very similar to the version seen in the previous chapter; however, we have added the **bindless_flags** values to enable partial updates to the descriptor set. We also have to chain a **VkDescriptorSetLayoutBindingFlagsCreateInfoEXT** structure to the **layout_info** variable. Finally, we can create the descriptor set we are going to use for the lifetime of the application:

```
VkDescriptorSetAllocateInfo alloc_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO };
alloc_info.descriptorPool = vulkan_bindless
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_descriptor_pool;
alloc_info.descriptorSetCount = 1;
alloc_info.pSetLayouts = &vulkan_bindless_descriptor
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_layout;
vkAllocateDescriptorSets( vulkan_device, &alloc_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&vulkan_bindless_descriptor_set
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
```


We simply populate the **VkDescriptorSetAllocateInfo** structure with the values we have defined so far and call **vkAllocateDescriptorSets**.

## Updating the descriptor set


We have done most of the heavy lifting at this point. When we call **GpuDevice::create_texture**, the newly created resource gets added to the **texture_to_update_bindless** array:

```
if ( gpu.bindless_supported ) {
&#160;&#160;&#160;&#160;ResourceUpdate resource_update{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ResourceDeletionType::Texture,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->handle.index, gpu.current_frame };
&#160;&#160;&#160;&#160;gpu.texture_to_update_bindless.push( resource_update );
}
```


It’s also possible to associate a specific sampler to a given texture. For instance, when we load a texture for a given material, we add the following code:

```
gpu.link_texture_sampler( diffuse_texture_gpu.handle,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;diffuse_sampler_gpu.handle );
```


This links the diffuse texture with its sampler. This information will be used in the next code section to determine whether we use a default sampler or the one we have just assigned to the texture.

Before the next frame is processed, we update the descriptor set we have created in the previous section with any new textures that have been uploaded:

```
for ( i32 it = texture_to_update_bindless.size - 1;
&#160;&#160;it >= 0; it-- ) {
&#160;&#160;&#160;&#160;ResourceUpdate& texture_to_update =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture_to_update_bindless[ it ];
&#160;&#160;&#160;Texture* texture = access_texture( {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture_to_update.handle } );
&#160;&#160;&#160;&#160;VkWriteDescriptorSet& descriptor_write =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;bindless_descriptor_writes[ current_write_index ];
&#160;&#160;&#160;&#160;descriptor_write = {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET };
&#160;&#160;&#160;&#160;descriptor_write.descriptorCount = 1;
&#160;&#160;&#160;&#160;descriptor_write.dstArrayElement =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture_to_update.handle;
&#160;&#160;&#160;&#160;descriptor_write.descriptorType =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
&#160;&#160;&#160;&#160;descriptor_write.dstSet =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_bindless_descriptor_set;
&#160;&#160;&#160;&#160;descriptor_write.dstBinding =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;k_bindless_texture_binding;
&#160;&#160;&#160;&#160;Sampler* vk_default_sampler = access_sampler(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;default_sampler );
&#160;&#160;&#160;&#160;VkDescriptorImageInfo& descriptor_image_info =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;bindless_image_info[ current_write_index ];
&#160;&#160;&#160;&#160;if ( texture->sampler != nullptr ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;descriptor_image_info.sampler =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->sampler->vk_sampler;
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;else {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;descriptor_image_info.sampler =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vk_default_sampler->vk_sampler;
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;descriptor_image_info.imageView =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->vk_format != VK_FORMAT_UNDEFINED ?
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->vk_image_view : vk_dummy_texture->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vk_image_view;
&#160;&#160;&#160;&#160;descriptor_image_info.imageLayout =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
&#160;&#160;&#160;&#160;descriptor_write.pImageInfo = &descriptor_image_info;
&#160;&#160;&#160;&#160;texture_to_update.current_frame = u32_max;
&#160;&#160;&#160;&#160;texture_to_update_bindless.delete_swap( it );
&#160;&#160;&#160;&#160;++current_write_index;
}
```


The preceding code is quite similar to the previous version. We have highlighted the main differences: the sampler selection, as we mentioned in the previous paragraph, and the use of a dummy texture if a slot is empty. We still have to assign a texture to each slot, hence the use of a dummy texture if one is not specified. This is also useful for spotting any missing textures in your scene.

If you prefer to have a tightly packed array of textures, another option is to enable the **VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT_EXT** flag and chain a **VkDescriptorSetVariableDescriptorCountAllocateInfoEXT** structure when creating the descriptor set. We already have some preliminary code to enable this feature, and we encourage you to complete the implementation!

## Update to shader code


The final piece of the puzzle to use bindless rendering is in the shader code, as it needs to be written in a different way.

The steps are similar for all shaders making use of bindless resources, and it would be beneficial to have them defined in a common header. Unfortunately, this is not fully supported by the **OpenGL Shading Language**, or **GLSL**.

We recommend automating this step as it can be easily added when compiling the shader in the engine code.

The first thing to do is to enable the nonuniform qualifier in the GLSL code:

```
#extension GL_EXT_nonuniform_qualifier : enable
```


This will enable the extension in the current shader, not globally; thus, it must be written in every shader.

The following code is the declaration of the proper bindless textures, with a catch:

```
layout ( set = 1, binding = 10 ) uniform sampler2D global_textures[];
layout ( set = 1, binding = 10 ) uniform sampler3D global_textures_3d[];
```


This is a known trick to alias the texture declarations to the same binding point. This allows us to have just one global bindless texture array, but all kinds of textures (one-dimensional, two-dimensional, three-dimensional, and their array counterparts) are supported in one go!

This simplifies the usage of bindless textures across the engine and the shaders.

Finally, to read the texture, the code in the shader has to be modified as follows:

```
texture(global_textures[nonuniformEXT(texture_index)],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vTexcoord0)
```


Let’s go in the following order:

- First of all, we need the integer index coming from a constant. In this case, **texture_index** will contain the same number as the texture position in the bindless array.


- Second, and this is the crucial change, we need to wrap the index with the **nonuniformEXT** qualifier ([https://github.com/KhronosGroup/GLSL/blob/master/extensions/ext/GL_EXT_nonuniform_qualifier.txt](https://github.com/KhronosGroup/GLSL/blob/master/extensions/ext/GL_EXT_nonuniform_qualifier.txt)); this will basically synchronize the programs between the different executions to properly read the texture index, in case the index is different across different threads of the same shader invocation.




This might sound complicated at first but think about it as a multithreading issue that needs synchronization to make sure the proper texture index is read in each thread and, as a result, the correct texture is used.

- Lastly, using the synchronized index we read from the **global_textures** array, we finally have the texture sample we wanted!




We have now added bindless textures support to the Raptor Engine! We started by checking whether the GPU supports this feature. Then we detailed the changes we made to the creation of the descriptor pool and descriptor set.

Finally, we have shown how the descriptor set is updated as new textures are uploaded to the GPU and the necessary shader modifications to make use of bindless textures. All the rendering from now on will use this feature; thus, this concept will become familiar.

Next, we are going to improve our engine capabilities by adding automatic pipeline generation by parsing shaders’ binary data.

# Automating pipeline layout generation


In this section, we are going to take advantage of the data provided by the SPIR-V binary format to extract the information needed to create a pipeline layout. SPIR-V is the **intermediate representation** (**IR**) that shader sources are compiled to before being passed to the GPU.

Compared to standard GLSL shader sources, which are plain text, SPIR-V is a binary format. This means it’s a more compact format to use when distributing an application. More importantly, developers don’t have to worry about their shaders getting compiled into a different set of high-level instructions depending on the GPU and driver their code is running on.

However, a SPIR-V binary does not contain the final instructions that will be executed by the GPU. Every GPU will take a SPIR-V blob and do a final compilation into GPU instructions. This step is still required because different GPUs and driver versions can produce different assemblies for the same SPIR-V binary.

Having SPIR-V as an intermediate step is still a great improvement. Shader code validation and parsing are done offline, and developers can compile their shaders together with their application code. This allows us to spot any syntax mistakes before trying to run the shader code.

Another benefit of having an intermediate representation is being able to compile shaders written in different languages to SPIR-V so that they can be used with Vulkan. It’s possible, for instance, to compile a shader written in HLSL into SPIR-V and reuse it in a Vulkan renderer.

Before this option was available, developers either had to port the code manually or had to rely on tools that rewrote the shader from one language to another.

By now, you should be convinced of the advantages the introduction of SPIR-V has brought to developers and the Vulkan API.

In the following sections, we are going to use one of our shaders to show you how to compile it to SPIR-V and explain how to use the information in the binary data to automatically generate a pipeline layout.

## Compiling GLSL to SPIR-V


We are going to use the vertex shader code that we developed in [*Chapter 1*](B18395_01.xhtml#_idTextAnchor016), *Introducing the Raptor Engine and Hydra*. Previously, we stored the shader code string in the **main.cpp** file and we didn’t compile it to SPIR-V before passing it to the Vulkan API to create a pipeline.

Starting from this chapter, we are storing all shader code in the **shaders** folder of each chapter. For [*Chapter 2*](B18395_02.xhtml#_idTextAnchor030), *Improving Resources Management*, you will find two files: **main.vert** for the vertex shader and **main.frag** for the fragment shader. Here is the content of **main.vert**:

```
#version 450
layout ( std140, binding = 0 ) uniform LocalConstants {
&#160;&#160;&#160;&#160;mat4&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;model;
&#160;&#160;&#160;&#160;mat4&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;view_projection;
&#160;&#160;&#160;&#160;mat4&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;model_inverse;
&#160;&#160;&#160;&#160;vec4&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;eye;
&#160;&#160;&#160;&#160;vec4&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light;
};
layout(location=0) in vec3 position;
layout(location=1) in vec4 tangent;
layout(location=2) in vec3 normal;
layout(location=3) in vec2 texCoord0;
layout (location = 0) out vec2 vTexcoord0;
layout (location = 1) out vec3 vNormal;
layout (location = 2) out vec4 vTangent;
layout (location = 3) out vec4 vPosition;
void main() {
&#160;&#160;&#160;&#160;gl_Position = view_projection * model * vec4(position,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1);
&#160;&#160;&#160;&#160;vPosition = model * vec4(position, 1.0);
&#160;&#160;&#160;&#160;vTexcoord0 = texCoord0;
&#160;&#160;&#160;&#160;vNormal = mat3(model_inverse) * normal;
&#160;&#160;&#160;&#160;vTangent = tangent;
}
```


This code is quite standard for a vertex shader. We have four streams of data for position, tangent, normal, and texture coordinates. We have also defined a **LocalConstants** uniform buffer that stores the data common for all vertices. Finally, we have defined the **out** variables that are going to be passed to the fragment shader.

The Vulkan SDK provides the tools to compile GLSL to SPIR-V and to disassemble the generated SPIR-V into human-readable form. This can be useful to debug a shader that is not behaving as expected.

To compile our vertex shader, we run the following command:

```
glslangValidator -V main.vert -o main.vert.spv
```


This will produce a **main.vert.spv** file that contains the binary data. To view the contents of this file in a human-readable format, we run the following command:

```
spirv-dis main.vert.spv
```


This command will print the disassembled SPIR-V on the Terminal. We are now going to examine the relevant sections of the output.

## Understanding the SPIR-V output


Starting from the top of the output, the following is the first set of information we are provided with:

```
&#160;&#160;&#160;&#160;&#160;&#160;OpCapability Shader
%1 = OpExtInstImport "GLSL.std.450"
&#160;&#160;&#160;&#160;&#160;&#160;OpMemoryModel Logical GLSL450
&#160;&#160;&#160;&#160;&#160;&#160;OpEntryPoint Vertex %main "main" %_ %position
&#160;&#160;&#160;&#160;&#160;&#160;%vPosition %vTexcoord0 %texCoord0 %vNormal %normal
&#160;&#160;&#160;&#160;&#160;&#160;%vTangent %tangent
&#160;&#160;&#160;&#160;&#160;&#160;OpSource GLSL 450
&#160;&#160;&#160;&#160;&#160;&#160;OpName %main "main"
```


This preamble defines the version of GLSL that was used to write the shader. The **OpEntryPoint** directive references the main function and lists the inputs and outputs for the shader. The convention is for variables to be prefixed by **%**, and it’s possible to forward declare a variable that is defined later.

The next section defines the output variables that are available in this shader:

```
OpName %gl_PerVertex "gl_PerVertex"
OpMemberName %gl_PerVertex 0 "gl_Position"
OpMemberName %gl_PerVertex 1 "gl_PointSize"
OpMemberName %gl_PerVertex 2 "gl_ClipDistance"
OpMemberName %gl_PerVertex 3 "gl_CullDistance"
OpName %_ ""
```


These are variables that are automatically injected by the compiler and are defined by the GLSL specification. We can see we have a **gl_PerVertex** structure, which in turn has four members: **gl_Position**, **gl_PointSize**, **gl_ClipDistance,** and **gl_CullDistance**. There is also an unnamed variable defined as **%_**. We’re going to discover soon what it refers to.

We now move on to the structures we have defined:

```
OpName %LocalConstants "LocalConstants"
OpMemberName %LocalConstants 0 "model"
OpMemberName %LocalConstants 1 "view_projection"
OpMemberName %LocalConstants 2 "model_inverse"
OpMemberName %LocalConstants 3 "eye"
OpMemberName %LocalConstants 4 "light"
OpName %__0 ""
```


Here, we have the entries for our **LocalConstants** uniform buffer, its members, and their position within the struct. We see again an unnamed **%__0** variable. We’ll get to it shortly. SPIR-V allows you to define member decorations to provide additional information that is useful to determine the data layout and location within the struct:

```
OpMemberDecorate %LocalConstants 0 ColMajor
OpMemberDecorate %LocalConstants 0 Offset 0
OpMemberDecorate %LocalConstants 0 MatrixStride 16
OpMemberDecorate %LocalConstants 1 ColMajor
OpMemberDecorate %LocalConstants 1 Offset 64
OpMemberDecorate %LocalConstants 1 MatrixStride 16
OpMemberDecorate %LocalConstants 2 ColMajor
OpMemberDecorate %LocalConstants 2 Offset 128
OpMemberDecorate %LocalConstants 2 MatrixStride 16
OpMemberDecorate %LocalConstants 3 Offset 192
OpMemberDecorate %LocalConstants 4 Offset 208
OpDecorate %LocalConstants Block
```


From these entries, we can start to have some insights as to the type of each member of the struct. For instance, we can identify the first three entries as being matrices. The last one only has an offset.

The offset value is the most relevant value for our purposes as it allows us to know where exactly each member starts. This is crucial when transferring data from the CPU to the GPU, as the alignment rules for each member could be different.

The next two lines define the descriptor set and binding for our struct:

```
OpDecorate %__0 DescriptorSet 0
OpDecorate %__0 Binding 0
```


As you can see, these decorations refer to the unnamed **%__0** variable. We have now reached the section where the variable types are defined:

```
%float = OpTypeFloat 32
%v4float = OpTypeVector %float 4
%uint = OpTypeInt 32 0
%uint_1 = OpConstant %uint 1
%_arr_float_uint_1 = OpTypeArray %float %uint_1
%gl_PerVertex = OpTypeStruct %v4float %float
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;%_arr_float_uint_1 %_arr_float_uint_1
%_ptr_Output_gl_PerVertex = OpTypePointer Output
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;%gl_PerVertex
%_ = OpVariable %_ptr_Output_gl_PerVertex Output
```


For each variable, we have its type and, depending on the type, additional information that is relevant to it. For instance, the **%float** variable is of type 32-bit **float**; the **%v4float** variable is of type **vector**, and it contains 4 **%****float** values.

This corresponds to **vec4** in GLSL. We then have a constant definition for an unsigned value of **1** and a fixed-sized array of the **float** type and length of **1**.

The definition of the **%gl_PerVertex** variable follows. It is of the **struct** type and, as we have seen previously, it has four members. Their types are **vec4** for **gl_Position**, **float** for **gl_PointSize**, and **float[1]** for **gl_ClipDistance** and **gl_CullDistance**.

The SPIR-V specs require that each variable that can be read or written to is referred to by a pointer. And that’s exactly what we see with **%_ptr_Output_gl_PerVertex**: it’s a pointer to the **gl_PerVertex** struct. Finally, we can see the type for the unnamed **%_** variable is a pointer to the **gl_PerVertex** struct.

Finally, we have the type definitions for our own uniform data:

```
%LocalConstants = OpTypeStruct %mat4v4float %mat4v4float
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;%mat4v4float %v4float %v4float
%_ptr_Uniform_LocalConstants = OpTypePointer Uniform
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;%LocalConstants
%__0 = OpVariable %_ptr_Uniform_LocalConstants
&#160;&#160;&#160;&#160;&#160;&#160;&#160;Uniform
```


As before, we can see that **%LocalConstants** is a struct with five members, three of the **mat4** type and two of the **vec4** type. We then have the type definition of the pointer to our uniform struct and finally, the **%__0** variable of this type. Notice that this variable has the **Uniform** attribute. This means it is read-only and we will make use of this information later to determine the type of descriptor to add to the pipeline layout.

The rest of the disassembly contains the input and output variable definitions. Their definition follows the same structure as the variables we have seen so far, so we are not going to analyze them all here.

The disassembly also contains the instructions for the body of the shader. While it is interesting to see how the GLSL code is translated into SPIR-V instructions, this detail is not relevant to the pipeline creation, and we are not going to cover it here.

Next, we are going to show how we can leverage all of this data to automate pipeline creation.

## From SPIR-V to pipeline layout


Khronos already provides functionality to parse SPIR-V data to create a pipeline layout. You can find the implementation at [https://github.com/KhronosGroup/SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect). For this book, we decided to write a simplified version of the parser that we believe is easier to follow as we are interested only in a small subset of entries.

You can find the implementation in **source\chapter2\graphics\spirv_parser.cpp**. Let’s see how to use this API and how it works under the hood:

```
spirv::ParseResult parse_result{ };
spirv::parse_binary( ( u32* )spv_vert_data,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;spv_vert_data_size, name_buffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&parse_result );
spirv::parse_binary( ( u32* )spv_frag_data,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;spv_frag_data_size, name_buffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&parse_result );
```


Here, we assume that the binary data for the vertex and fragment shader has already been read into the **spv_vert_data** and **spv_frag_data** variables. We have to define an empty **spirv::ParseResult** structure that will contain the result of the parsing. Its definition is quite simple:

```
struct ParseResult {
&#160;&#160;&#160;&#160;u32 set_count;
&#160;&#160;&#160;&#160;DescriptorSetLayoutCreation sets[MAX_SET_COUNT];
};
```


It contains the number of sets that we identified from the binary data and the list of entries for each set.

The first step of the parsing is to make sure that we are reading valid SPIR-V data:

```
u32 spv_word_count = safe_cast<u32>( data_size / 4 );
u32 magic_number = data[ 0 ];
RASSERT( magic_number == 0x07230203 );
u32 id_bound = data[3];
```


We first compute the number of 32-bit words that are included in the binary. Then we verify that the first four bytes match the magic number that identifies a SPIR-V binary. Finally, we retrieve the number of IDs that are defined in the binary.

Next, we loop over all the words in the binary to retrieve the information we need. Each ID definition starts with the **Op** type and the number of words that it is composed of:

```
SpvOp op = ( SpvOp )( data[ word_index ] & 0xFF );
u16 word_count = ( u16 )( data[ word_index ] >> 16 );
```


The **Op** type is stored in the bottom 16 bits of the word, and the word count is in the top 16 bits. Next, we parse the data for the **Op** types we are interested in. We are not going to cover all **Op** types in this section, as the structure is the same for all types. We suggest you refer to the SPIR-V specification (linked in the *Further reading* section) for more details on each **Op** type.

We start with the type of shader we are currently parsing:

```
case ( SpvOpEntryPoint ):
{
&#160;&#160;&#160;&#160;SpvExecutionModel model = ( SpvExecutionModel )data[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;word_index + 1 ];
&#160;&#160;&#160;&#160;stage = parse_execution_model( model );
&#160;&#160;&#160;&#160;break;
}
```


We extract the execution model, translate it into a **VkShaderStageFlags** value, and store it in the **stage** variable.

Next, we parse the descriptor set index and binding:

```
case ( SpvOpDecorate ):
{
&#160;&#160;&#160;&#160;u32 id_index = data[ word_index + 1 ];
&#160;&#160;&#160;&#160;Id& id= ids[ id_index ];
&#160;&#160;&#160;&#160;SpvDecoration decoration = ( SpvDecoration )data[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;word_index + 2 ];
&#160;&#160;&#160;&#160;switch ( decoration )
&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;case ( SpvDecorationBinding ):
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;id.binding = data[ word_index + 3 ];
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;case ( SpvDecorationDescriptorSet ):
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;id.set = data[ word_index + 3 ];
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;break;
}
```


First, we retrieve the index of the ID. As we mentioned previously, variables can be forward declared, and we might have to update the values for the same ID multiple times. Next, we retrieve the value of the decoration. We are only interested in the descriptor set index (**SpvDecorationDescriptorSet**) and binding (**SpvDecorationBinding**) and we store their values in the entry for this ID.

We follow with an example of a variable type:

```
case ( SpvOpTypeVector ):
{
&#160;&#160;&#160;&#160;u32 id_index = data[ word_index + 1 ];
&#160;&#160;&#160;&#160;Id& id= ids[ id_index ];
&#160;&#160;&#160;&#160;id.op = op;
&#160;&#160;&#160;&#160;id.type_index = data[ word_index + 2 ];
&#160;&#160;&#160;&#160;id.count = data[ word_index + 3 ];
&#160;&#160;&#160;&#160;break;
}
```


As we saw in the disassembly, a vector is defined by its entry type and count. We store them in the **type_index** and **count** members of the ID struct. Here, we also see how an ID can refer to another one if needed. The **type_index** member stores the index to another entry in the **ids** array and can be used later to retrieve additional type information.

Next, we have a sampler definition:

```
case ( SpvOpTypeSampler ):
{
&#160;&#160;&#160;&#160;u32 id_index = data[ word_index + 1 ];
&#160;&#160;&#160;&#160;RASSERT( id_index < id_bound );
&#160;&#160;&#160;&#160;Id& id= ids[ id_index ];
&#160;&#160;&#160;&#160;id.op = op;
&#160;&#160;&#160;&#160;break;
}
```


We only need to store the **Op** type for this entry. Finally, we have the entry for a variable type:

```
case ( SpvOpVariable ):
{
&#160;&#160;&#160;&#160;u32 id_index = data[ word_index + 2 ];
&#160;&#160;&#160;&#160;Id& id= ids[ id_index ];
&#160;&#160;&#160;&#160;id.op = op;
&#160;&#160;&#160;&#160;id.type_index = data[ word_index + 1 ];
&#160;&#160;&#160;&#160;id.storage_class = ( SpvStorageClass )data[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;word_index + 3 ];
&#160;&#160;&#160;&#160;break;
}
```


The relevant information for this entry is **type_index**, which will always refer to an entry of **pointer** type and the storage class. The storage class tells us which entries are variables that we are interested in and which ones we can skip.

And that is exactly what the next part of the code is doing. Once we finish parsing all IDs, we loop over each ID entry and identify the ones we are interested in. We first identify all variables:

```
for ( u32 id_index = 0; id_index < ids.size; ++id_index ) {
&#160;&#160;&#160;&#160;Id& id= ids[ id_index ];
&#160;&#160;&#160;&#160;if ( id.op == SpvOpVariable ) {
```


Next, we use the variable storage class to determine whether it is a uniform variable:

```
switch ( id.storage_class ) {
&#160;&#160;&#160;&#160;case ( SpvStorageClassUniform ):
&#160;&#160;&#160;&#160;case ( SpvStorageClassUniformConstant ):
&#160;&#160;&#160;&#160;{
```


We are only interested in the **Uniform** and **UniformConstant** variables. We then retrieve the **uniform** type. Remember, there is a double indirection to retrieve the actual type of a variable: first, we get the **pointer** type, and from the **pointer** type, we get to the real type of the variable. We have highlighted the code that does this:

```
Id& uniform_type = ids[ ids[ id.type_index ].type_index ];
DescriptorSetLayoutCreation& setLayout =
parse_result->sets[ id.set ];
setLayout.set_set_index( id.set );
DescriptorSetLayoutCreation::Binding binding{ };
binding.start = id.binding;
binding.count = 1;
```


After retrieving the type, we get the **DescriptorSetLayoutCreation** entry for the set this variable is part of. We then create a new **binding** entry and store the **binding** value. We always assume a count of **1** for each resource.

In this last step, we determine the resource type for this binding and add its entry to the set layout:

```
switch ( uniform_type.op ) {
&#160;&#160;&#160;&#160;case (SpvOpTypeStruct):
&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;binding.type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;binding.name = uniform_type.name.text;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;case (SpvOpTypeSampledImage):
&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;binding.type = VK_DESCRIPTOR_TYPE_COMBINED
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_IMAGE_SAMPLER;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;binding.name = id.name.text;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;break;
&#160;&#160;&#160;&#160;}
}
setLayout.add_binding_at_index( binding, id.binding );
```


We use the **Op** type to determine the type of resource we have found. So far, we are only interested in **Struct** for uniform buffers and **SampledImage** for textures. We are going to add support for more types when needed for the remainder of the book.

While it’s possible to distinguish between uniform buffers and storage buffers, the binary data cannot determine whether a buffer is dynamic or not. In our implementation, the application code needs to specify this detail.

An alternative would be to use a naming convention (prefixing dynamic buffers with **dyn_**, for instance) so that dynamic buffers can be automatically identified.

This concludes our introduction to the SPIR-V binary format. It might take a couple of readings to fully understand how it works, but don’t worry, it certainly took us a few iterations to fully understand it!

Knowing how to parse SPIR-V data is an important tool to automate other aspects of graphics development. It can be used, for instance, to automate the generation of C++ headers to keep CPU and GPU structs in sync. We encourage you to expand our implementation to add support for the features you might need!

In this section, we have explained how to compile a shader source into SPIR-V. We have shown how the SPIR-V binary format is organized and how to parse this data to help us automatically create a pipeline layout.

In the next and final section of this chapter, we are going to add pipeline caching to our GPU device implementation.

# Improving load times with a pipeline cache


Each time we create a graphics pipeline and, to a lesser extent, a compute pipeline, the driver has to analyze and compile the shaders we have provided. It also has to inspect the state we have defined in the creation structure and translate it into instructions to program the different units of the GPU. This process is quite expensive, and it’s one of the reasons why, in Vulkan we have to define most of the pipeline state upfront.

In this section, we are going to add pipeline caching to our GPU device implementation to improve loading times. If your application has to create thousands of pipelines, it can incur a significant startup time or, for a game, long loading times between levels.

The technique described in this section will help to reduce the time spent creating pipelines. The first change you will notice is that the **GpuDevice::create_pipeline** method accepts a new optional parameter that defines the path of a pipeline cache file:

```
GpuDevice::create_pipeline( const PipelineCreation&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;creation, const char*
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;cache_path )
```


We then need to define the **VkPipelineCache** structure:

```
VkPipelineCache pipeline_cache = VK_NULL_HANDLE;
VkPipelineCacheCreateInfo pipeline_cache_create_info {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO };
```


The next step is to check whether the pipeline cache file already exists. If it does, we load the file data and add it to the pipeline cache creation:

```
FileReadResult read_result = file_read_binary( cache_path,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;allocator );
pipeline_cache_create_info.initialDataSize =
&#160;&#160;read_result.size;
pipeline_cache_create_info.pInitialData = read_result.data;
```


If the file doesn’t exist, we don’t have to make any further changes to the creation structure. We can now call **vkCreatePipelineCache**:

```
vkCreatePipelineCache( vulkan_device,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&pipeline_cache_create_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&pipeline_cache );
```


This will return a handle to a **VkPipelineCache** object that we are going to use when creating the pipeline object:

```
vkCreateGraphicsPipelines( vulkan_device, pipeline_cache,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1, &pipeline_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&pipeline->vk_pipeline );
```


We can do the same for compute pipelines:

```
vkCreateComputePipelines( vulkan_device, pipeline_cache, 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&pipeline_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&pipeline->vk_pipeline );
```


If we have loaded a pipeline cache file, the driver will use the data to accelerate the pipeline creation. If, on the other hand, this is the first time we are creating the given pipeline, we can now query and store the pipeline cache data for later reuse:

```
sizet cache_data_size = 0;
vkGetPipelineCacheData( vulkan_device, pipeline_cache,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&cache_data_size, nullptr );
void* cache_data = allocator->allocate( cache_data_size, 64 );
vkGetPipelineCacheData( vulkan_device, pipeline_cache,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&cache_data_size, cache_data );
file_write_binary( cache_path, cache_data, cache_data_size );
```


We first call **vkGetPipelineCacheData** with **nullptr** for the data member to retrieve the cache data size. We then allocate the memory that is needed to store the cache data and call **vkGetPipelineCacheData** again, this time with a pointer to the memory where the cache data will be stored. Finally, we write this data to the file specified when **GpuDevice::create_pipeline** was called.

We are now done with the pipeline cache data structure, and it can be destroyed:

```
vkDestroyPipelineCache( vulkan_device, pipeline_cache,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks );
```


Before we conclude, we want to mention a shortcoming of pipeline caching. The data in the cache is controlled by each vendor driver implementation. When a new driver version is released, the data format of the cache might change and become incompatible with the data previously stored in the cache file. Having a cache file, in this case, might provide no benefit as the driver cannot make use of it.

For this reason, each driver has to prefix the cache data with the following header:

```
struct VkPipelineCacheHeaderVersionOne {
&#160;&#160;&#160;&#160;uint32_t&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;headerSize;
&#160;&#160;&#160;&#160;VkPipelineCacheHeaderVersion&#160;&#160;&#160;headerVersion;
&#160;&#160;&#160;&#160;uint32_t&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vendorID;
&#160;&#160;&#160;&#160;uint32_t&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;deviceID;
&#160;&#160;&#160;&#160;uint8_t&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pipeline
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;CacheUUID[VK_UUID_SIZE];
}
```


When we load the cache data from disk, we can compare the values in the header against the values returned by the driver and GPU we are running on:

```
VkPipelineCacheHeaderVersionOne* cache_header =
&#160;&#160;&#160;&#160;(VkPipelineCacheHeaderVersionOne*)read_result.data;
if ( cache_header->deviceID == vulkan_physical
&#160;&#160;&#160;&#160;&#160;_properties.deviceID && cache_header->vendorID ==
&#160;&#160;&#160;&#160;&#160;vulkan_physical_properties.vendorID &&
&#160;&#160;&#160;&#160;&#160;memcmp( cache_header->pipelineCacheUUID,
&#160;&#160;&#160;&#160;&#160;vulkan_physical_properties.pipelineCacheUUID,
&#160;&#160;&#160;&#160;&#160;VK_UUID_SIZE ) == 0 ) {
&#160;&#160;&#160;&#160;pipeline_cache_create_info.initialDataSize =
&#160;&#160;&#160;&#160;read_result.size;
&#160;&#160;&#160;&#160;pipeline_cache_create_info.pInitialData =
&#160;&#160;&#160;&#160;read_result.data;
}
else
{
&#160;&#160;&#160;&#160;cache_exists = false;
}
```


If the values in the header match the ones of the device we are running on, we use the cache data as before. If they don’t, we act as if the cache didn’t exist and store a new version after the pipeline has been created.

In this section, we have demonstrated how to leverage pipeline caching to speed up pipeline creation at runtime. We have highlighted the changes made to our GPU device implementation to make use of this feature and how it has been used in this chapter’s code.

# 小结
In this chapter, we improved our GPU device implementation to make it easier to manage a large number of textures with bindless resources. We explained which extensions are needed and detailed which changes are required when creating a descriptor set layout to allow the use of bindless resources. We then showed the changes needed when creating a descriptor set to update the array of textures in use.

We then added automatic pipeline layout generation by parsing the SPIR-V binaries generated by the **glslang** compiler for our shaders. We provided an overview of the SPIR-V binary data format and explained how to parse it to extract the resources bound to a shader, and how to use this information to create a pipeline layout.

Finally, we enhanced our pipeline creation API by adding pipeline caching to improve the load times of our applications after the first run. We presented the Vulkan APIs that are needed to either generate or load the pipeline cache data. We also explained some of the limitations of pipeline caching and how to deal with them.

All the techniques presented in this chapter have the common goal of making it easier to deal with large projects and reduce manual code changes to a minimum when making changes to our shaders or materials.

We will continue to scale our engine in the next chapter by adding multithreading to record multiple command buffers or to submit multiple workloads in parallel to the GPU.

# 延伸阅读
We have covered only a small subset of the SPIR-V specification. If you would like to expand our parser implementation for your needs, we highly recommend consulting the official specification: [https://www.khronos.org/registry/SPIR-V/specs/unified1/SPIRV.html](https://www.khronos.org/registry/SPIR-V/specs/unified1/SPIRV.html).

We wrote a custom SPIR-V parser for this chapter, primarily for educational purposes. For your own project, we recommend using the existing reflection library from Khronos: [https://github.com/KhronosGroup/SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect).

It provides the functionality described in this chapter to deduce the pipeline layout for a shader binary and many other features.