# Chapter 4: Implementing a Frame Graph

# 4



# Implementing a Frame Graph


In this chapter, we are introducing **frame graphs**, a new system to control the rendering steps for a given frame. As the name implies, we are going to organize the steps (passes) required to render a frame in a **Directed Acyclic Graph** (**DAG**). This will allow us to determine the order of execution of each pass and which passes can be executed in parallel.

Having a graph also provides us with many other benefits, such as the following:

- It allows us to automate the creation and management of render passes and frame buffers, as each pass defines the input resources it will read from and which resources it will write to.


- It helps us reduce the memory required for a frame with a technique called **memory aliasing**. We can determine how long a resource will be in use by analyzing the graph. After the resource is no longer needed, we can reuse its memory for a new resource.


- Finally, we’ll be able to let the graph manage the insertion of memory barriers and layout transitions during its execution. Each input and output resource defines how it will be used (texture versus attachment, for instance), and we can infer its next layout with this information.




In summary, in this chapter, we’re going to cover the following main topics:

- Understanding the structure of a frame graph and the details of our implementations


- Implementing a topological sort to make sure the passes execute in the right order


- Using the graph to drive rendering and automate resource management and layout transitions





# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter4](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter4).

# Understanding frame graphs


So far, the rendering in the Raptor Engine has consisted of one pass only. While this approach has served us well for the topics we have covered, it won’t scale for some of the later chapters. More importantly, it wouldn’t be representative of how modern rendering engines organize their work. Some games and engines implement hundreds of passes, and having to manually manage them can become tedious and error-prone.

Thus, we decided this was a good time in the book to introduce a frame graph. In this section, we are going to present the structure of our graph and the main interfaces to manipulate it in the code.

Let’s start with the basic concepts of a graph.

## Building a graph


Before we present our solution and implementation for the frame graph, we would like to provide some of the building blocks that we are going to use throughout the chapter. If you’re familiar with frame graphs, or graphs in general, feel free to skim through this section.

A graph is defined by two elements: **nodes** (or vertices) and **edges**. Each node can be connected to one or more nodes, and each connection is defined by an edge.



 ![Figure 4.1 – An edge from node A to B](image/B18395_04_01.jpg)


Figure 4.1 – An edge from node A to B

In the introduction of this chapter, we mentioned that a frame graph is a DAG. It’s important that our frame graph has these properties as otherwise, we wouldn’t be able to execute it:

- **Directed**: This means that the edges have a direction. If, for instance, we define an edge to go from node *A* to node *B*, we can’t use the same edge to go from *B* to *A*. We would need a different edge to go from *B* to *A*.







 ![Figure 4.2 – Connecting A to B and B to A in a directed graph](image/B18395_04_02.jpg)


Figure 4.2 – Connecting A to B and B to A in a directed graph

- **Acyclic**: This means that there can’t be any cycles in the graph. A cycle is introduced when we can go back to a given node after following the path from one of its children. If this happens, our frame graph will enter an infinite loop.







 ![Figure 4.3 – An example of a graph containing a cycle](image/B18395_04_03.jpg)


Figure 4.3 – An example of a graph containing a cycle

In the case of a frame graph, each node represents a rendering pass: depth prepass, g-buffer, lighting, and so on. We don’t define the edges explicitly. Instead, each node will define a number of outputs and, if needed, a number of inputs. An edge is then implied when the output of a given pass is used as input in another pass.



 ![Figure 4.4 – An example of a full frame graph](image/B18395_04_04.jpg)


Figure 4.4 – An example of a full frame graph

These two concepts, nodes and edges, are all that is needed to understand a frame graph. Next, we are going to present how we decided to encode this data structure.

## A data-driven approach


Some engines only provide a code interface to build a frame graph, while others let developers specify the graph in a human-readable format – JSON for example – so that making changes to the graph doesn’t necessarily require code changes.

After some consideration, we have decided to define our graph in JSON and implement a parser to instantiate the classes required. There are a few reasons we opted for this approach:

