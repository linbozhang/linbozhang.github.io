# 第 2 章：改进资源管理

本章将改进资源管理，使处理纹理数量不固定的材质更简单。这类技术常被称作 bindless（无绑定），虽不十分贴切：我们仍然会绑定一组资源，但可以通过索引访问，而无需在每次绘制时显式指定具体用哪些资源。

第二个改进是自动生成管线布局（pipeline layout）。大型项目有数百乃至数千个着色器，随材质组合不同而有多种编译变体。若每次改动都要人手更新管线布局定义，很难把应用推向市场。本章实现将依赖 SPIR-V 二进制格式提供的信息。

最后，我们会在 GPU 设备实现中加入管线缓存（pipeline cache）。这样在首次运行之后可以加快管线对象的创建，从而明显缩短应用加载时间。

本章将涵盖以下主题：

- 启用并实现 bindless 资源
- 自动生成管线布局
- 用管线缓存缩短加载时间

学完本章后，你将掌握在 Vulkan 中启用和使用 bindless 资源、解析 SPIR-V 二进制并自动生成管线布局，以及通过管线缓存加快应用加载。

## 技术需求

本章代码可在以下地址获取：[Mastering-Graphics-Programming-with-Vulkan/source/chapter2](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter2)。

## 启用并实现 bindless 渲染

上一章中我们不得不为每种材质手动绑定纹理。这也意味着若要支持纹理数量不同的多种材质，就需要多套着色器和管线。
Vulkan 提供了一种机制：可以绑定一个纹理数组并在多个着色器中共用，每个纹理通过索引访问。下面几节将说明我们为启用该特性对 GPU 设备实现做的修改，以及如何使用它。

接下来我们会：先确认当前 GPU 是否支持启用 bindless 所需的扩展；再说明描述符池创建与描述符集更新所需的改动；最后更新着色器，使渲染时通过纹理数组的索引访问。

### 检查支持情况

在驱动较新的前提下，多数桌面 GPU（即便较老）都应支持 `VK_EXT_descriptor_indexing` 扩展。仍建议在运行时检查扩展是否可用；若做正式产品，在扩展不可用时应提供回退到标准绑定模型的代码路径。

要验证设备是否支持该扩展，可使用下面代码，或运行 Vulkan SDK 提供的 `vulkaninfo`。SDK 安装方法见第 1 章《介绍 Raptor Engine 与 Hydra》。

第一步是查询物理设备以确认 GPU 是否支持该扩展。以下代码完成这一查询：
```cpp
VkPhysicalDeviceDescriptorIndexingFeatures indexing_features{ VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES, nullptr };
VkPhysicalDeviceFeatures2 device_features{ VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, &indexing_features };
vkGetPhysicalDeviceFeatures2( vulkan_physical_device, &device_features );
bindless_supported = indexing_features.descriptorBindingPartiallyBound && indexing_features.runtimeDescriptorArray;
```

需要填充 `VkPhysicalDeviceDescriptorIndexingFeatures` 并把它链到 `VkPhysicalDeviceFeatures2` 上。调用 `vkGetPhysicalDeviceFeatures2` 后，驱动会填好 `indexing_features` 的成员。我们通过 `descriptorBindingPartiallyBound` 和 `runtimeDescriptorArray` 均为 true 来确认支持描述符索引扩展。

确认支持后，在创建设备时启用该扩展：
```cpp
VkPhysicalDeviceFeatures2 physical_features2 = { VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 };
vkGetPhysicalDeviceFeatures2( vulkan_physical_device, &physical_features2 );
VkDeviceCreateInfo device_create_info = {};
// 与第 1 章相同
device_create_info.pNext = &physical_features2;
if ( bindless_supported ) {
    physical_features2.pNext = &indexing_features;
}
vkCreateDevice( vulkan_physical_device, &device_create_info, vulkan_allocation_callbacks, &vulkan_device );
```

