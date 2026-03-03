# Chapter 5: Unlocking Async Compute

# 5



# Unlocking Async Compute


In this chapter, we are going to improve our renderer by allowing compute work to be done in parallel with graphics tasks. So far, we have been recording and submitting all of our work to a single queue. We can still submit compute tasks to this queue to be executed alongside graphics work: in this chapter, for instance, we have started using a compute shader for the fullscreen lighting rendering pass. We don’t need a separate queue in this case as we want to reduce the amount of synchronization between separate queues.

However, it might be beneficial to run other compute workloads on a separate queue and allow the GPU to fully utilize its compute units. In this chapter, we are going to implement a simple cloth simulation using compute shaders that will run on a separate compute queue. To unlock this new functionality, we will need to make some changes to our engine.

In this chapter, we’re going to cover the following main topics:

- Using a single timeline semaphore to avoid multiple fences


- Adding a separate queue for async compute


- Implementing cloth simulation using async compute





# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter5](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter5)

# Replacing multiple fences with a single timeline semaphore


In this section, we are going to explain how fences and semaphores are currently used in our renderer and how to reduce the number of objects we must use by taking advantage of timeline semaphores.

Our engine already supports rendering multiple frames in parallel using fences. Fences must be used to ensure the GPU has finished using resources for a given frame. This is accomplished by waiting on the CPU before submitting a new batch of commands to the GPU.



 ![Figure 5.1 – The CPU is working on the current frame while the GPU is rendering the previous frame](image/B18395_05_01.jpg)


Figure 5.1 – The CPU is working on the current frame while the GPU is rendering the previous frame

There is a downside, however; we need to create a fence for each frame in flight. This means we will have to manage at least two fences for double buffering and three if we want to support triple buffering.

We also need multiple semaphores to ensure the GPU waits for certain operations to complete before moving on. For instance, we need to signal a semaphore once rendering is complete and pass that same semaphore to the present command. This is needed to guarantee that rendering is complete before we try to present the swap chain image.

The following diagram illustrates two scenarios; in the first one, no semaphore is present, and the swapchain image could be presented to the screen while rendering is still in progress.

In the second scenario, we have added a semaphore that is signaled in the render submission and is waited on before presenting. This ensures the correct behavior of the application. If we didn’t have this semaphore, we would risk presenting an image that is still being rendered and displaying corrupted data.



 ![Figure 5.2 – Two scenarios illustrating the need for a semaphore between rendering and presentation](image/B18395_05_02.jpg)


Figure 5.2 – Two scenarios illustrating the need for a semaphore between rendering and presentation

The situation worsens when we start to consider multiple queues. In this chapter, we are going to add a separate compute queue. This means that we will need to add more fences to wait on the CPU for compute work to complete. We will also need new semaphores to synchronize the compute and graphics queue to ensure the data produced by the compute queue is ready to be used by the graphics queue.

Even if we weren’t using a compute queue, we might want to break our rendering work into multiple submissions. Each submission would need its own signal and wait for semaphores according to the dependencies of each workload. This can get out of hand quickly for large scenes that have tens, possibly hundreds, of submissions.

Luckily for us, there is a solution. If we think about it, the fence and the semaphore hold the same information; they get signaled once a submission is complete. What if there was a way to use a single object both on the CPU and the GPU? This exact functionality is provided by a timeline semaphore.

As the name suggests, a timeline semaphore holds a monotonically increasing value. We can define what value we want the semaphore to be signaled with and what value we want to wait for. This object can be waited on by both the GPU and the CPU, greatly reducing the number of objects needed to implement correct synchronization.

We are now going to show how to use timeline semaphores in Vulkan.

## Enabling the timeline semaphore extension


The timeline semaphore feature has been promoted to core in Vulkan 1.2. However, it’s not a mandatory extension, so we first need to query for support before using it. This is done, as usual, by enumerating the extension the device exposes and looking for the extension name:

```
vkEnumerateDeviceExtensionProperties(
&#160;&#160;&#160;&#160;vulkan_physical_device, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&device_extension_count, extensions );
for ( size_t i = 0; i < device_extension_count; i++ ) {
&#160;&#160;&#160;&#160;if ( !strcmp( extensions[ i ].extensionName,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME ) ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;timeline_semaphore_extension_present = true;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;continue;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
}
```