- It allows us to make some changes to the graph without having to recompile the code. If, for instance, we want to change the size or format of a render target, all we have to do is make the change in the JSON definition of the graph and rerun the program.


- We can also reorganize the graph and remove some of its nodes without making changes to the code.


- It’s easier to understand the flow of the graph. Depending on the implementation, the definition of the graph in code could be spread across different code locations or even different files. This makes it harder to determine the graph structure.


- It’s easier for non-technical contributors to make changes. The graph definition could also be done through a visual tool and translated into JSON. The same approach wouldn’t be feasible if the graph definition was done purely in code.




We can now have a look at a node in our frame graph:

```
{
&#160;&#160;&#160;&#160;"inputs":
&#160;&#160;&#160;&#160;[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"type": "attachment",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"name": "depth"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;],
&#160;&#160;&#160;&#160;"name": "gbuffer_pass",
&#160;&#160;&#160;&#160;"outputs":
&#160;&#160;&#160;&#160;[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"type": "attachment",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"name": "gbuffer_colour",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"format": "VK_FORMAT_B8G8R8A8_UNORM",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"resolution": [ 1280, 800 ],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"op": "VK_ATTACHMENT_LOAD_OP_CLEAR"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;},
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"type": "attachment",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"name": "gbuffer_normals",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"format": "VK_FORMAT_R16G16B16A16_SFLOAT",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"resolution": [ 1280, 800 ],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"op": "VK_ATTACHMENT_LOAD_OP_CLEAR"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;},
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;...
&#160;&#160;&#160;&#160;]
}
```


A node is defined by three variables:

- **name**: This helps us identify the node during execution, and it also gives us a meaningful name for other elements, for instance, the render pass associated with this node.


- **inputs**: This lists the inputs for this node. These are resources that have been produced by another node. Note that it would be an error to define an input that has not been produced by another node in the graph. The only exceptions are external resources, which are managed outside the render graph, and the user will have to provide them to the graph at runtime.


- **outputs**: These are the resources produced by a given node.




We have defined four different types of resources depending on their use:

- **attachment**: The list of attachments is used to determine the render pass and framebuffer composition of a given node. As you noticed in the previous example, attachments can be defined both for inputs and outputs. This is needed to continue working on a resource in multiple nodes. After we run a depth prepass, for instance, we want to load the depth data and use it during the g-buffer pass to avoid shading pixels for objects that are hidden behind other objects.


- **texture**: This type is used to distinguish images from attachments. An attachment has to be part of the definition of the render pass and framebuffer for a node, while a texture is read during the pass and is part of a shader data definition.




This distinction is also important to determine which images need to be transitioned to a different layout and require an image barrier. We’ll cover this in more detail later in the chapter.

We don’t need to specify the size and format of the texture here, as we had already done so when we first defined the resource as an output.

- **buffer**: This type represents a storage buffer that we can write to or read from. As with textures, we will need to insert memory barriers to ensure the writes from a previous pass are completed before accessing the buffer data in another pass.


- **reference**: This type is used exclusively to ensure the right edges between nodes are computed without creating a new resource.




All types are quite intuitive, but we feel that the reference type deserves an example to better understand why we need this type:

```
{
&#160;&#160;&#160;&#160;"inputs":
&#160;&#160;&#160;&#160;[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"type": "attachment",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"name": "lighting"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;},
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"type": "attachment",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"name": "depth"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;],
&#160;&#160;&#160;&#160;"name": "transparent_pass",
&#160;&#160;&#160;&#160;"outputs":
&#160;&#160;&#160;&#160;[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;{
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"type": "reference",
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;"name": "lighting"
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;]
}
```


In this case, lighting is an input resource of the **attachment** type. When processing the graph, we will correctly link the node that produced the lighting resource to this node. However, we also need to make sure that the next node that makes use of the lighting resource creates a connection to this node, as otherwise, the node ordering would be incorrect.

For this reason, we add a reference to the lighting resource in the output of the transparent pass. We can’t use the **attachment** type here as otherwise, we would double count the lighting resource in the creation of the render pass and framebuffer.