需要把 `indexing_features` 链到创建设备时使用的 `physical_features2` 上。其余逻辑与第 1 章《介绍 Raptor Engine 与 Hydra》一致。

### 创建描述符池

下一步是创建描述符池，以便分配“在绑定后仍可更新纹理内容”的描述符集：
```cpp
VkDescriptorPoolSize pool_sizes_bindless[] = {
    { VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, k_max_bindless_resources },
    { VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, k_max_bindless_resources },
};
pool_info.flags = VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT_EXT;
pool_info.maxSets = k_max_bindless_resources * ArraySize( pool_sizes_bindless );
pool_info.poolSizeCount = ( u32 )ArraySize( pool_sizes_bindless );
pool_info.pPoolSizes = pool_sizes_bindless;
vkCreateDescriptorPool( vulkan_device, &pool_info, vulkan_allocation_callbacks, &vulkan_bindless_descriptor_pool );
```

与第 1 章相比，主要多了 `VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT_EXT` 标志。该标志用于允许创建“绑定后仍可更新”的描述符集。

接着定义描述符集布局的 binding：
```cpp
const u32 pool_count = ( u32 )ArraySize( pool_sizes_bindless );
VkDescriptorSetLayoutBinding vk_binding[ 4 ];
VkDescriptorSetLayoutBinding& image_sampler_binding = vk_binding[ 0 ];
image_sampler_binding.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
image_sampler_binding.descriptorCount = k_max_bindless_resources;
image_sampler_binding.binding = k_bindless_texture_binding;
VkDescriptorSetLayoutBinding& storage_image_binding = vk_binding[ 1 ];
storage_image_binding.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
storage_image_binding.descriptorCount = k_max_bindless_resources;
storage_image_binding.binding = k_bindless_texture_binding + 1;

VkDescriptorSetLayoutCreateInfo layout_info = { VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO };
layout_info.bindingCount = pool_count;
layout_info.pBindings = vk_binding;
layout_info.flags = VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT_EXT;
VkDescriptorBindingFlags bindless_flags = VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT_EXT | VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT_EXT;
VkDescriptorBindingFlags binding_flags[ 4 ];
binding_flags[ 0 ] = bindless_flags;
binding_flags[ 1 ] = bindless_flags;
VkDescriptorSetLayoutBindingFlagsCreateInfoEXT extended_info{ VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO_EXT, nullptr };
extended_info.bindingCount = pool_count;
extended_info.pBindingFlags = binding_flags;
layout_info.pNext = &extended_info;
vkCreateDescriptorSetLayout( vulkan_device, &layout_info, vulkan_allocation_callbacks, &vulkan_bindless_descriptor_layout );

VkDescriptorSetAllocateInfo alloc_info{ VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO };
alloc_info.descriptorPool = vulkan_bindless_descriptor_pool;
alloc_info.descriptorSetCount = 1;
alloc_info.pSetLayouts = &vulkan_bindless_descriptor_layout;
vkAllocateDescriptorSets( vulkan_device, &alloc_info, &vulkan_bindless_descriptor_set );
```

注意 `descriptorCount` 不再为 1，而要能容纳我们使用的最大纹理数量。代码与上一章很接近，但增加了 `bindless_flags` 以支持描述符集的部分更新，并把 `VkDescriptorSetLayoutBindingFlagsCreateInfoEXT` 链到 `layout_info`。最后分配应用生命周期内使用的描述符集：填充 `VkDescriptorSetAllocateInfo` 并调用 `vkAllocateDescriptorSets`。

### 更新描述符集
到这里大部分工作已经完成。调用 `GpuDevice::create_texture` 时，新创建的资源会被加入 `texture_to_update_bindless` 数组：

```cpp
if ( gpu.bindless_supported ) {
    ResourceUpdate resource_update{ ResourceDeletionType::Texture, texture->handle.index, gpu.current_frame };
    gpu.texture_to_update_bindless.push( resource_update );
}
```

也可以为某张纹理指定采样器。例如为某材质加载纹理时加入：

