# Chapter 3: Unlocking Multi-Threading

# 3



# Unlocking Multi-Threading


In this chapter, we will talk about adding multi-threading to the Raptor Engine.

This requires both a big change in the underlying architecture and some Vulkan-specific changes and synchronization work so that the different cores of the CPU and the GPU can cooperate in the most correct and the fastest way.

**Multi-threading** rendering is a topic covered many times over the years and a feature that most game engines have needed since the era of multi-core architectures exploded. Consoles such as the PlayStation 2 and the Sega Saturn already offered multi-threading support, and later generations continued the trend by providing an increasing number of cores that developers could take advantage of.

The first trace of multi-threading rendering in a game engine is as far back as 2008 when Christer Ericson wrote a blog post ([https://realtimecollisiondetection.net/blog/?p=86](https://realtimecollisiondetection.net/blog/?p=86)) and showed that it was possible to parallelize and optimize the generation of commands used to render objects on the screen.

Older APIs such as OpenGL and DirectX (up until version 11) did not have proper multi-threading support, especially because they were big state machines with a global context tracking down each change after each command. Still, the command generation across different objects could take a few milliseconds, so multi-threading was already a big save in performance.

Luckily for us, Vulkan fully supports multi-threading command buffers natively, especially with the creation of the **VkCommandBuffer** class, from an architectural perspective of the Vulkan API.

The Raptor Engine, up until now, was a single-threaded application and thus required some architectural changes to fully support multi-threading. In this chapter, we will see those changes, learn how to use a task-based multi-threading library called enkiTS, and then unlock both asynchronous resource loading and multi-threading command recording.

本章将涉及以下主题：

- How to use a task-based multi-threading library


- How to asynchronously load resources


- How to draw in parallel threads




学完本章后，我们将know how to run concurrent tasks both for loading resources and drawing objects on the screen. By learning how to reason with a task-based multi-threading system, we will be able to perform other parallel tasks in future chapters as well.

# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter3](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter3).

# Task-based multi-threading using enkiTS


To achieve parallelism, we need to understand some basic concepts and choices that led to the architecture developed in this chapter. First, we should note that when we talk about parallelism in software engineering, we mean the act of executing chunks of code at the same time.

This is possible because modern hardware has different units that can be operated independently, and operating systems have dedicated execution units called **threads**.

A common way to achieve parallelism is to reason with tasks – small independent execution units that can run on any thread.

## Why task-based parallelism?


Multi-threading is not a new subject, and since the early years of it being added to various game engines, there have been different ways of implementing it. Game engines are pieces of software that use all of the hardware available in the most efficient way, thus paving the way for more optimized software architectures.

Therefore, we’ll take some ideas from game engines and gaming-related presentations. The initial implementations started by adding a thread with a single job to do – something specific, such as rendering a single thread, an asynchronous **input/output** (**I/O**) thread, and so on.

This helped add more granularity to what could be done in parallel, and it was perfect for the older CPUs (having two cores only), but it soon became limiting.

There was the need to use cores in a more agnostic way so that any type of job could be done by almost any core and to improve performance. This gave way to the emergence of two new architectures: **task-based** and **fiber-based** architectures.

Task-based parallelism is achieved by feeding multiple threads with different tasks and orchestrating them through dependencies. Tasks are inherently platform agnostic and cannot be interrupted, leading to a more straightforward capability to schedule and organize code to be executed with them.

On the other hand, fibers are software constructs similar to tasks, but they rely heavily on the scheduler to interrupt their flow and resume when needed. This main difference makes it hard to write a proper fiber system and normally leads to a lot of subtle errors.

For the simplicity of using tasks over fibers and the bigger availability of libraries implementing task-based parallelism, the enkiTS library was chosen to handle everything. For those curious about more in-depth explanations, there are a couple of great presentations about these architectures.

A great example of a task-based engine is the one behind the Destiny franchise (with an in-depth architecture you can view at [https://www.gdcvault.com/play/1021926/Destiny-s-Multithreaded-Rendering](https://www.gdcvault.com/play/1021926/Destiny-s-Multithreaded-Rendering)), while a fiber-based one is used by the game studio Naughty Dog for their games (there is a presentation about it at [https://www.gdcvault.com/play/1022186/Parallelizing-the-Naughty-Dog-Engine](https://www.gdcvault.com/play/1022186/Parallelizing-the-Naughty-Dog-Engine)).

## Using the enkiTS (Task-Scheduler) library


Task-based multi-threading is based on the concept of a task, defined as a *unit of independent work that can be executed on any core of **a CPU*.

To do that, there is a need for a scheduler to coordinate different tasks and take care of the possible dependencies between them. Another interesting aspect of a task is that it could have one or more dependencies so that it could be scheduled to run only after certain tasks finish their execution.

This means that tasks can be submitted to the scheduler at any time, and with proper dependencies, we create a graph-based execution of the engine. If done properly, each core can be utilized fully and results in optimal performance to the engine.

The scheduler is the brain behind all the tasks: it checks dependencies and priorities, and schedules or removes tasks based on need, and it is a new system added to the Raptor Engine.

When initializing the scheduler, the library spawns a number of threads, each waiting to execute a task. When adding tasks to the scheduler, they are inserted into a queue. When the scheduler is told to execute pending tasks, each thread gets the next available task from the queue – according to dependency and priority – and executes it.

It’s important to note that running tasks can spawn other tasks. These tasks will be added to the thread’s local queue, but they are up for grabs if another thread is idle. This implementation is called a **work-stealing queue**.

Initializing the scheduler is as simple as creating a configuration and calling the **Initialize** method:

```
enki::TaskSchedulerConfig config;
config.numTaskThreadsToCreate = 4;
enki::TaskScheduler task_scheduler;
task_scheduler.Initialize( config );
```


With this code, we are telling the task scheduler to spawn four threads that it will use to perform its duties. enkiTS uses the **TaskSet** class as a unit of work, and it uses both inheritance and lambda functions to drive the execution of tasks in the scheduler:

```
Struct ParallelTaskSet : enki::ItaskSet {
&#160;&#160;&#160;&#160;void ExecuteRange(&#160;&#160;enki::TaskSetPartition range_,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uint32_t threadnum_ ) override {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// do something here, can issue tasks with
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;task_scheduler
&#160;&#160;&#160;&#160;}
};
int main(int argc, const char * argv[]) {
&#160;&#160;&#160;&#160;enki::TaskScheduler task_scheduler;
&#160;&#160;&#160;&#160;task_scheduler.Initialize( config );
&#160;&#160;&#160;&#160;ParallelTaskSet task; // default constructor has a set
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;size of 1
&#160;&#160;&#160;&#160;task_scheduler.AddTaskSetToPipe( &task );
&#160;&#160;&#160;&#160;// wait for task set (running tasks if they exist)
&#160;&#160;&#160;&#160;// since we&apos;ve just added it and it has no range we&apos;ll
&#160;&#160;&#160;&#160;&#160;&#160;&#160;likely run it.
&#160;&#160;&#160;&#160;Task_scheduler.WaitforTask( &task );
&#160;&#160;&#160;&#160;return 0;
}
```


In this simple snippet, we see how to create an empty **TaskSet** (as the name implies, a set of tasks) that defines how a task will execute the code, leaving the scheduler with the job of deciding how many of the tasks will be needed and which thread will be used.

A more streamlined version of the previous code uses lambda functions:

```
enki::TaskSet task( 1, []( enki::TaskSetPartition range_,
&#160;&#160;uint32_t threadnum_&#160;&#160;) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// do something here
&#160;&#160;}&#160;&#160;);
task_scheduler.AddTaskSetToPipe( &task );
```


This version can be easier when reading the code as it does break the flow less, but it is functionally equivalent to the previous one.

Another feature of the enkiTS scheduler is the possibility to add pinned tasks – special tasks that will be bound to a thread and will always be executed there. We will see the use of pinned tasks in the next section to perform asynchronous I/O operations.

In this section, we talked briefly about the different types of multi-threading so that we could express the reason for choosing to use task-based multi-threading. We then showed some simple examples of the enkiTS library and its usage, adding multi-threading capabilities to the Raptor Engine.

下一节将finally see a real use case in the engine, which is the asynchronous loading of resources.

# Asynchronous loading


The loading of resources is one of the (if not *the*) slowest operations that can be done in any framework. This is because the files to be loaded are big, and they can come from different sources, such as optical units (DVD and Blu-ray), hard drives, and even the network.

It is another great topic, but the most important concept to understand is the inherent speed necessary to read the memory:



 ![Figure 3.1 – A memory hierarchy](image/B18395_03_01.jpg)


Figure 3.1 – A memory hierarchy

As shown in the preceding diagram, the fastest memory is the registers memory. After registers follows the cache, with different levels and access speeds: both registers and caches are directly in the processing unit (both the CPU and GPU have registers and caches, even with different underlying architectures).

Main memory refers to the RAM, which is the area that is normally populated with the data used by the application. It is slower than the cache, but it is the target of the loading operations as the only one directly accessible from the code. Then there are magnetic disks (hard drives) and optical drives – much slower but with greater capacity. They normally contain the asset data that will be loaded into the main memory.

The final memory is in remote storage, such as from some servers, and it is the slowest. We will not deal with that here, but it can be used when working on applications that have some form of online service, such as multiplayer games.

With the objective of optimizing the read access in an application, we want to transfer all the needed data into the main memory, as we can’t interact with caches and registers. To hide the slow speed of magnetic and optical disks, one of the most important things that can be done is to parallelize the loading of any resource coming from any medium so that the fluidity of the application is not slowed down.

The most common way of doing it, and one example of the thread-specialization architecture we talked briefly about before, is to have a separate thread that handles just the loading of resources and interacts with other systems to update the used resources in the engine.

在以下各节中，我们将talk about how to set up enkiTS and create tasks for parallelizing the Raptor Engine, as well as talk about Vulkan queues, which are necessary for parallel command submission. Finally, we will dwell on the actual code used for asynchronous loading.

## Creating the I/O thread and tasks


In the enkiTS library, there is a feature called **pinned-task** that associates a task to a specific thread so that it is continuously running there unless stopped by the user or a higher priority task is scheduled on that thread.

To simplify things, we will add a new thread and avoid it being used by the application. This thread will be mostly idle, so the context switch should be low:

```
config.numTaskThreadsToCreate = 4;
```


We then create a pinned task and associate it with a thread ID:

```
// Create IO threads at the end
RunPinnedTaskLoopTask run_pinned_task;
run_pinned_task.threadNum = task_scheduler.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;GetNumTaskThreads() - 1;
task_scheduler.AddPinnedTask( &run_pinned_task );
```


At this point, we can create the actual task responsible for asynchronous loading, associating it with the same thread as the pinned task:

```
// Send async load task to external thread
AsynchronousLoadTask async_load_task;
async_load_task.threadNum = run_pinned_task.threadNum;
task_scheduler.AddPinnedTask( &async_load_task );
```


The final piece of the puzzle is the actual code for these two tasks. First, let us have a look at the first pinned task:

```
struct RunPinnedTaskLoopTask : enki::IPinnedTask {
&#160;&#160;&#160;&#160;void Execute() override {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;while ( task_scheduler->GetIsRunning() && execute )
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;task_scheduler->WaitForNewPinnedTasks();
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// this thread will &apos;sleep&apos; until there are new
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pinned tasks
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;task_scheduler->RunPinnedTasks();
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;enki::TaskScheduler*task_scheduler;
&#160;&#160;&#160;&#160;bool execute = true;
}; // struct RunPinnedTaskLoopTask
```


This task will wait for any other pinned task and run them when possible. We have added an **execute** flag to stop the execution when needed, for example, when exiting the application, but it could be used in general to suspend it in other situations (such as when the application is minimized).

The other task is the one executing the asynchronous loading using the **AsynchronousLoader** class:

```
struct AsynchronousLoadTask : enki::IPinnedTask {
&#160;&#160;&#160;&#160;void Execute() override {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;while ( execute ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;async_loader->update();
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;AsynchronousLoader*async_loader;
&#160;&#160;&#160;&#160;enki::TaskScheduler*task_scheduler;
&#160;&#160;&#160;&#160;bool execute = true;
}; // struct AsynchronousLoadTask
```


The idea behind this task is to always be active and wait for requests for resource loading. The **while** loop ensures that the root pinned task never schedules other tasks on this thread, locking it to I/O as intended.

Before moving on to look at the **AsynchronousLoader** class, we need to look at an important concept in Vulkan, namely queues, and why they are a great addition for asynchronous loading.

## Vulkan queues and the first parallel command generation


The concept of a *queue* – which can be defined as the entry point to submit commands recorded in **VkCommandBuffers** to the GPU – is an addition to Vulkan compared to OpenGL and needs to be taken care of.

Submission using a queue is a single-threaded operation, and a costly operation that becomes a synchronization point between CPU and GPU to be aware of. Normally, there is the main queue to which the engine submits command buffers before presenting the frame. This will send the work to the GPU and create the rendered image intended.

But where there is one queue, there can be more. To enhance parallel execution, we can instead create different *queues* – and use them in different threads instead of the main one.

A more in-depth look at queues can be found at [https://github.com/KhronosGroup/Vulkan-Guide/blob/master/chapters/queues.adoc](https://github.com/KhronosGroup/Vulkan-Guide/blob/master/chapters/queues.adoc), but what we need to know is that each queue can submit certain types of commands, visible through a queue’s flag:

- **VK_QUEUE_GRAPHICS_BIT** can submit all **vkCmdDraw** commands


- **VK_QUEUE_COMPUTE** can submit all **vkCmdDispatch** and **vkCmdTraceRays** (used for ray tracing)


- **VK_QUEUE_TRANSFER** can submit copy commands, such as **vkCmdCopyBuffer**, **vkCmdCopyBufferToImage**, and **vkCmdCopyImageToBuffer**




Each available queue is exposed through a queue family. Each queue family can have multiple capabilities and can expose multiple queues. Here is an example to clarify:

```
{
&#160;&#160;&#160;&#160;"VkQueueFamilyProperties": {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"queueFlags": [
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_GRAPHICS_BIT",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_COMPUTE_BIT",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_TRANSFER_BIT",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_SPARSE_BINDING_BIT"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"queueCount": 1,
&#160;&#160;&#160;&#160;}
},
{
&#160;&#160;&#160;&#160;"VkQueueFamilyProperties": {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"queueFlags": [
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_COMPUTE_BIT",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_TRANSFER_BIT",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_SPARSE_BINDING_BIT"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"queueCount": 2,
&#160;&#160;&#160;&#160;}
},
{
&#160;&#160;&#160;&#160;"VkQueueFamilyProperties": {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"queueFlags": [
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_TRANSFER_BIT",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"VK_QUEUE_SPARSE_BINDING_BIT"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"queueCount": 2,
&#160;&#160;&#160;&#160;}
}
```


The first queue exposes all capabilities, and we only have one of them. The next queue can be used for compute and transfer, and the third one for transfer (we’ll ignore the sparse feature for now). We have two queues for each of these families.

It is guaranteed that on a GPU there will always be at least one queue that can submit all types of commands, and that will be our main queue.

In some GPUs, though, there can be specialized queues that have only the **VK_QUEUE_TRANSFE**R flag activated, which means that they can use **direct memory access** (**DMA**) to speed up the transfer of data between the CPU and the GPU.

One last thing: the Vulkan logical device is responsible for creating and destroying queues – an operation normally done at the startup/shutdown of the application. Let us briefly see the code to query the support for different queues:

```
u32 queue_family_count = 0;
&#160;&#160;&#160;&#160;vkGetPhysicalDeviceQueueFamilyProperties(
&#160;&#160;&#160;&#160;vulkan_physical_device, &queue_family_count, nullptr );
&#160;&#160;&#160;&#160;VkQueueFamilyProperties*queue_families = (
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VkQueueFamilyProperties* )ralloca( sizeof(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VkQueueFamilyProperties ) * queue_family_count,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;temp_allocator );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vkGetPhysicalDeviceQueueFamilyProperties(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_physical_device, &queue_family_count,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;queue_families );
&#160;&#160;&#160;&#160;u32 main_queue_index = u32_max, transfer_queue_index =
&#160;&#160;&#160;&#160;u32_max;
&#160;&#160;&#160;&#160;for ( u32 fi = 0; fi < queue_family_count; ++fi) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VkQueueFamilyProperties queue_family =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;queue_families[ fi ];
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( queue_family.queueCount == 0 ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;continue;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Search for main queue that should be able to do
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;all work (graphics, compute and transfer)
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( (queue_family.queueFlags & (
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT |
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_QUEUE_TRANSFER_BIT )) == (
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT |
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_QUEUE_TRANSFER_BIT ) ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;main_queue_index = fi;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Search for transfer queue
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( ( queue_family.queueFlags &
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_QUEUE_COMPUTE_BIT ) == 0 &&
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(queue_family.queueFlags &
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_QUEUE_TRANSFER_BIT) ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;transfer_queue_index = fi;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
```


As can be seen in the preceding code, we get the list of all queues for the selected GPU, and we check the different bits that identify the types of commands that can be executed there.

In our case, we will save the *main queue* and the *transfer queue*, if it is present on the GPU, and we will save the indices of the *queues* to retrieve the **VkQueue** after the device creation. Some devices don’t expose a separate transfer queue. In this case, we will use the main queue to perform transfer operations, and we need to make sure that access to the queue is correctly synchronized for upload and graphics submissions.

Let’s see how to create the *queues*:

```
// Queue creation
VkDeviceQueueCreateInfo queue_info[ 2 ] = {};
VkDeviceQueueCreateInfo& main_queue = queue_info[ 0 ];
main_queue.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_CREATE_INFO;
main_queue.queueFamilyIndex = main_queue_index;
main_queue.queueCount = 1;
main_queue.pQueuePriorities = queue_priority;
if ( vulkan_transfer_queue_family < queue_family_count ) {
&#160;&#160;&#160;&#160;VkDeviceQueueCreateInfo& transfer_queue_info =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;queue_info[ 1 ];
&#160;&#160;&#160;&#160;transfer_queue_info.sType = VK_STRUCTURE_TYPE
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_DEVICE_QUEUE_CREATE_INFO;
&#160;&#160;&#160;&#160;transfer_queue_info.queueFamilyIndex = transfer_queue
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_index;
transfer_queue_info.queueCount = 1;
transfer_queue_info.pQueuePriorities = queue_priority;
}
VkDeviceCreateInfo device_create_info {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO };
device_create_info.queueCreateInfoCount = vulkan_transfer
&#160;&#160;&#160;&#160;_queue_family < queue_family_count ? 2 : 1;
device_create_info.pQueueCreateInfos = queue_info;
...
result = vkCreateDevice( vulkan_physical_device,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&device_create_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&vulkan_device );
```


As already mentioned, **vkCreateDevice** is the command that creates *queues* by adding **pQueueCreateInfos** in the **VkDeviceCreateInfo** struct.

Once the device is created, we can query for all the queues as follows:

```
// Queue retrieval
// Get main queue
vkGetDeviceQueue( vulkan_device, main_queue_index, 0,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&vulkan_main_queue );
// Get transfer queue if present
if ( vulkan_transfer_queue_family < queue_family_count ) {
&#160;&#160;&#160;&#160;vkGetDeviceQueue( vulkan_device, transfer_queue_index,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;0, &vulkan_transfer_queue );
}
```


At this point, we have both the main and the transfer queues ready to be used to submit work in parallel.

We had a look at how to submit parallel work to copy memory over the GPU without blocking either the GPU or the CPU, and we created a specific class to do that, **AsynchronousLoader**, which we will cover in the next section.

## The AsynchronousLoader class


Here, we’ll finally see the code for the class that implements asynchronous loading.

The **AsynchronousLoader** class has the following responsibilities:

- Process load from file requests


- Process GPU upload transfers


- Manage a staging buffer to handle a copy of the data


- Enqueue the command buffers with copy commands


- Signal to the renderer that a texture has finished a transfer




Before focusing on the code that uploads data to the GPU, there is some Vulkan-specific code that is important to understand, relative to command pools, transfer queues, and using a staging buffer.

### Creating command pools for the transfer queue


In order to submit commands to the transfer queue, we need to create command pools that are linked to that queue:

```
for ( u32 i = 0; i < GpuDevice::k_max_frames; ++i) {
VkCommandPoolCreateInfo cmd_pool_info = {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, nullptr };
cmd_pool_info.queueFamilyIndex = gpu->vulkan
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_transfer_queue_family;
cmd_pool_info.flags = VK_COMMAND_POOL_CREATE_RESET
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_COMMAND_BUFFER_BIT;
vkCreateCommandPool( gpu->vulkan_device, &cmd_pool_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gpu->vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&command_pools[i]);
}
```


The important part is **queueFamilyIndex**, to link **CommandPool** to the transfer queue so that every command buffer allocated from this pool can be properly submitted to the transfer queue.

Next, we will simply allocate the command buffers linked to the newly created pools:

```
for ( u32 i = 0; i < GpuDevice::k_max_frames; ++i) {
&#160;&#160;&#160;&#160;VkCommandBufferAllocateInfo cmd = {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nullptr };
&#160;&#160;&#160;&#160;&#160;&#160;&#160;cmd.commandPool = command_pools[i];
cmd.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
cmd.commandBufferCount = 1;
vkAllocateCommandBuffers( renderer->gpu->vulkan_device,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&cmd, &command_buffers[i].
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vk_command_buffer );
```


With this setup, we are now ready to submit commands to the transfer queue using the command buffers.

Next, we will have a look at the staging buffer – an addition to ensure that the transfer to the GPU is the fastest possible from the CPU.

### Creating the staging buffer


To optimally transfer data between the CPU and the GPU, there is the need to create an area of memory that can be used as a source to issue commands related to copying data to the GPU.

To achieve this, we will create a staging buffer, a persistent buffer that will serve this purpose. We will see both the Raptor wrapper and the Vulkan-specific code to create a persistent staging buffer.

In the following code, we will allocate a persistently mapped buffer of 64 MB:

```
BufferCreation bc;
bc.reset().set( VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ResourceUsageType::Stream, rmega( 64 )
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;).set_name( "staging_buffer" ).
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;set_persistent( true );
BufferHandle staging_buffer_handle = gpu->create_buffer
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;( bc );
```


This translates to the following code:

```
VkBufferCreateInfo buffer_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO };
buffer_info.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
buffer_info.size = 64 * 1024 * 1024; // 64 MB
VmaAllocationCreateInfo allocation_create_info{};
allocation_create_info.flags = VMA_ALLOCATION_CREATE
_STRATEGY_BEST_FIT_BIT | VMA_ALLOCATION_CREATE_MAPPED_BIT;
VmaAllocationInfo allocation_info{};
check( vmaCreateBuffer( vma_allocator, &buffer_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&allocation_create_info, &buffer->vk_buffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&buffer->vma_allocation, &allocation_info ) );
```


This buffer will be the source of the memory transfers, and the **VMA_ALLOCATION_CREATE_MAPPED_BIT** flag ensures that it will always be mapped.

We can retrieve and use the pointer to the allocated data from the **allocation_info** structure, filled by **vmaCreateBuffer**:

```
buffer->mapped_data = static_cast<u8*>(allocation_info.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pMappedData);
```


We can now use the staging buffer for any operation to send data to the GPU, and if ever there is the need for a bigger allocation, we could recreate a new staging buffer with a bigger size.

Next, we need to see the code to create a semaphore and a fence used to submit and synchronize the CPU and GPU execution of commands.

### Creating semaphores and fences for GPU synchronization


The code here is straightforward; the only important part is the creation of a signaled fence because it will let the code start to process uploads:

```
VkSemaphoreCreateInfo semaphore_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
vkCreateSemaphore( gpu->vulkan_device, &semaphore_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gpu->vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&transfer_complete_semaphore );
VkFenceCreateInfo fence_info{
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_FENCE_CREATE_INFO };
fence_info.flags = VK_FENCE_CREATE_SIGNALED_BIT;
vkCreateFence( gpu->vulkan_device, &fence_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gpu->vulkan_allocation_callbacks,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&transfer_fence );
```


Finally, we have now arrived at processing the requests.

### Processing a file request


File requests are not specifically Vulkan-related, but it is useful to see how they are done.

We use the STB image library ([https://github.com/nothings/stb](https://github.com/nothings/stb)) to load the texture into memory and then simply add the loaded memory and the associated texture to create an upload request. This will be responsible for copying the data from the memory to the GPU using the transfer queue:

```
FileLoadRequest load_request = file_load_requests.back();
// Process request
int x, y, comp;
u8* texture_data = stbi_load( load_request.path, &x, &y,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&comp, 4 );
// Signal the loader that an upload data is ready to be
&#160;&#160;&#160;transferred to the GPU
UploadRequest& upload_request = upload_requests.push_use();
upload_request.data = texture_data;
upload_request.texture = load_request.texture;
```


Next, we will see how to process an upload request.

### Processing an upload request


This is the part that finally uploads the data to the GPU. First, we need to ensure that the fence is signaled to proceed, which is why we created it already signaled.

If it is signaled, we can reset it so we can let the API signal it when the submission is done:

```
// Wait for transfer fence to be finished
if ( vkGetFenceStatus( gpu->vulkan_device, transfer_fence )
&#160;&#160;&#160;&#160;&#160;!= VK_SUCCESS ) {
return;
}
// Reset if file requests are present.
vkResetFences( gpu->vulkan_device, 1, &transfer_fence );
```


We then proceed to take a request, allocate memory from the staging buffer, and use a command buffer to upload the GPU:

```
// Get last request
UploadRequest request = upload_requests.back();
const sizet aligned_image_size = memory_align(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->width *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->height *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;k_texture_channels,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;k_texture_alignment );
// Request place in buffer
const sizet current_offset = staging_buffer_offset +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;aligned_image_size;
CommandBuffer* cb = &command_buffers[ gpu->current_frame ;
cb->begin();
cb->upload_texture_data( texture->handle, request.data,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;staging_buffer->handle,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_offset );
free( request.data );
cb->end();
```


The **upload_texture_data** method is the one that takes care of uploading data and adding the needed barriers. This can be tricky, so we’ve included the code to show how it can be done.

First, we need to copy the data to the staging buffer:

```
// Copy buffer_data to staging buffer
memcpy( staging_buffer->mapped_data +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;staging_buffer_offset, texture_data,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;static_cast< size_t >( image_size ) );
```


Then we can prepare a copy, in this case, from the staging buffer to an image. Here, it is important to specify the offset into the staging buffer:

```
VkBufferImageCopy region = {};
region.bufferOffset = staging_buffer_offset;
region.bufferRowLength = 0;
region.bufferImageHeight = 0;
```


We then proceed with adding a precopy memory barrier to perform a layout transition and specify that the data is using the transfer queue.

This uses the code suggested in the synchronization examples provided by the Khronos Group ([https://github.com/KhronosGroup/Vulkan-Docs/wiki/Synchronization-Examples](https://github.com/KhronosGroup/Vulkan-Docs/wiki/Synchronization-Examples)).

Once again, we show the raw Vulkan code that is simplified with some utility functions, highlighting the important lines:

```
// Pre copy memory barrier to perform layout transition
VkImageMemoryBarrier preCopyMemoryBarrier;
...
.srcAccessMask = 0,
.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
.image = image,
.subresourceRange = ... };
...
```


The texture is now ready to be copied to the GPU:

```
// Copy from the staging buffer to the image
vkCmdCopyBufferToImage( vk_command_buffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;staging_buffer->vk_buffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->vk_image,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_IMAGE_LAYOUT_TRANSFER_DST
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_OPTIMAL, 1, &region );
```


The texture is now on the GPU, but it is still not usable from the main queue.

That is why we need another memory barrier that will also transfer ownership:

```
// Post copy memory barrier
VkImageMemoryBarrier postCopyTransferMemoryBarrier = {
...
.srcAccessMask = VK_ACCESS_TRANFER_WRITE_BIT,
.dstAccessMask = 0,
.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
.srcQueueFamilyIndex = transferQueueFamilyIndex,
.dstQueueFamilyIndex = graphicsQueueFamilyIndex,
.image = image,
.subresourceRange = ... };
```


Once the ownership is transferred, a final barrier is needed to ensure that the transfer is complete and the texture can be read from the shaders, but this will be done by the renderer because it needs to use the main queue.

### Signaling the renderer of the finished transfer


The signaling is implemented by simply adding the texture to a mutexed list of textures to update so that it is thread safe.

At this point, we need to perform a final barrier for each transferred texture. We opted to add these barriers after all the rendering is done and before the present step, but it could also be done at the beginning of the frame.

As stated before, one last barrier is needed to signal that the newly updated image is ready to be read by shaders and that all the writing operations are done:

```
VkImageMemoryBarrier postCopyGraphicsMemoryBarrier = {
...
.srcAccessMask = 0,
.dstAccessMask = VK_ACCESS_SHADER_READ_BIT,
.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
.srcQueueFamilyIndex = transferQueueFamilyIndex,
.dstQueueFamilyIndex = graphicsQueueFamilyIndex,
.image = image,
.subresourceRange = ... };
```


We are now ready to use the texture on the GPU in our shaders, and the asynchronous loading is working. A very similar path is created for uploading buffers and thus will be omitted from the book but present in the code.

In this section, we saw how to unlock the asynchronous loading of resources to the GPU by using a transfer queue and different command buffers. We also showed how to manage ownership transfer between queues. Then, we finally saw the first steps in setting up tasks with the task scheduler, which is used to add multi-threading capabilities to the Raptor Engine.

下一节将use the acquired knowledge to add the parallel recording of commands to draw objects on the screen.

# Recording commands on multiple threads


To record commands using multiple threads, it is necessary to use different command buffers, at least one on each thread, to record the commands and then submit them to the main queue. To be more precise, in Vulkan, any kind of pool needs to be externally synchronized by the user; thus, the best option is to have an association between a thread and a pool.

In the case of command buffers, they are allocated from the associated pool and commands registered in it. Pools can be **CommandPools**, **DescriptorSetPools**, and **QueryPools** (for time and occlusion queries), and once associated with a thread, they can be used freely inside that thread of execution.

The execution order of the command buffers is based on the order of the array submitted to the main queue – thus, from a Vulkan perspective, sorting can be performed on a command buffer level.

We will see how important the allocation strategy for command buffers is and how easy it is to draw in parallel once the allocation is in place. We will also talk about the different types of command buffers, a unique feature of Vulkan.

## The allocation strategy


The success in recording commands in parallel is achieved by taking into consideration both thread access and frame access. When creating command pools, not only does each thread need a unique pool to allocate command buffers and commands from, but it also needs to not be in flight in the GPU.

A simple allocation strategy is to decide the maximum number of threads (we will call them **T**) that will record commands and the max number of frames (we will call them **F**) that can be in flight, then allocate command pools that are **F * ****T**.

For each task that wants to render, using the pair frame-thread ID, we will guarantee that no pool will be either in flight or used by another thread.

This is a very conservative approach and can lead to unbalanced command generations, but it can be a great starting point and, in our case, enough to provide support for parallel rendering to the Raptor Engine.

In addition, we will allocate a maximum of five empty command buffers, two primary and three secondary, so that more tasks can execute chunks of rendering in parallel.

The class responsible for this is the **CommandBufferManager** class, accessible from the device, and it gives the user the possibility to request a command buffer through the **get_command_buffer** method.

下一节将see the difference between primary and secondary command buffers, which are necessary to decide the granularity of the tasks to draw the frame in parallel.

## Command buffer recycling


Linked to the allocation strategy is the recycling of the buffers. When a buffer has been executed, it can be reused to record new commands instead of always allocating new ones.

Thanks to the allocation strategy we chose, we associate a fixed amount of **CommandPools** to each frame, and thus to reuse the command buffers, we will reset its corresponding **CommandPool** instead of manually freeing buffers: this has been proven to be much more efficient on CPU time.

Note that we are not freeing the memory associated with the buffer, but we give **CommandPool** the freedom to reuse the total memory allocated between the command buffers that will be recorded, and it will reset all the states of all its command buffers to their initial state.

At the beginning of each frame, we call a simple method to reset pools:

```
void CommandBufferManager::reset_pools( u32 frame_index ) {
&#160;&#160;&#160;&#160;for ( u32 i = 0; i < num_pools_per_frame; i++ ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const u32 pool_index = pool_from_indices(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;frame_index, i );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vkResetCommandPool( gpu->vulkan_device,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vulkan_command_pools[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pool_index ], 0 );
&#160;&#160;&#160;&#160;}
}
```


There is a utility method to calculate the pool index, based on the thread and frame.

After the reset of the pools, we can reuse the command buffers to record commands without needing to explicitly do so for each command.

We can finally have a look at the different types of command buffers.

## Primary versus secondary command buffers


The Vulkan API has a unique difference in what command buffers can do: a command buffer can either be primary or secondary.

Primary command buffers are the most used ones and can perform any of the commands – drawing, compute, or copy commands, but their granularity is pretty coarse – at least one render pass must be used, and no pass can be further parallelized.

Secondary command buffers are much more limited – they can actually only execute draw commands within a render pass – but they can be used to parallelize the rendering of render passes that contain many draw calls (such as a G-Buffer render pass).

It is paramount then to make an informed decision about the granularity of the tasks, and especially important is to understand when to record using a primary or secondary buffer.

In [*Chapter 4*](B18395_04.xhtml#_idTextAnchor064), *Implementing a Frame Graph*, we will see how a graph of the frame can give enough information to decide which command buffer type to use and how many objects and render passes should be used in a task.

下一节将see how to use both primary and secondary command buffers.

## Drawing using primary command buffers


Drawing using primary command buffers is the most common way of using Vulkan and also the simplest. A primary command buffer, as already stated before, can execute any kind of command with no limitation, and it is the only one that can be submitted to a queue to be executed on the GPU.

Creating a primary command buffer is simply a matter of using **VK_COMMAND_BUFFER_LEVEL_PRIMARY** in the **VkCommandBufferAllocateInfo** structure passed to the **vkAllocateCommandBuffers** function.

Once created, at any time, we can begin the commands recording (with the **vkBeginCommandBuffer** function), bind passes and pipelines, and issue draw commands, copy commands, and compute ones.

Once the recording is finished, the **vkEndCommandBuffer** function must be used to signal the end of recording and prepare the buffer to be ready to be submitted to a queue:

```
VkSubmitInfo submit_info = {
&#160;&#160;&#160;&#160;VK_STRUCTURE_TYPE_SUBMIT_INFO };
submit_info.commandBufferCount = num_queued_command
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_buffers;
submit_info.pCommandBuffers = enqueued_command_buffers;
...
vkQueueSubmit( vulkan_main_queue, 1, &submit_info,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;*render_complete_fence );
```


To record commands in parallel, there are only two conditions that must be respected by the recording threads:

- Simultaneous recording on the same **CommandPool** is forbidden


- Commands relative to **RenderPass** can only be executed in one thread




What happens if a pass (such as a Forward or G-Buffer typical pass) contains a lot of draw-calls, thus requiring parallel rendering? This is where secondary command buffers can be useful.

## Drawing using secondary command buffers


Secondary command buffers have a very specific set of conditions to be used – they can record commands relative to only one render pass.

That is why it is important to allow the user to record more than one secondary command buffer: it could be possible that more than one pass needs per-pass parallelism, and thus more than one secondary command buffer is needed.

Secondary buffers always need a primary buffer and can’t be submitted directly to any queue: they must be copied into the primary buffer and inherit only **RenderPass** and **FrameBuffers** set when beginning to record commands.

Let’s have a look at the different steps involving the usage of secondary command buffers. First, we need to have a primary command buffer that needs to set up a render pass and frame buffer to be rendered into, as this is absolutely necessary because no secondary command buffer can be submitted to a queue or set **RenderPass** or **FrameBuffer**.

Those will be the only states inherited from the primary command buffer, thus, even when beginning to record commands, viewport and stencil states must be set again.

Let’s start by showing a primary command buffer setup:

```
VkClearValue clearValues[2];
VkRenderPassBeginInfo renderPassBeginInfo {};
renderPassBeginInfo.renderPass = renderPass;
renderPassBeginInfo.framebuffer = frameBuffer;
vkBeginCommandBuffer(primaryCommandBuffer, &cmdBufInfo);
```


When beginning a render pass that will be split among one or more secondary command buffers, we need to add the **VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS** flag:

```
vkCmdBeginRenderPass(primaryCommandBuffer, &renderPassBeginInfo, VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS);
```


We can then pass the **inheritanceInfo** struct to the secondary buffer:

```
VkCommandBufferInheritanceInfo inheritanceInfo {};
inheritanceInfo.renderPass = renderPass;
inheritanceInfo.framebuffer = frameBuffer;
```


And then we can begin the secondary command buffer:

```
VkCommandBufferBeginInfo commandBufferBeginInfo {};
commandBufferBeginInfo.flags =
VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT;
commandBufferBeginInfo.pInheritanceInfo = &inheritanceInfo;
VkBeginCommandBuffer(secondaryCommandBuffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&commandBufferBeginInfo);
```


The secondary command buffer is now ready to start issuing drawing commands:

```
vkCmdSetViewport(secondaryCommandBuffers.background, 0, 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&viewport);
vkCmdSetScissor(secondaryCommandBuffers.background, 0, 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&scissor);
vkCmdBindPipeline(secondaryCommandBuffers.background,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_PIPELINE_BIND_POINT_GRAPHICS,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pipelines.starsphere);
VkDrawIndexed(…)
```


Note that the scissor and viewport must always be set at the beginning, as no state is inherited outside of the bound render pass and frame buffer.

Once we have finished recording the commands, we can call the **VkEndCommandBuffer** function and put the buffer into a copiable state in the primary command buffer. To copy the secondary command buffers into the primary one, there is a specific function, **vkCmdExecuteCommands**, that needs to be called:

```
vkCmdExecuteCommands(primaryCommandBuffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;commandBuffers.size(),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;commandBuffers.data());
```


This function accepts an array of secondary command buffers that will be sequentially copied into the primary one.

To ensure a correct ordering of the commands recorded, not guaranteed by multi-threading (as threads can finish in any order), we can give each command buffer an execution index, put them all into an array, sort them, and then use this sorted array in the **vkCmdExecuteCommands** function.

At this point, the primary command buffer can record other commands or be submitted to the queue, as it contains all the commands copied from the secondary command buffers.

## Spawning multiple tasks to record command buffers


The last step is to create multiple tasks to record command buffers in parallel. We have decided to group multiple meshes per command buffer as an example, but usually, you would record separate command buffers per render pass.

Let’s take a look at the code:

```
SecondaryDrawTask secondary_tasks[ parallel_recordings ]{ };
u32 start = 0;
for ( u32 secondary_index = 0;
&#160;&#160;&#160;&#160;&#160;&#160;secondary_index < parallel_recordings;
&#160;&#160;&#160;&#160;&#160;&#160;++secondary_index ) {
&#160;&#160;&#160;&#160;SecondaryDrawTask& task = secondary_tasks[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;secondary_index ];
&#160;&#160;&#160;&#160;task.init( scene, renderer, gpu_commands, start,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;start + draws_per_secondary );
&#160;&#160;&#160;&#160;start += draws_per_secondary;
&#160;&#160;&#160;&#160;task_scheduler->AddTaskSetToPipe( &task );
}
```


We add a task to the scheduler for each mesh group. Each task will record a command buffer for a range of meshes.

Once we have added all the tasks, we have to wait until they complete before adding the secondary command buffers for execution on the main command buffer:

```
for ( u32 secondary_index = 0;
&#160;&#160;&#160;&#160;&#160;&#160;secondary_index < parallel_recordings;
&#160;&#160;&#160;&#160;&#160;&#160;++secondary_index ) {
&#160;&#160;&#160;&#160;SecondaryDrawTask& task = secondary_tasks[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;secondary_index ];
&#160;&#160;&#160;&#160;task_scheduler->WaitforTask( &task );
&#160;&#160;&#160;&#160;vkCmdExecuteCommands( gpu_commands->vk_command_buffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1, &task.cb->vk_command_buffer );
}
```


We suggest reading the code for this chapter for more details on the implementation.

In this section, we have described how to record multiple command buffers in parallel to optimize this operation on the CPU. We have detailed our allocation strategy for command buffers and how they can be reused across frames.

We have highlighted the differences between primary and secondary buffers and how they are used in our renderer. Finally, we have demonstrated how to record multiple command buffers in parallel.

In the next chapter, we are going to introduce the frame graph, a system that allows us to define multiple render passes and that can take advantage of the task system we have described to record the command buffer for each render pass in parallel.

# 小结
In this chapter, we learned about the concept of task-based parallelism and saw how using a library such as enkiTS can quickly add multi-threading capabilities to the Raptor Engine.

We then learned how to add support for loading data from files to the GPU using an asynchronous loader. We also focused on Vulkan-related code to have a second queue of execution that can run in parallel to the one responsible for drawing. We saw the difference between primary and secondary command buffers.

We talked about the importance of the buffer’s allocation strategy to ensure safety when recording commands in parallel, especially taking into consideration command reuse between frames.

Finally, we showed step by step how to use both types of command buffers, and this should be enough to add the desired level of parallelism to any application that decides to use Vulkan as its graphics API.

In the next chapter, we will work on a data structure called **Frame Graph**, which will give us enough information to automate some of the recording processes, including barriers, and will ease the decision making about the granularity of the tasks that will perform parallel rendering.

# 延伸阅读
Task-based systems have been in use for many years. [https://www.gdcvault.com/play/1012321/Task-based-Multithreading-How-to](https://www.gdcvault.com/play/1012321/Task-based-Multithreading-How-to) provides a good overview.

Many articles can be found that cover work-stealing queues at [https://blog.molecular-matters.com/2015/09/08/job-system-2-0-lock-free-work-stealing-part-2-a-specialized-allocator/](https://blog.molecular-matters.com/2015/09/08/job-system-2-0-lock-free-work-stealing-part-2-a-specialized-allocator/) and are a good starting point on the subject.

The PlayStation 3 and Xbox 360 use the Cell processor from IBM to provide more performance to developers through multiple cores. In particular, the PlayStation 3 has several **synergistic processor units** (**SPUs**) that developers can use to offload work from the main processor.

There are many presentations and articles that detail many clever ways developers have used these processors, for example, [https://www.gdcvault.com/play/1331/The-PlayStation-3-s-SPU](https://www.gdcvault.com/play/1331/The-PlayStation-3-s-SPU) and [https://gdcvault.com/play/1014356/Practical-Occlusion-Culling-on](https://gdcvault.com/play/1014356/Practical-Occlusion-Culling-on).