Now that you have a good understanding of the frame graph structure, it’s time to look at some code!

## Implementing the frame graph


In this section, we are going to define the data structures that are going to be used throughout the chapter, namely resources and nodes. Next, we are going to parse the JSON definition of the graph to create resources and nodes that will be used for subsequent steps.

Let’s start with the definition of our data structures.

### Resources


**Resources** define an input or an output of a node. They determine the use of the resource for a given node and, as we will explain later, they are used to define edges between the frame graph nodes. A resource is structured as follows:

```
struct FrameGraphResource {
&#160;&#160;&#160;&#160;FrameGraphResourceType type;
&#160;&#160;&#160;&#160;FrameGraphResourceInfo resource_info;
&#160;&#160;&#160;&#160;FrameGraphNodeHandle producer;
&#160;&#160;&#160;&#160;FrameGraphResourceHandle output_handle;
&#160;&#160;&#160;&#160;i32 ref_count = 0;
&#160;&#160;&#160;&#160;const char* name = nullptr;
};
```


A resource can be either an input or an output of a node. It’s worth going through each field in the following list:

- **type**: Defines whether we are dealing with an image or a buffer.


- **resource_info**: Contains the details about the resource (such as size, format, and so on) based on **type**.


- **producer**: Stores a reference to the node that outputs a resource. This will be used to determine the edges of the graph.


- **output_handle**: Stores the parent resource. It will become clearer later why we need this field.


- **ref_count**: Will be used when computing which resources can be aliased. Aliasing is a technique that allows multiple resources to share the same memory. We will provide more details on how this works later in this chapter.


- **name**: Contains the name of the resource as defined in JSON. This is useful for debugging and also to retrieve the resource by name.




Next, we are going to look at a graph node:

```
struct FrameGraphNode {
&#160;&#160;&#160;&#160;RenderPassHandle render_pass;
&#160;&#160;&#160;&#160;FramebufferHandle framebuffer;
&#160;&#160;&#160;&#160;FrameGraphRenderPass* graph_render_pass;
&#160;&#160;&#160;&#160;Array<FrameGraphResourceHandle> inputs;
&#160;&#160;&#160;&#160;Array<FrameGraphResourceHandle> outputs;
&#160;&#160;&#160;&#160;Array<FrameGraphNodeHandle> edges;
&#160;&#160;&#160;&#160;const char* name = nullptr;
};
```


A node stores the list of inputs it will use during execution and the outputs it will produce. Each input and output is a different instance of **FrameGraphResource**. The **output_handle** field is used to link an input to its output resource. We need separate resources because their type might differ; an image might be used as an output attachment and then used as an input texture. This is an important detail that will be used to automate memory barrier placement.

A node also stores a list of the nodes it is connected to, its name, the framebuffer, and the render pass created according to the definition of its inputs and outputs. Like resources, a node also stores its name as defined on JSON.

Finally, a node contains a pointer to the rendering implementation. We’ll discuss later how we link a node to its rendering pass.

These are the main data structures used to define our frame graph. We have also created a **FrameGraphBuilder** helper class that will be used by the **FrameGraph** class. The **FrameGraphBuilder** helper class contains the functionality to create nodes and resources.

Let’s see how these building blocks are used to define our frame graph!

### Parsing the graph


Now that we have defined the data structures that make our graph, we need to parse the JSON definition of the graph to fill those structures and create our frame graph definition. Here are the steps that need to be executed to parse the frame graph:

- We start by initializing a **FrameGraphBuilder** and **FrameGraph** class:

```
FrameGraphBuilder frame_graph_builder;
```

```
frame_graph_builder.init( &gpu );
```

```
FrameGraph frame_graph;
```

```
frame_graph.init( &frame_graph_builder );
```


- Next, we call the **parse** method to read the JSON definition of the graph and create the resources and nodes for it:

```
frame_graph.parse( frame_graph_path,
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&scratch_allocator );
```


- Once we have our graph definition, we have our compile step:

```
frame_graph.compile();
```