```cpp
gpu.link_texture_sampler( diffuse_texture_gpu.handle, diffuse_sampler_gpu.handle );
```

这样就把漫反射纹理和其采样器关联起来，下一段代码会根据该信息决定使用默认采样器还是刚绑定的采样器。

在下一帧开始前，用本帧新上传的纹理更新前面创建好的描述符集：
```cpp
for ( i32 it = texture_to_update_bindless.size - 1; it >= 0; it-- ) {
    ResourceUpdate& texture_to_update = texture_to_update_bindless[ it ];
    Texture* texture = access_texture( { texture_to_update.handle } );
    VkWriteDescriptorSet& descriptor_write = bindless_descriptor_writes[ current_write_index ];
    descriptor_write = { VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET };
    descriptor_write.descriptorCount = 1;
    descriptor_write.dstArrayElement = texture_to_update.handle;
    descriptor_write.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    descriptor_write.dstSet = vulkan_bindless_descriptor_set;
    descriptor_write.dstBinding = k_bindless_texture_binding;
    Sampler* vk_default_sampler = access_sampler( default_sampler );
    VkDescriptorImageInfo& descriptor_image_info = bindless_image_info[ current_write_index ];
    if ( texture->sampler != nullptr ) {
        descriptor_image_info.sampler = texture->sampler->vk_sampler;
    } else {
        descriptor_image_info.sampler = vk_default_sampler->vk_sampler;
    }
    descriptor_image_info.imageView = texture->vk_format != VK_FORMAT_UNDEFINED ? texture->vk_image_view : vk_dummy_texture->vk_image_view;
    descriptor_image_info.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    descriptor_write.pImageInfo = &descriptor_image_info;
    texture_to_update.current_frame = u32_max;
    texture_to_update_bindless.delete_swap( it );
    ++current_write_index;
}
```

这段逻辑与之前版本类似。主要区别是：按上一段方式选择采样器；若槽位为空则使用占位（dummy）纹理。因为每个槽位都必须绑定纹理，未指定时就用占位纹理，也有利于在场景中排查缺失纹理。

若希望纹理数组紧凑排列，可以启用 `VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT_EXT`，并在分配描述符集时链入 `VkDescriptorSetVariableDescriptorCountAllocateInfoEXT`。我们已有部分铺垫代码，欢迎在此基础上补全实现。

### 着色器代码的修改

使用 bindless 渲染的最后一步在着色器里：需要按另一种方式编写。
所有使用 bindless 资源的着色器步骤类似，若能放在公共头文件里会更好，但 OpenGL Shading Language（GLSL）对此支持有限。建议在引擎编译着色器时自动插入这些内容。

首先在 GLSL 中启用 nonuniform 限定符：

```glsl
#extension GL_EXT_nonuniform_qualifier : enable
```

该扩展只对当前着色器生效，因此每个着色器都要写一遍。

下面是 bindless 纹理的声明，有一个小技巧：

```glsl
layout ( set = 1, binding = 10 ) uniform sampler2D global_textures[];
layout ( set = 1, binding = 10 ) uniform sampler3D global_textures_3d[];
```

这是常用做法：把不同维度的纹理声明别名到同一 binding。这样只需一个全局 bindless 纹理数组，就能同时支持一维、二维、三维及其数组形式，在引擎和着色器里都更统一。

读取纹理时，着色器里要改成：

```glsl
texture( global_textures[ nonuniformEXT( texture_index ) ], vTexcoord0 )
```

要点依次是：