If the extension is present, we need to populate an additional structure that will be used at device creation, as shown in the following code:

```
VkPhysicalDeviceFeatures2 physical_features2 {
VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 };
void* current_pnext = nullptr;
VkPhysicalDeviceTimelineSemaphoreFeatures timeline_sempahore_features{ VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES&#160;&#160;};
if ( timeline_semaphore_extension_present ) {
&#160;&#160;&#160;&#160;timeline_sempahore_features.pNext = current_pnext;
&#160;&#160;&#160;&#160;current_pnext = &timeline_sempahore_features;
}
physical_features2.pNext = current_pnext;
vkGetPhysicalDeviceFeatures2( vulkan_physical_device,
&#160;&#160;&#160;&#160;&physical_features2 );
```


We also need to add the extension name to the list of enabled extensions:

```
if ( timeline_semaphore_extension_present ) {
&#160;&#160;&#160;&#160;device_extensions.push(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME );
}
```


Finally, we use the data we just retrieved when creating the device:

```
VkDeviceCreateInfo device_create_info {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO };
device_create_info.enabledExtensionCount =
&#160;&#160;&#160;&#160;device_extensions.size;&#160;&#160;
device_create_info.ppEnabledExtensionNames =
&#160;&#160;&#160;&#160;device_extensions.data;
device_create_info.pNext = &physical_features2;
vkCreateDevice( vulkan_physical_device,
&#160;&#160;&#160;&#160;&device_create_info, vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&vulkan_device );
```


We are now ready to use a timeline semaphore in our code! We will see how to create a timeline semaphore in the next section.

## Creating a timeline semaphore


Creating a timeline semaphore is quite simple. We start by defining the standard creation structure:

```
VkSemaphoreCreateInfo semaphore_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
```


We then need to pass an extra structure to tell the API that we want to create a timeline semaphore:

```
VkSemaphoreTypeCreateInfo semaphore_type_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO };
semaphore_type_info.semaphoreType =
&#160;&#160;&#160;&#160;VK_SEMAPHORE_TYPE_TIMELINE;
semaphore_info.pNext = &semaphore_type_info;
Finally, we call the create function:
vkCreateSemaphore( vulkan_device, &semaphore_info,
&#160;&#160;&#160;&#160;vulkan_allocation_callbacks, &vulkan_timeline_semaphore );
```


This is it! We now have a timeline semaphore that can be used in our renderer. 下一节将look at a few examples of how to use this type of semaphore.

## Waiting for a timeline semaphore on the CPU


As mentioned previously, we can wait for a timeline semaphore to be signaled on the CPU. The following code does just that:

```
u64 timeline_value = …;

VkSemaphoreWaitInfo semaphore_wait_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO };
semaphore_wait_info.semaphoreCount = 1;
semaphore_wait_info.pSemaphores =
&#160;&#160;&#160;&#160;&vulkan_timeline_semaphore;
semaphore_wait_info.pValues = &timeline_value;

vkWaitSemaphores( vulkan_device, &semaphore_wait_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;timeout );
```


As you probably noticed, it’s possible to wait for multiple semaphores at once and specify a different value for each semaphore. This could be useful, for instance, when rendering to multiple windows, and each window uses a different semaphore. The **VkSemaphoreWaitInfo** structure also has a **flags** field.

Using the **VK_SEMAPHORE_WAIT_ANY_BIT** value in this field will terminate the wait as soon as one of the semaphores reaches the value we are waiting for. Otherwise, the wait will terminate only when all semaphores have reached their respective value.

The last important aspect of the preceding code is the timeout value. This value is specified in nanoseconds. If, after the given time, the wait condition is not satisfied, the call will return **VK_TIMEOUT**. We usually set the timeout to infinity, as we absolutely need the semaphore to be signaled.

However, there is a risk that the wait call might never return, for instance, if the combination of wait and signal values leads to a deadlock on the GPU. An alternative approach would be to set the timeout to a relatively large value – 1 second, for example. If the wait is not completed within this time span, there is likely an issue with our submission, and we can communicate the error to the user.

In this section, we have shown how to wait for a timeline semaphore on the CPU. In the next section, we are going to cover how to use a timeline semaphore on the GPU.

## Using a timeline semaphore on the GPU


In this section, we are going to show how to update a timeline semaphore value and how to wait for a given value on the GPU.