This step is where the magic happens. We analyze the graph to compute the edges between nodes, create the framebuffer and render passes for each class, and determine which resources can be aliased. We are going to explain each of these steps in detail in the next section.

- Once we have compiled our graph, we need to register our rendering passes:

```
frame_graph->builder->register_render_pass(
```

```
&#160;&#160;&#160;&#160;"depth_pre_pass", &depth_pre_pass );
```

```
frame_graph->builder->register_render_pass(
```

```
&#160;&#160;&#160;&#160;"gbuffer_pass", &gbuffer_pass );
```

```
frame_graph->builder->register_render_pass(
```

```
&#160;&#160;&#160;&#160;"lighting_pass", &light_pass );
```

```
frame_graph->builder->register_render_pass(
```

```
&#160;&#160;&#160;&#160;"transparent_pass", &transparent_pass );
```

```
frame_graph->builder->register_render_pass(
```

```
&#160;&#160;&#160;&#160;"depth_of_field_pass", &dof_pass );
```




This allows us to test different implementations for each pass by simply swapping which class we register for a given pass. It’s even possible to swap these passes at runtime.

- Finally, we are ready to render our scene:

```
frame_graph->render( gpu_commands, scene );
```




We are now going to look at the **compile** and **render** methods in detail.

## Implementing topological sort


As we mentioned in the preceding section, the most interesting aspects of the frame graph implementation are inside the **compile** method. We have abbreviated some of the code for clarity in the following sections.

Please refer to the GitHub link mentioned in the *Technical requirements* section of the chapter for the full implementation.

Here is a breakdown of the algorithm that we use to compute the edges between nodes:

- The first step we perform is to create the edges between nodes:

```
for ( u32 r = 0; r < node->inputs.size; ++r ) {
```

```
&#160;&#160;&#160;&#160;FrameGraphResource* resource = frame_graph->
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;get_resource( node->inputs[ r ].index );
```

```
&#160;&#160;&#160;&#160;u32 output_index = frame_graph->find_resource(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;hash_calculate( resource->name ) );
```

```
&#160;&#160;&#160;&#160;FrameGraphResource* output_resource = frame_graph
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;->get_resource( output_index );
```




We accomplish this by iterating through each input and retrieving the corresponding output resource. Note that internally, the graph stores the outputs in a map keyed by name.

- Next, we save the details of the output in the input resource. This way we have direct access to this data in the input as well:

```
&#160;&#160;&#160;&#160;resource->producer = output_resource->producer;
```

```
&#160;&#160;&#160;&#160;resource->resource_info = output_resource->
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource_info;
```

```
&#160;&#160;&#160;&#160;resource->output_handle = output_resource->
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;output_handle;
```


- Finally, we create an edge between the node that produces this input and the node we are currently processing:

```
&#160;&#160;&#160;&#160;FrameGraphNode* parent_node = ( FrameGraphNode*)
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;frame_graph->
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;get_node(
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource->
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;producer.index );
```

```
&#160;&#160;&#160;&#160;parent_node->edges.push( frame_graph->nodes[
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;node_index ] );
```

```
}
```




At the end of this loop, each node will contain the list of nodes it is connected to. While we currently don’t do this, at this stage, it would be possible to remove nodes that have no edges from the graph.

Now that we have computed the connection between nodes, we can sort them in topological order. At the end of this step, we will obtain the list of nodes ordered to ensure that nodes that produce an output come before the nodes that make use of that output.

Here is a breakdown of the sorting algorithm where we have highlighted the most relevant sections of the code:

- The **sorted_node** array will contain the sorted nodes in reverse order:

```
Array<FrameGraphNodeHandle> sorted_nodes;
```

```
sorted_nodes.init( &local_allocator, nodes.size );
```


- The **visited** array will be used to mark which nodes we have already processed. We need to keep track of this information to avoid infinite loops:

```
Array<u8> visited;
```

```
visited.init( &local_allocator, nodes.size, nodes.size
```

```
);
```

```
memset( visited.data, 0, sizeof( bool ) * nodes.size );
```


- Finally, the **stack** array is used to keep track of which nodes we still have to process. We need this data structure as our implementation doesn’t make use of recursion:

```
Array<FrameGraphNodeHandle> stack;
```

```
stack.init( &local_allocator, nodes.size );
```


- The graph is traversed by using **depth-first search** (**DFS**). The code that follows performs exactly this task:

```
for ( u32 n = 0; n < nodes.size; ++n ) {
```

```
&#160;&#160;&#160;&#160;stack.push( nodes[ n ] );
```


- We iterate through each node and add it to the stack. We do this to ensure we process all the nodes in the graph:

```
&#160;&#160;&#160;&#160;while ( stack.size > 0 ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphNodeHandle node_handle =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;stack.back();
```


- We then have a second loop that will be active until we have processed all nodes that are connected to the node we just added to the stack:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if (visited[ node_handle.index ] == 2) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;stack.pop();
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;continue;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
```




If a node has already been visited and added to the list of sorted nodes, we simply remove it from the stack and continue processing other nodes. Traditional graph processing implementations don’t have this step.

We had to add it as a node might produce multiple outputs. These outputs, in turn, might link to multiple nodes, and we don’t want to add the producing node multiple times to the sorted node list.

- If the node we are currently processing has already been visited and we got to it in the stack, it means we processed all of its children, and it can be added to the list of sorted nodes. As mentioned in the following code, we also mark it as added so that we won’t add it multiple times to the list:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( visited[ node_handle.index ]&#160;&#160;== 1) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;visited[ node_handle.index ] = 2; // added
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sorted_nodes.push( node_handle );
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;stack.pop();
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;continue;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
```


- When we first get to a node, we mark it as **visited**. As mentioned in the following code block, this is needed to make sure we don’t process the same node multiple times:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;visited[ node_handle.index ] = 1; // visited
```


- If the node we are processing has no edges, we continue to iterate:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphNode* node = ( FrameGraphNode* )
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->node_cache.
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nodes.access_resource
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;( node_handle.index
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Leaf node
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( node->edges.size == 0 ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;continue;
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
```