1. 使用一个整数索引（例如 `texture_index`），其值对应该纹理在 bindless 数组中的位置。
2. **关键**：用 `nonuniformEXT` 包住索引（参见 [GL_EXT_nonuniform_qualifier](https://github.com/KhronosGroup/GLSL/blob/master/extensions/ext/GL_EXT_nonuniform_qualifier.txt)）。这样会在不同执行之间做同步，保证正确读出纹理索引——尤其在同一调用内不同线程可能用不同索引时。
可以把它理解成多线程下的同步问题：需要保证每个线程读到正确的纹理索引，从而访问正确的纹理。
3. 用同步后的索引从 `global_textures` 中采样，得到所需纹素。

至此 Raptor Engine 已支持 bindless 纹理：我们先检查了 GPU 是否支持，再说明了描述符池与描述符集创建上的改动，以及新纹理上传后如何更新描述符集、着色器侧需要做的修改。之后所有渲染都会使用该特性。

接下来我们通过解析着色器二进制数据，为引擎增加自动管线布局生成能力。

## 自动生成管线布局
本节将利用 SPIR-V 二进制格式提供的数据，提取创建管线布局所需的信息。SPIR-V 是着色器源码在交给 GPU 之前编译成的中间表示（IR）。
与纯文本的 GLSL 源码相比，SPIR-V 是二进制格式，发布应用时更紧凑。更重要的是，开发者不必担心同一份着色器在不同 GPU 和驱动上被编译成不同的高层指令。
但 SPIR-V 二进制并不是 GPU 最终执行的指令。每块 GPU 都会把 SPIR-V 再做一次最终编译成 GPU 指令，因为不同 GPU 和驱动版本可能对同一 SPIR-V 产生不同汇编。
把 SPIR-V 作为中间步骤仍有很大好处：着色器的校验和解析可以离线完成，并能和业务代码一起编译，便于在运行前发现语法错误。
另一好处是能把多种语言写的着色器编译成 SPIR-V 供 Vulkan 使用，例如把 HLSL 着色器编译成 SPIR-V 并在 Vulkan 渲染器中复用。在此之前，只能手写移植或依赖把着色器从一种语言改写为另一种的工具。
至此应能体会到 SPIR-V 为开发者和 Vulkan API 带来的优势。
下面我们用一个实际着色器演示如何编译到 SPIR-V，以及如何用二进制中的信息自动生成管线布局。

### 将 GLSL 编译为 SPIR-V
我们使用第 1 章《介绍 Raptor Engine 与 Hydra》中的顶点着色器。之前把着色器源码字符串放在 main.cpp 里，并在传给 Vulkan 创建管线前未先编译成 SPIR-V。
从本章起，所有着色器代码放在各章的 `shaders` 目录下。第 2 章《改进资源管理》中有两个文件：顶点着色器 `main.vert` 和片元着色器 `main.frag`。下面是 `main.vert` 的内容：
```glsl
#version 450
layout ( std140, binding = 0 ) uniform LocalConstants {
mat4 model;
mat4 view_projection;
mat4 model_inverse;
vec4 eye;
vec4 light;
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
gl_Position = view_projection * model * vec4(position,
1);
vPosition = model * vec4(position, 1.0);
vTexcoord0 = texCoord0;
vNormal = mat3(model_inverse) * normal;
vTangent = tangent;
}
```
这是较标准的顶点着色器：位置、切线、法线、纹理坐标四路输入，一个所有顶点共用的 LocalConstants uniform 缓冲，以及输出到片元着色器的变量。
Vulkan SDK 提供将 GLSL 编译为 SPIR-V、以及把生成的 SPIR-V 反汇编为可读形式的工具，便于调试异常行为的着色器。
编译顶点着色器可执行：

```bash
glslangValidator -V main.vert -o main.vert.spv
```

会生成包含二进制的 `main.vert.spv`。要以可读形式查看内容可执行：

```bash
spirv-dis main.vert.spv
```

反汇编结果会打印到终端。下面我们只看与管线布局相关的部分。

### 理解 SPIR-V 输出

从输出开头起，首先会看到类似下面的信息：
```spirv
OpCapability Shader
%1 = OpExtInstImport "GLSL.std.450"
OpMemoryModel Logical GLSL450
OpEntryPoint Vertex %main "main" %_ %position %vPosition %vTexcoord0 %texCoord0 %vNormal %normal %vTangent %tangent
OpSource GLSL 450
OpName %main "main"
```

这段前导说明了编写着色器所用的 GLSL 版本。`OpEntryPoint` 指向 main 并列出着色器的输入与输出。约定以 `%` 为变量前缀，且可前向声明后文才定义的变量。

下一段定义该着色器中的输出变量：
```spirv
OpName %gl_PerVertex "gl_PerVertex"
OpMemberName %gl_PerVertex 0 "gl_Position"
...
OpName %_ ""
```

这些是编译器按 GLSL 规范自动注入的变量。其中有 `gl_PerVertex` 结构体，包含 gl_Position、gl_PointSize、gl_ClipDistance、gl_CullDistance 四个成员，以及一个无名变量 `%_`，稍后会看到它指什么。

接着是我们自己定义的结构体：
```spirv
OpName %LocalConstants "LocalConstants"
OpMemberName %LocalConstants 0 "model"
...
OpName %__0 ""
```

这里对应我们的 LocalConstants uniform 缓冲及其成员在结构体中的位置，再次出现无名变量 `%__0`，稍后说明。SPIR-V 允许用成员装饰（member decoration）提供布局与偏移等额外信息：
```spirv
OpMemberDecorate %LocalConstants 0 Offset 0
...
OpDecorate %LocalConstants Block
```

从这些条目可以推断各成员类型（例如前三个为矩阵，最后一个只有偏移）。对我们最有用的是 **Offset**，它给出每个成员的起始位置，在 CPU 向 GPU 传数据时很重要，因为各成员对齐规则可能不同。

下面两行为该结构体指定 descriptor set 与 binding：

```spirv
OpDecorate %__0 DescriptorSet 0
OpDecorate %__0 Binding 0
```

它们作用在无名变量 `%__0` 上。接下来是变量类型定义部分：
（此处为类型与变量定义：%float、%v4float、%gl_PerVertex 等。每个变量都有其类型及与类型相关的信息；可读写的变量在 SPIR-V 中通过指针引用。）

我们自己的 uniform 数据的类型定义在最后：
`%LocalConstants` 是包含五个成员的结构体（三个 mat4、两个 vec4），接着是指向该 uniform 结构体的指针类型，以及该类型的变量 `%__0`。该变量带 Uniform 属性，即只读，后面会用它决定往管线布局里添加哪种描述符类型。
反汇编其余部分还有输入/输出变量定义和着色器主体指令，结构类似，此处不逐一分析；GLSL 如何翻译成 SPIR-V 指令与管线创建无关，也不展开。
下面说明如何利用这些数据自动创建管线。

### 从 SPIR-V 到管线布局

Khronos 已提供解析 SPIR-V 并创建管线布局的实现：[SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect)。本书为便于理解只实现了一个简化版解析器，只处理我们关心的那一小部分条目。
实现位于 `source/chapter2/graphics/spirv_parser.cpp`。下面看如何调用该 API 以及其内部逻辑：
```cpp
spirv::ParseResult parse_result{ };
spirv::parse_binary( ( u32* )spv_vert_data, spv_vert_data_size, name_buffer, &parse_result );
spirv::parse_binary( ( u32* )spv_frag_data, spv_frag_data_size, name_buffer, &parse_result );
```

这里假定顶点与片元着色器的二进制已读入 `spv_vert_data` 和 `spv_frag_data`。需要准备一个空的 `spirv::ParseResult` 存放解析结果，其定义大致如下：

```cpp
struct ParseResult {
    u32 set_count;
    DescriptorSetLayoutCreation sets[MAX_SET_COUNT];
};
```

其中包含从二进制中识别出的 set 数量以及每个 set 的条目列表。

解析第一步是确认数据是合法的 SPIR-V：
```cpp
u32 spv_word_count = safe_cast<u32>( data_size / 4 );
u32 magic_number = data[ 0 ];
RASSERT( magic_number == 0x07230203 );
u32 id_bound = data[3];
```

先计算二进制中包含的 32 位字数量，再校验前四字节是否为 SPIR-V 魔数，最后读取二进制中定义的 ID 数量。
然后遍历二进制中的每个字以收集需要的信息。每条指令以 Op 类型和字数开头：

```cpp
SpvOp op = ( SpvOp )( data[ word_index ] & 0xFF );
u16 word_count = ( u16 )( data[ word_index ] >> 16 );
```

低 16 位是 Op 类型，高 16 位是字数。接着按我们关心的 Op 类型解析。本节不覆盖所有 Op，结构类似，更多细节见“延伸阅读”中的 SPIR-V 规范。
先从当前解析的着色器类型开始：
```cpp
case ( SpvOpEntryPoint ): {
    SpvExecutionModel model = ( SpvExecutionModel )data[ word_index + 1 ];
    stage = parse_execution_model( model );
    break;
}
```

从中取出 execution model，转换为 `VkShaderStageFlags` 并存入 `stage`。接着解析 descriptor set 索引与 binding：
```c++
{case ( SpvOpDecorate ):
u32 id_index = data[ word_index + 1 ];
Id& id= ids[ id_index ];
SpvDecoration decoration = ( SpvDecoration )data[
word_index + 2 ];
switch ( decoration )
{
case ( SpvDecorationBinding ):
{
id.binding = data[ word_index + 3 ];
break;
}
case ( SpvDecorationDescriptorSet ):
 {
id.set = data[ word_index + 3 ];
break;
}
}
break;
}
```
先取 ID 的索引（变量可前向声明，同一 ID 可能被多次更新）。再取装饰类型，我们只关心 DescriptorSet 和 Binding，并把值存到该 ID 的条目中。
下面以变量类型解析为例：
```c++
{case ( SpvOpTypeVector ):
u32 id_index = data[ word_index + 1 ];
Id& id= ids[ id_index ];
id.op = op;
id.type_index = data[ word_index + 2 ];
id.count = data[ word_index + 3 ];
break;
}
```
反汇编中向量由其元素类型和数量定义，我们将其存入 ID 的 type_index 与 count。type_index 指向 ids 数组中的另一项，可用来递归获取类型信息。
接着是采样器类型：
```c++
{case ( SpvOpTypeSampler ):
u32 id_index = data[ word_index + 1 ];
RASSERT( id_index < id_bound );
 Id& id= ids[ id_index ];
id.op = op;
break;
}
```
这里只需保存该条目的 Op 类型。最后是变量类型的处理：
```c++
{case ( SpvOpVariable ):
u32 id_index = data[ word_index + 2 ];
Id& id= ids[ id_index ];
id.op = op;
id.type_index = data[ word_index + 1 ];
id.storage_class = ( SpvStorageClass )data[
word_index + 3 ];
break;
}
```
该条目的关键信息是 type_index（总是指向指针类型）和 storage_class。storage_class 用来区分我们关心的变量与可跳过的条目。
解析完所有 ID 后，遍历并找出变量，再根据 storage_class 只处理 Uniform / UniformConstant；通过二次间接（先取指针类型，再取所指类型）得到真实类型，据此创建 binding 并加入对应 set 的 layout（Struct→UNIFORM_BUFFER，SampledImage→COMBINED_IMAGE_SAMPLER，count 暂为 1）。uniform 与 storage buffer 可从二进制区分，但无法判断是否 dynamic，需由应用指定或通过命名约定（如 dyn_ 前缀）自动识别。
以上是对 SPIR-V 二进制格式的入门介绍，多读几遍会更容易掌握。会解析 SPIR-V 后还可用来自动化其他工作，例如生成 C++ 头文件以保持 CPU/GPU 结构体一致。欢迎在现有实现上扩展你需要的功能。
本节说明了如何把着色器编译为 SPIR-V、二进制的大致结构以及如何解析并自动生成管线布局。本章最后一节将在 GPU 设备实现中加入管线缓存。

## 用管线缓存缩短加载时间

每次创建图形管线（以及程度较轻的计算管线）时，驱动都要分析和编译我们提供的着色器，并检查创建结构体中的状态、将其翻译成驱动 GPU 各单元的指令。这一过程开销较大，也是 Vulkan 要求我们提前定义大部分管线状态的原因之一。
本节在 GPU 设备实现中加入管线缓存以缩短加载时间。若应用需要创建大量管线，会导致启动或关卡加载很慢，本节方法有助于减少管线创建耗时。
首先，`GpuDevice::create_pipeline` 增加了一个可选参数，用于指定管线缓存文件路径：
```cpp
GpuDevice::create_pipeline( const PipelineCreation& creation, const char* cache_path )
```

接着定义并创建 `VkPipelineCache`。若缓存文件已存在，则读入并填入 `VkPipelineCacheCreateInfo` 的 initialData；若不存在则不改动创建信息。然后调用 `vkCreatePipelineCache`，得到句柄后在创建图形/计算管线时传入 `vkCreateGraphicsPipelines` / `vkCreateComputePipelines`。若加载了缓存文件，驱动会用它加速管线创建；若是首次创建该管线，可在创建后查询并保存缓存数据供下次使用：
```cpp
size_t cache_data_size = 0;
vkGetPipelineCacheData( vulkan_device, pipeline_cache, &cache_data_size, nullptr );
void* cache_data = allocator->allocate( cache_data_size, 64 );
vkGetPipelineCacheData( vulkan_device, pipeline_cache, &cache_data_size, cache_data );
file_write_binary( cache_path, cache_data, cache_data_size );
```

先用 `vkGetPipelineCacheData` 且 data 传 nullptr 获取大小，再分配内存并再次调用以读入数据，最后写入 `create_pipeline` 时传入的路径。用完后销毁管线缓存：`vkDestroyPipelineCache`。

需要说明管线缓存的一个局限：缓存数据格式由各厂商驱动决定，驱动升级后格式可能变化，旧缓存文件可能无法使用，此时缓存没有收益。因此驱动会在缓存数据前加上如下头：
```cpp
struct VkPipelineCacheHeaderVersionOne {
    uint32_t headerSize;
    VkPipelineCacheHeaderVersion headerVersion;
    uint32_t vendorID;
    uint32_t deviceID;
    uint8_t pipelineCacheUUID[VK_UUID_SIZE];
}
```

从磁盘加载缓存时，将头中的 deviceID、vendorID、pipelineCacheUUID 与当前物理设备属性比较；若一致则设置 `pipeline_cache_create_info.initialDataSize` 与 `pInitialData` 使用该缓存，否则设 `cache_exists = false`，创建管线后再保存新缓存。

## 小结

本章改进了 GPU 设备实现，通过 bindless 资源更便于管理大量纹理：说明了所需扩展、创建描述符集布局时的改动，以及创建与更新描述符集中纹理数组时的改动。
接着通过解析 glslang 为着色器生成的 SPIR-V 二进制实现了管线布局的自动生成；概述了 SPIR-V 二进制格式，并说明如何解析以得到着色器绑定的资源、并据此创建管线布局。
最后在管线创建 API 中加入了管线缓存以在首次运行后缩短加载时间；介绍了生成与加载管线缓存所需的 Vulkan API，以及管线缓存的局限与应对方式。
本章所有技术的共同目标是便于应对大型项目，并在修改着色器或材质时尽量减少手写改动。
下一章将通过多线程录制多条命令缓冲或并行向 GPU 提交多路工作负载，继续扩展引擎。

## 延伸阅读

我们只涉及 SPIR-V 规范的一小部分。若要扩展解析器以满足需求，建议查阅官方规范：[SPIR-V 规范](https://www.khronos.org/registry/SPIR-V/specs/unified1/SPIRV.html)。
本章的自定义 SPIR-V 解析器主要为教学目的。在实际项目中建议使用 Khronos 的现成反射库：[SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect)，它提供从着色器二进制推导管线布局等本章所述功能及更多特性。