说明

Before we begin, we’d like to point out that we are using the **VK_KHR_synchronization2** extension. This extension simplifies writing code for barriers and semaphores. Please refer to the full code to see how this is implemented using the old APIs.

We start by defining the list of semaphores we want to wait for:

```
VkSemaphoreSubmitInfoKHR wait_semaphores[]{
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_image_acquired_semaphore, 0,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;0 },
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_timeline_semaphore, absolute_frame - (
&#160;&#160;&#160;&#160;&#160;&#160;&#160;k_max_frames - 1 ),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR , 0 }
};
```


This list can contain both standard semaphores and timeline semaphores. For standard semaphores, the **signal** value is ignored.

Similarly, we need to define a list of semaphores to wait on:

```
VkSemaphoreSubmitInfoKHR signal_semaphores[]{
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;*render_complete_semaphore, 0,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;0 },
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_timeline_semaphore, absolute_frame + 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR
&#160;&#160;&#160;&#160;&#160;&#160;&#160;, 0 }
};
```


As before, we can use different semaphore types and the signal value is ignored for standard semaphores. It’s important the signal value for a timeline semaphore is always increased. If we were to submit the same value twice or a smaller value, we would get a validation error.

We also need to be careful with the values we use for waiting and signaling. If we were to wait for a value that is set within the same submission, we would deadlock the GPU. As a rule of thumb, always try to use a value that is guaranteed to have been set by a previous submission. The validation layers will also help you catch this type of error.

The last step is to pass the two lists to the submit info structure:

```
VkSubmitInfo2KHR submit_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_SUBMIT_INFO_2_KHR };
submit_info.waitSemaphoreInfoCount = 2;
submit_info.pWaitSemaphoreInfos = wait_semaphores;
submit_info.commandBufferInfoCount =
&#160;&#160;&#160;&#160;num_queued_command_buffers;
submit_info.pCommandBufferInfos = command_buffer_info;
submit_info.signalSemaphoreInfoCount = 2;
submit_info.pSignalSemaphoreInfos = signal_semaphores;

queue_submit2( vulkan_main_queue, 1, &submit_info,
&#160;&#160;&#160;&#160;VK_NULL_HANDLE );
```


As you probably noticed, we can now wait for and signal the same timeline semaphore in a submission. We also no longer need a fence. This greatly simplifies the code and reduces the number of synchronization objects needed.

In this section, we have shown how to enable the extension to use timeline semaphores and how to create and use them to wait on the CPU. Finally, we have shown how to wait and signal timeline semaphores on the GPU.

In the next section, we are going to use this newly acquired knowledge to add a separate queue for async compute work.

# Adding a separate queue for async compute


In this section, we are going to illustrate how to use separate queues for graphics and compute work to make full use of our GPU. Modern GPUs have many generic compute units that can be used both for graphics and compute work. Depending on the workload for a given frame (shader complexity, screen resolution, dependencies between rendering passes, and so on), it’s possible that the GPU might not be fully utilized.

Moving some of the computation done on the CPU to the GPU using compute shaders can increase performance and lead to better GPU utilization. This is possible because the GPU scheduler can determine if any of the compute units are idle and assign work to them to overlap existing work:



 ![Figure 5.3 – Top: graphics workload is not fully utilizing the GPU; Bottom: compute workload can take advantage of unused resources for optimal GPU utilization](image/B18395_05_03.jpg)


Figure 5.3 – Top: graphics workload is not fully utilizing the GPU; Bottom: compute workload can take advantage of unused resources for optimal GPU utilization

In the remainder of this section, we are going to demonstrate how to use the timeline semaphore introduced in the previous section to synchronize access to data between the two queues.

## Submitting work on separate queues