- On the other hand, if the node is connected to other nodes, we add them to the stack for processing and then iterate again. If this is the first time you’ve seen an iterative implementation of graph traversal, it might not be immediately clear how it relates to the recursive implementation. We suggest going through the code a few times until you understand it; it’s a powerful technique that will come in handy at times!

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;for ( u32 r = 0; r < node->edges.size; ++r ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphNodeHandle child_handle =
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;node->edges[ r ];
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( !visited[ child_handle.index ] ) {
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;stack.push( child_handle );
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
```

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
```


- The final step is to iterate through the sorted nodes array and add them to the graph nodes in reverse order:

```
for ( i32 i = sorted_nodes.size - 1; i >= 0; --i ) {
```

```
&#160;&#160;&#160;&#160;nodes.push( sorted_nodes[ i ] );
```

```
}
```




We have now completed the topological sorting of the graph! With the nodes sorted, we can now proceed to analyze the graph to identify which resources can be aliased.

### Computing resource aliasing


Large frame graphs must deal with hundreds of nodes and resources. The lifetime of these resources might not span the full graph, and this gives us an opportunity to reuse memory for resources that are no longer needed. This technique is called **memory aliasing**, as multiple resources can point to the same memory allocation.



 ![Figure 4.5 – An example of resource lifetime across the frame](image/B18395_04_05.jpg)


Figure 4.5 – An example of resource lifetime across the frame

In this example, we can see that the **gbuffer_colour** resource is not needed for the full frame, and its memory can be reused, for instance, for the **final** resource.

We first need to determine the first and last nodes that use a given resource. Once we have the information, we can determine whether a given node can reuse existing memory for its resources. The code that follows implements this technique.

We start by allocating a few helper arrays:

```
sizet resource_count = builder->resource_cache.resources.
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;used_indices;
Array<FrameGraphNodeHandle> allocations;
allocations.init( &local_allocator, resource_count,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource_count );
for ( u32 i = 0; i < resource_count; ++i) {
&#160;&#160;&#160;&#160;allocations[ i ].index = k_invalid_index;
}
Array<FrameGraphNodeHandle> deallocations;
deallocations.init( &local_allocator, resource_count,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource_count );
for ( u32 i = 0; i < resource_count; ++i) {
&#160;&#160;&#160;&#160;deallocations[ i ].index = k_invalid_index;
}
Array<TextureHandle> free_list;
free_list.init( &local_allocator, resource_count );
```


They are not strictly needed by the algorithm, but they are helpful for debugging and ensuring our implementation doesn’t have a bug. The **allocations** array will track on which node a given resource was allocated.

Similarly, the **deallocations** array contains the node at which a given resource can be deallocated. Finally, **free_list** will contain the resources that have been freed and can be reused.

Next, we are going to look at the algorithm that tracks the allocations and deallocations of resources:

```
for ( u32 i = 0; i < nodes.size; ++i ) {
&#160;&#160;&#160;&#160;FrameGraphNode* node = ( FrameGraphNode* )builder->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;node_cache.nodes.access
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;_resource( nodes[ i ].index );
&#160;&#160;&#160;&#160;for ( u32 j = 0; j < node->inputs.size; ++j ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResource* input_resource =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->resource_cache.resources.get(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;node->inputs[ j ].index );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResource* resource =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->resource_cache.resources.get(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;input_resource->output_handle.index );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource->ref_count++;
&#160;&#160;&#160;&#160;}
}
```


First, we loop through all the input resources and increase their reference count each time they are used as input. We also mark which node allocates the resource in the **allocations** array:

```
for ( u32 i = 0; i < nodes.size; ++i ) {
&#160;&#160;&#160;&#160;FrameGraphNode* node = builder->get_node(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nodes[ i ].index );
&#160;&#160;&#160;&#160;for ( u32 j = 0; j < node->outputs.size; ++j ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;u32 resource_index = node->outputs[ j ].index;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResource* resource =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->resource_cache.resources.get(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource_index );
```


The next step is to iterate through all the nodes and their outputs. The code that follows is responsible for performing the memory allocations:

```
if ( !resource->resource_info.external &&
&#160;&#160;allocations[ resource_index ].index ==
&#160;&#160;k_invalid_index ) {
&#160;&#160;&#160;&#160;&#160;&#160;allocations[ resource_index ] = nodes[ i ];
if ( resource->type ==
&#160;&#160;FrameGraphResourceType_Attachment ) {
&#160;&#160;&#160;&#160;&#160;FrameGraphResourceInfo& info =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource->resource_info;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( free_list.size > 0 ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;TextureHandle alias_texture =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;free_list.back();
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;free_list.pop();
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;TextureCreation texture_creation{ };
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;TextureHandle handle =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->device->create_texture(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture_creation );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;info.texture.texture = handle;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;} else {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;TextureCreation texture_creation{ };
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;TextureHandle handle =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->device->create_texture(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture_creation );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;info.texture.texture = handle;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
```


For each output resource, we first check whether there are any available resources that can be reused. If so, we pass the free resource to the **TextureCreation** structure. Internally, **GpuDevice** will use the memory from this resource and bind it to the newly created resource. If no free resources are available, we proceed by creating a new resource.

The last part of the loop takes care of determining which resources can be freed and added to the free list:

```
&#160;&#160;&#160;&#160;for ( u32 j = 0; j < node->inputs.size; ++j ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResource* input_resource =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->resource_cache.resources.get(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;node->inputs[ j ].index );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;u32 resource_index = input_resource->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;output_handle.index;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResource* resource =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->resource_cache.resources.get(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource_index );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource->ref_count--;
if ( !resource->resource_info.external &&
&#160;&#160;resource->ref_count == 0 ) {
&#160;&#160;&#160;&#160;&#160;deallocations[ resource_index ] = nodes[ i ];
if ( resource->type ==
&#160;&#160;FrameGraphResourceType_Attachment ||
&#160;&#160;resource->type ==
&#160;&#160;FrameGraphResourceType_Texture ) {
&#160;&#160;&#160;&#160;&#160;free_list.push( resource->resource_info.
&#160;&#160;&#160;&#160;&#160;texture.texture );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
}
```


We iterate over the inputs one final time and decrease the reference count of each resource. If the reference count reaches **0**, it means this is the last node that uses the resource. We save the node in the **deallocations** array and add the resource to the free list, ready to be used for the next node we are going to process.

This concludes the implementation of the graph analysis. The resources we have created are used to create the **framebuffer** object, at which point the graph is ready for rendering!

We are going to cover the execution of the graph in the next section.

## Driving rendering with the frame graph


After the graph has been analyzed, we have all the details we need for rendering. The following code is responsible for executing each node and ensuring all the resources are in the correct state for use by that node:

```
for ( u32 n = 0; n < nodes.size; ++n ) {
&#160;&#160;&#160;&#160;FrameGraphNode*node = builder->get_node( nodes
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;[ n ].index );
&#160;&#160;&#160;&#160;gpu_commands->clear( 0.3, 0.3, 0.3, 1 );
&#160;&#160;&#160;&#160;gpu_commands->clear_depth_stencil( 1.0f, 0 );
for ( u32 i = 0; i < node->inputs.size; ++i ) {
&#160;&#160;&#160;FrameGraphResource* resource =
&#160;&#160;&#160;builder->get_resource( node->inputs[ i ].index
&#160;&#160;&#160;);
if ( resource->type ==
&#160;&#160;FrameGraphResourceType_Texture ) {
&#160;&#160;&#160;&#160;&#160;Texture* texture =
&#160;&#160;&#160;&#160;&#160;gpu_commands->device->access_texture(
&#160;&#160;&#160;&#160;&#160;resource->resource_info.texture.texture
&#160;&#160;&#160;&#160;&#160;);
util_add_image_barrier( gpu_commands->
&#160;&#160;&#160;&#160;vk_command_buffer, texture->vk_image,
&#160;&#160;&#160;&#160;RESOURCE_STATE_RENDER_TARGET,
&#160;&#160;&#160;&#160;RESOURCE_STATE_PIXEL_SHADER_RESOURCE,
&#160;&#160;&#160;&#160;0, 1, resource->resource_info.
&#160;&#160;&#160;&#160;texture.format ==
&#160;&#160;&#160;&#160;VK_FORMAT_D32_SFLOAT );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;} else if ( resource->type ==
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResourceType_Attachment ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;Texture*texture = gpu_commands->device->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;access_texture( resource->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource_info.texture.texture
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;); }
&#160;&#160;&#160;&#160;}
```


We first iterate through all the inputs of a node. If the resource is a texture, we insert a barrier to transition that resource from an attachment layout (for use in a render pass) to a shader stage layout (for use in a fragment shader).

This step is important to make sure any previous writes have completed before we access this resource for reading:

```
&#160;&#160;&#160;&#160;for ( u32 o = 0; o < node->outputs.size; ++o ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResource* resource =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;builder->resource_cache.resources.get(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;node->outputs[ o ].index );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( resource->type ==
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;FrameGraphResourceType_Attachment ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;Texture* texture =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gpu_commands->device->access_texture(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource->resource_info.texture.texture
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;width = texture->width;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;height = texture->height;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if ( texture->vk_format == VK_FORMAT_D32_SFLOAT ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;util_add_image_barrier(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gpu_commands->vk_command_buffer,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture->vk_image, RESOURCE_STATE_UNDEFINED,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;RESOURCE_STATE_DEPTH_WRITE, 0, 1, resource->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource_info.texture.format ==
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_FORMAT_D32_SFLOAT );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;} else {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;util_add_image_barrier( gpu_commands->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vk_command_buffer, texture->vk_image,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;RESOURCE_STATE_UNDEFINED,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;RESOURCE_STATE_RENDER_TARGET, 0, 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;resource->resource_info.texture.format ==
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;VK_FORMAT_D32_SFLOAT );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
```


Next, we iterate over the outputs of the node. Once again, we need to make sure the resource is in the correct state to be used as an attachment in the render pass. After this step, our resources are ready for rendering.

The render targets of each node could all have different resolutions. The following code ensures that our scissor and viewport sizes are correct:

```
&#160;&#160;&#160;&#160;Rect2DInt scissor{ 0, 0,( u16 )width, ( u16 )height };
&#160;&#160;&#160;&#160;gpu_commands->set_scissor( &scissor );
&#160;&#160;&#160;&#160;Viewport viewport{ };
&#160;&#160;&#160;&#160;viewport.rect = { 0, 0, ( u16 )width, ( u16 )height };
&#160;&#160;&#160;&#160;viewport.min_depth = 0.0f;
&#160;&#160;&#160;&#160;viewport.max_depth = 1.0f;
&#160;&#160;&#160;&#160;gpu_commands->set_viewport( &viewport );
```


Once the viewport and scissor are set correctly, we call the **pre_render** method on each node. This allows each node to perform any operations that must happen outside a render pass. For instance, the render pass for the depth-of-field effect takes the input texture and computes the MIP maps for that resource:

```
&#160;&#160;&#160;&#160;node->graph_render_pass->pre_render( gpu_commands,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;render_scene );
```


Finally, we bind the render pass for this node, call the **render** method of the rendering pass that we registered for this node, and end the loop by ending the render pass:

```
&#160;&#160;&#160;&#160;gpu_commands->bind_pass( node->render_pass, node->
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;framebuffer, false );
&#160;&#160;&#160;&#160;node->graph_render_pass->render( gpu_commands,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;render_scene );
&#160;&#160;&#160;&#160;gpu_commands->end_current_render_pass();
}
```


This concludes the code overview for this chapter! We have covered a lot of ground; this is a good time for a brief recap: we started with the definition of the main data structures used by our frame graph implementation. Next, we explained how the graph is parsed to compute the edges between nodes by using inputs and outputs.

Once this step is completed, we can sort the nodes in topological order to ensure they are executed in the correct order. We then create the resources needed to execute the graph and make use of memory aliasing to optimize memory usage. Finally, we iterate over each node for rendering, making sure that all resources are in the correct state for that node.

There are some features that we haven’t implemented and that could improve the functionality and robustness of our frame graph. For example, we should ensure there are no loops in the graph and that an input isn’t being produced by the same node it’s being used in.

For the memory aliasing implementation, we use a greedy approach and simply pick the first free resource that can accommodate a new resource. This can lead to fragmentation and suboptimal use of memory.

We encourage you to experiment with the code and improve on it!

# 小结
In this chapter, we implemented a frame graph to improve the management of rendering passes and make it easier to expand our rendering pipeline in future chapters. We started by covering the basic concepts, nodes and edges, that define a graph.

Next, we gave an overview of the structure of our graph and how it’s encoded in JSON format. We also mentioned why we went for this approach as opposed to defining the graph fully in code.

In the last part, we detailed how the graph is processed and made ready for execution. We gave an overview of the main data structures used for the graph, and covered how the graph is parsed to create nodes and resources, and how edges are computed. Next, we explained the topological sorting of nodes, which ensures they are executed in the correct order. We followed that with the memory allocation strategy, which allows us to reuse memory from resources that are no longer needed at given nodes. Finally, we provided an overview of the rendering loop and how we ensure that resources are in the correct state for rendering.

In the next chapter, we are going to take advantage of the techniques we have developed in the last two chapters. We are going to leverage multithreading and our frame graph implementation to demonstrate how to use compute and graphics pipelines in parallel for cloth simulation.

# 延伸阅读
Our implementation has been heavily inspired by the implementation of a frame graph in the Frostbite engine, and we recommend watching this presentation: [https://www.gdcvault.com/play/1024045/FrameGraph-Extensible-Rendering-Architecture-in](https://www.gdcvault.com/play/1024045/FrameGraph-Extensible-Rendering-Architecture-in).

Many other engines implement a frame graph to organize and optimize their rendering pipeline. We encourage you to look at other implementations and find the solution that best fits your needs!