We have already set up multiple queues in [*Chapter 3*](B18395_03.xhtml#_idTextAnchor045), *Unlocking Multi-Threading*. We now need to ensure that access to data from two queues is correctly synchronized; otherwise, we might access data that is out of date or, worse, data that hasn’t been initialized yet.

The first step in this process is to create a separate command buffer. A different command buffer must be used for compute work, as the same command buffer can’t be submitted to different queues. This is easily achieved by requesting a new command buffer from our **GpuDevice** implementation:

```
CommandBuffer* cb = gpu.get_command_buffer( 0,
gpu.current_frame, true );
```


Next, we need to create a new timeline semaphore to be used by the compute queue. This is the same code we have shown in the previous section, and we won’t be duplicating it here.

We then need to increment the value of our timeline semaphore with each compute submission:

```
bool has_wait_semaphore = last_compute_semaphore_value > 0;
VkSemaphoreSubmitInfoKHR wait_semaphores[]{
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_compute_semaphore,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;last_compute_semaphore_value,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT_KHR, 0 }
};

last_compute_semaphore_value++;

VkSemaphoreSubmitInfoKHR signal_semaphores[]{
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_compute_semaphore,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;last_compute_semaphore_value,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT_KHR, 0 },
};
```


This code is similar to the code we showed before in relation to submitting timeline semaphores. The main difference is the wait stage, which must now be **VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT_KHR**. Now that we have the list of wait and signal semaphores, they are ready to be used for our submission:

```
VkCommandBufferSubmitInfoKHR command_buffer_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO_KHR };
command_buffer_info.commandBuffer =
&#160;&#160;&#160;&#160;command_buffer->vk_command_buffer;

VkSubmitInfo2KHR submit_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_SUBMIT_INFO_2_KHR };
submit_info.waitSemaphoreInfoCount =
&#160;&#160;&#160;&#160;has_wait_semaphore ? 1 : 0;
submit_info.pWaitSemaphoreInfos = wait_semaphores;
submit_info.commandBufferInfoCount = 1;
submit_info.signalSemaphoreInfoCount = 1;
submit_info.pSignalSemaphoreInfos = signal_semaphores;

queue_submit2( vulkan_compute_queue, 1, &submit_info,
&#160;&#160;&#160;&#160;VK_NULL_HANDLE );
```


Again, this should be familiar code. We want to highlight that we only add the wait semaphore after the first submission. If we were to wait for the semaphore on the first submission, we would deadlock the GPU, as the semaphore will never be signaled. Luckily, the validation layers will highlight this problem, and it can be easily corrected.

Now that we have submitted our compute workload, we need to make sure the graphics queue waits until the data is ready. We can achieve this by adding the compute semaphore to the list of wait semaphores when submitting the graphics queue. We are going to highlight only the new code:

```
bool wait_for_compute_semaphore = (
&#160;&#160;&#160;&#160;last_compute_semaphore_value > 0 ) && has_async_work;
VkSemaphoreSubmitInfoKHR wait_semaphores[]{
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_image_acquired_semaphore, 0,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;0 },
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_compute_semaphore,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;last_compute_semaphore_value,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_VERTEX_ATTRIBUTE_INPUT_BIT_KHR,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;0 },
&#160;&#160;&#160;&#160;{ VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO_KHR, nullptr,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_graphics_semaphore,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;absolute_frame - ( k_max_frames - 1 ),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR , 0 },
};
```


The same care must be taken when adding the compute semaphore to the list. We want to wait only if at least one compute submission has been performed. For some frames, we might not have any compute work pending. We don’t want to wait for the compute semaphore in this case, either.

In our case, we have set the wait stage to **VK_PIPELINE_STAGE_2_VERTEX_ATTRIBUTE_INPUT_BIT_KHR**, as we are modifying the vertices of our mesh. This will need adjusting if, for instance, you are using the compute queue to update a texture that won’t be used until the fragment shader stage. Using the right wait stage is important to obtain the best performance.

In this section, we have demonstrated how to retrieve a separate queue for compute work. We then explained how to use the newly created queue to submit compute work and correctly synchronize data access from different queues to ensure correct results.

In the next section, we are going to show a concrete example by implementing a simple cloth simulation using compute shaders.

# Implementing cloth simulation using async compute


In this section, we are going to implement a simple cloth simulation on the GPU as an example use case of a compute workload. We start by explaining why running some tasks on the GPU might be beneficial. Next, we provide an overview of compute shaders. Finally, we show how to port code from the CPU to the GPU and highlight some of the differences between the two platforms.

## Benefits of using compute shaders


In the past, physics simulations mainly ran on the CPU. GPUs only had enough compute capacity for graphics work, and most stages in the pipeline were implemented by dedicated hardware blocks that could only perform one task. As GPUs evolved, pipeline stages moved to generic compute blocks that could perform different tasks.

This increase both in flexibility and compute capacity has allowed engine developers to move some workloads on the GPU. Aside from raw performance, running some computations on the GPU avoids expensive copies from CPU memory to GPU memory. Memory speed hasn’t evolved as fast as processor speed, and moving data as little as possible between devices is key to application performance.

In our example, the cloth simulation has to update the position of all vertices and copy the updated data to the GPU. Depending on the size of the mesh and the number of meshes to update, this could amount to a significant percentage of frame time.

These workloads can also scale better on the GPU, as we can update a larger number of meshes in parallel.

We are now going to provide an overview of how compute shaders are executed. If you are familiar with compute shaders or have worked with CUDA or OpenCL before, feel free to skim the next section.

## Compute shaders overview


The GPU execution model is called **Single Instruction, Multiple Threads** (**SIMT**). It is similar to the **Single Instruction, Multiple Data** (**SIMD**) offered by modern CPUs to operate on multiple data entries with a single instruction.

However, GPUs operate on a larger number of data points within a single instruction. The other main difference is that each thread on the GPU is more flexible compared to a SIMD instruction. GPU architecture is a fascinating topic, but its scope is outside this book. We will provide references for further reading at the end of the chapter.

说明

A group of threads has different names depending on the GPU vendor. You might see the term warp or wave being mentioned in their documentation. We are going to use thread group to avoid confusion.

Each compute shader invocation can use multiple threads within a compute unit, and it’s possible to control how many threads are used. In Vulkan, this is achieved with the following directive inside a compute shader:

```
layout (local_size_x = 8, local_size_y = 8,
local_size_z = 1) in;
```


This defines the local group size; we are going to explain what it does in just a moment. For now, the main point is that we are telling the GPU that we want to execute 64 threads (8x8). Each GPU has an optimal thread group size. You should check the documentation from each vendor and, if possible, adjust the thread group size for optimal performance.

We also have to define a global group size when invoking a compute shader:

```
gpu_commands->dispatch( ceilu32( renderer->
&#160;&#160;&#160;&#160;gpu->swapchain_width * 1.f / 8 ),
&#160;&#160;&#160;&#160;&#160;&#160;ceilu32( renderer->gpu->swapchain_height * 1.f / 8 ),
&#160;&#160;&#160;&#160;&#160;&#160;1 );
```


This code is taken from our lighting pass implementation. In this case, we want to process all the pixels in our render target texture. As you probably noticed, we divide the size by 8. This is needed to ensure we don’t process the same pixel multiple times. Let’s walk through an example to clarify how the local and global group size works.

Let’s say our render target is 1280x720. Multiplying the width by the height will give us the total number of pixels in the image. When we define the local group size, we determine how many pixels are going to be processed by each shader invocation (again, 64 in our case). The number of shader invocations is computed as follows:

```
shader_invocation_count = total_pixels / 64
```


The **dispatch** command requires three values, though, as both the local and global group size are defined as a vector of three values. This is why we divide each dimension by **8**:

```
global_group_size_x = width / 8
global_group_size_y = height / 8
```


Since we are operating on a 2D texture, we are not modifying the **z** value. We can verify that we are processing the right number of pixels with this code:

```
local_thread_group_count = 64
shader_invocation_count = global_group_size_x *
&#160;&#160;&#160;&#160;global_group_size_y
total_pixels =&#160;&#160;shader_invocation_count *
&#160;&#160;&#160;&#160;local_thread_group_count
```


We can determine which invocation is being run inside the shader by using this variable provided by GLSL:

```
ivec3 pos = ivec3( gl_GlobalInvocationID.xyz );
```


Each thread will see a unique position value, which we can use to access our texture.

This was only a brief overview of the compute shader execution model. We are going to provide more in-depth resources in the *Further **reading* section.

Now that we have a better understanding of how compute shaders are executed, we are going to demonstrate how to convert CPU code to a GPU compute shader.

## Writing compute shaders


Writing code for compute shaders is similar to writing vertex or fragment shaders. The main difference is that we have more flexibility in compute shaders to define which data to access. For instance, in vertex shaders, we usually access a single entry in an attribute buffer. The same applies to fragment shaders, where the fragment being shaded by a shader invocation is determined by the GPU.

Because of the added flexibility, we also need to think more carefully about our access patterns and synchronization between threads. If, for instance, more than one thread has to write to the same memory location, we need to add memory barriers to ensure previous writes to that memory have completed and all threads see the correct value. In pseudo-code, this translates to this:

```
// code
MemoryBarrier()
// all threads have run the code before the barrier
```


GLSL also provides atomic operations in case the same memory location has to be accessed across shader invocations.

With that in mind, let’s have a look at the pseudo-code for the CPU version of the cloth simulation:

```
for each physics mesh in the scene:
&#160;&#160;&#160;&#160;for each vertex in the mesh:
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;compute the force applied to the vertex
&#160;&#160;&#160;&#160;// We need two loops because each vertex references
&#160;&#160;&#160;&#160;&#160;&#160;&#160;other vertices position
&#160;&#160;&#160;&#160;// First we need to compute the force applied to each
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vertex,
&#160;&#160;&#160;&#160;// and only after update each vertex position
&#160;&#160;&#160;&#160;&#160;&#160;&#160;for each vertex in the mesh:
&#160;&#160;&#160;&#160;update the vertex position and store its velocity

&#160;&#160;&#160;&#160;update the mesh normals and tangents
&#160;&#160;&#160;&#160;copy the vertices to the GPU
```


We used a common spring model for the cloth simulation, but its implementation is outside the scope of this chapter. We suggest looking at the code for more detail, and we also reference the paper we used in the *Further **reading* section.

As you notice, at the end of the loop, we have to copy the updated vertex, normal, and tangent buffers to the GPU. Depending on the number of meshes and their complexity, this could be a costly operation. This step could be even more costly if the cloth simulation were to rely on data from other systems that run on the GPU.

If, for instance, the animation system runs on the GPU while the cloth simulation runs on the CPU, we now have two copies to perform, in addition to extra synchronization points in the pipeline. For these reasons, it can be beneficial to move the cloth simulation to the GPU.

Let’s start by looking at the vertex buffer setup:

```
BufferCreation creation{ };
sizet buffer_size = positions.size * sizeof( vec3s );
creation.set( flags, ResourceUsageType::Immutable,
&#160;&#160;&#160;&#160;buffer_size ).set_data( positions.data )
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.set_name( nullptr ).set_persistent( true );

BufferResource* cpu_buffer = renderer->
&#160;&#160;&#160;&#160;create_buffer( creation );
cpu_buffers.push( *cpu_buffer );
```


This is the only buffer we needed before. Because we had to update the data on the CPU, we could only use a host coherent buffer so that write on the CPU would be visible on the CPU. Using this type of buffer has performance implications on the GPU, as this type of memory can be slower to access, especially when the buffer size is large.

Since we are now going to perform the update on the GPU, we can use a buffer that is marked as **device_only**. This is how we create the buffer:

```
creation.reset().set( flags, ResourceUsageType::Immutable,
&#160;&#160;&#160;&#160;buffer_size ).set_device_only( true )
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.set_name( "position_attribute_buffer" );

BufferResource* gpu_buffer = renderer->
&#160;&#160;&#160;&#160;create_buffer( creation );
gpu_buffers.push( *gpu_buffer );
```


Finally, we copy the data from the CPU to the GPU only once. After the copy is done, we can free the CPU buffer:

```
async_loader->request_buffer_copy( cpu_buffer->handle,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gpu_buffer->handle );
```


We have shown an example of the position buffer. All the other buffers (normal, tangent, texture coordinates, and indices) are managed in the same way.

Now that we have our buffers, we need to create a descriptor set that will be used by our compute shader:

```
DescriptorSetLayoutHandle physics_layout = renderer->
&#160;&#160;&#160;&#160;gpu->get_descriptor_set_layout
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;( cloth_technique->passes[ 0 ].pipeline,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;k_material_descriptor_set_index );
ds_creation.reset().buffer( physics_cb, 0 )
&#160;&#160;&#160;&#160;.buffer( mesh.physics_mesh->gpu_buffer, 1 )
&#160;&#160;&#160;&#160;.buffer( mesh.position_buffer, 2 )
&#160;&#160;&#160;&#160;.buffer( mesh.normal_buffer, 3 )
&#160;&#160;&#160;&#160;.buffer( mesh.index_buffer, 4 )
&#160;&#160;&#160;&#160;.set_layout( physics_layout );

mesh.physics_mesh->descriptor_set = renderer->
&#160;&#160;&#160;&#160;gpu->create_descriptor_set( ds_creation );
```


We can match the binding of the preceding buffers with the following shader code:

```
layout ( std140, set = MATERIAL_SET, binding = 0 ) uniform
&#160;&#160;&#160;&#160;PhysicsData {
&#160;&#160;&#160;&#160;...
};

layout ( set = MATERIAL_SET, binding = 1 ) buffer
&#160;&#160;&#160;&#160;PhysicsMesh {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint index_count;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint vertex_count;

&#160;&#160;&#160;&#160;PhysicsVertex physics_vertices[];
};

layout ( set = MATERIAL_SET, binding = 2 ) buffer
&#160;&#160;&#160;&#160;PositionData {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float positions[];
};

layout ( set = MATERIAL_SET, binding = 3 ) buffer
&#160;&#160;&#160;&#160;NormalData {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float normals[];
};

layout ( set = MATERIAL_SET, binding = 4 ) readonly buffer
&#160;&#160;&#160;&#160;IndexData {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint indices[];
};
```


It’s important to notice a couple of points. Because we don’t know the size of each buffer at runtime, we have to use separate storage blocks. We can only have one runtime array per storage block, and it must be the last member of the block.

We also have to use float arrays instead of **vec3** arrays; otherwise, each entry in the vector would be padded to 16 bytes and the data on the GPU will no longer match the data layout on the CPU. We could use **vec4** as type, but we would be wasting 4 bytes for each vertex. When you have millions, if not billions, of vertices, it adds up!

Finally, we marked the **IndexData** block as **readonly**. This is because we never modify the index buffer in this shader. It’s important to mark each block with the right attributes as this will give more opportunities for optimization to the shader compiler.

We could reduce the number of blocks by arranging our data differently, for example:

```
struct MeshVertex {
&#160;&#160;&#160;&#160;vec3 position;
&#160;&#160;&#160;&#160;vec3 normal;
&#160;&#160;&#160;&#160;vec3 tangent;
};

layout ( set = MATERIAL_SET, binding = 2 ) buffer MeshData {
&#160;&#160;&#160;&#160;MeshVertex mesh_vertices[];
};
```


This solution is usually referred to as **Array of Structures** (**AoS**), while the code we presented before used **Structure of Arrays** (**SoA**). While the AoS solution simplifies the bindings, it also makes it impossible to use each array individually. In our depth pass, for instance, we only need the positions. For this reason, we preferred the SoA approach.

We have already shown how to dispatch a compute shader and how to synchronize access between the compute and graphics queue, so we won’t repeat that code here. We can now move to the shader implementation. We are only going to show the relevant section; you can refer to the code for the full listing.

We start by computing the force applied to each vertex:

```
vec3 spring_force = vec3( 0, 0, 0 );

for ( uint j = 0; j < physics_vertices[ v ]
&#160;&#160;&#160;&#160;.joint_count; ++j ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pull_direction = ...;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;spring_force += pull_direction;
}

vec3 viscous_damping = physics_vertices[ v ]
&#160;&#160;&#160;&#160;.velocity * -spring_damping;

vec3 viscous_velocity = ...;

vec3 force = g * m;
force -= spring_force;
force += viscous_damping;
force += viscous_velocity;

physics_vertices[ v ].force = force;
```


Notice how we access the **physics_vertices** array each time. In the CPU code, we could simply get a reference to the struct, and each field would be updated correctly. However, GLSL doesn’t support references, so we need to be really careful that we are not writing to a local variable.

As in the CPU code, after computing the force vector for each vertex, we need to update its position:

```
vec3 previous_position = physics_vertices[ v ]
&#160;&#160;&#160;&#160;.previous_position;
vec3 current_position = physics_vertices[ v ].position;

vec3 new_position = ...;

physics_vertices[ v ].position = new_position;
physics_vertices[ v ].previous_position = current_position;

physics_vertices[ v ].velocity = new_position - current_position;
```


Again, notice that we always read from the buffer each time. Finally, we update the vertex positions of the mesh:

```
for ( uint v = 0; v < vertex_count; ++v ) {
&#160;&#160;&#160;&#160;&#160;positions[ v * 3 + 0 ] = physics_vertices[ v ]
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.position.x;
&#160;&#160;&#160;&#160;&#160;positions[ v * 3 + 1 ] = physics_vertices[ v ]
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.position.y;
&#160;&#160;&#160;&#160;&#160;positions[ v * 3 + 2 ] = physics_vertices[ v ]
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.position.z;
}
```


Because this is all performed on the GPU, the positions could have been updated first by another system, such as animation, but we no longer need costly copy operations to and from the GPU.

Before we conclude, we’d like to point out that we have one shader invocation per mesh and that performance is achieved by updating the cloth simulation for multiple meshes in the same dispatch. Another approach could have been to have one dispatch per mesh where each shader invocation updates an individual vertex.

While technically a valid approach, it requires a lot more synchronization within the thread group and across shader invocations. As we mentioned, we first have to compute the force for each vertex before updating their position. Another solution could be to split the update into two shaders, one that computes the force and a second one that updates the positions.

This still requires pipeline barriers between each shader dispatch. While the GPU must guarantee that each command is executed in the same order it has been recorded; it doesn’t guarantee the order of completion. For these reasons, we have decided to use one thread per mesh.

In this section, we have explained the execution model of compute shaders and the benefits of running selected computations on the GPU to improve performance and avoid extra memory copies. We then demonstrated how to port code written for the CPU to the GPU and some of the aspects we need to pay attention to when working with compute shaders.

We suggest looking at the code for more details. Try to make changes to the cloth simulation to implement a different simulation technique or add your own compute shaders to the engine!

# 小结
In this chapter, we have built the foundations to support compute shaders in our renderer. We started by introducing timeline semaphores and how they can be used to replace multiple semaphores and fences. We have shown how to wait for a timeline semaphore on the CPU and how a timeline semaphore can be used as part of a queue submission, either for it to be signaled or to be waited on.

Next, we demonstrated how to use the newly introduced timeline semaphore to synchronize execution across the graphics and compute queue.

In the last section, we showed an example of how to approach porting code written for the CPU to the GPU. We first explained some of the benefits of running computations on the GPU. Next, we gave an overview of the execution model for compute shaders and the configuration of local and global workgroup sizes. Finally, we gave a concrete example of a compute shader for cloth simulation and highlighted the main differences with the same code written for the CPU.

In the next chapter, we are going to improve our pipeline by adding mesh shaders, and for the devices that don’t support them, we are going to write a compute shader alternative.

# 延伸阅读
Synchronization is likely one of the most complex aspects of Vulkan. We have mentioned some of the concepts in this and previous chapters. If you want to improve your understanding, we suggest reading the following resources:

- [https://www.khronos.org/registry/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization](https://www.khronos.org/registry/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization)


- [https://www.khronos.org/blog/understanding-vulkan-synchronization](https://www.khronos.org/blog/understanding-vulkan-synchronization)


- [https://github.com/KhronosGroup/Vulkan-Docs/wiki/Synchronization-Examples](https://github.com/KhronosGroup/Vulkan-Docs/wiki/Synchronization-Examples)




We only touched the surface when it comes to compute shaders. The following resources go more in depth and also provide suggestions to get the most out of individual devices:

- [https://www.khronos.org/opengl/wiki/Compute_Shader](https://www.khronos.org/opengl/wiki/Compute_Shader)


- [https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#programming-model](https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#programming-model)


- [https://github.com/KhronosGroup/OpenCL-Guide/blob/main/chapters/opencl_programming_model.md](https://github.com/KhronosGroup/OpenCL-Guide/blob/main/chapters/opencl_programming_model.md)




Real-time cloth simulation for computer graphics has been a subject of study for many years. We have based our implementation on this paper: [http://graphics.stanford.edu/courses/cs468-02-winter/Papers/Rigidcloth.pdf](http://graphics.stanford.edu/courses/cs468-02-winter/Papers/Rigidcloth.pdf).

Another popular approach is presented in this paper: [http://www.cs.cmu.edu/~baraff/papers/sig98.pdf](http://www.cs.cmu.edu/~baraff/papers/sig98.pdf).

Finally, this GDC talk gave us the idea of using cloth simulation to demonstrate how to use compute shaders:

[https://www.gdcvault.com/play/1022350/Ubisoft-Cloth-Simulation-Performance-Postmortem](https://www.gdcvault.com/play/1022350/Ubisoft-Cloth-Simulation-Performance-Postmortem)