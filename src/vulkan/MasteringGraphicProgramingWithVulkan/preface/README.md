# Preface

# Preface


Vulkan is now an established and flexible multi-platform graphics API. It has been adopted in many industries, including game development, medical imaging, movie productions, and media playback.

Learning about Vulkan is a foundational step to understanding how a modern graphics API works, both on desktop and mobile.

In *Mastering Graphics Programming with Vulkan*, you will begin by developing the foundations of a rendering framework. You will learn how to leverage advanced Vulkan features to write a modern rendering engine. You will understand how to automate resource binding and dependencies. You will then take advantage of GPU-driven rendering to scale the size of your scenes and, finally, you will get familiar with ray tracing techniques that will improve the visual quality of your rendered image.

By the end of this book, you will have a thorough understanding of the inner workings of a modern rendering engine and the graphics techniques employed to achieve state-of-the-art results. The framework developed in this book will be the starting point for all your future experiments.

# Who this book is for


This book is for professional or hobbyist graphics and game developers who would like to gain more in-depth knowledge about how to write a modern and performant rendering engine in Vulkan.

Users should be already familiar with basic concepts of graphics programming (that is, matrices and vectors) and have basic knowledge of Vulkan.

# What this book covers


[*Chapter 1*](B18395_01.xhtml#_idTextAnchor016), *Introducing the Raptor Engine and Hydra*, introduces you to the structure of our framework by providing an overview of the main components. We will then see how to compile the code for Windows and Linux.

[*Chapter 2*](B18395_02.xhtml#_idTextAnchor030), *Improving Resources Management*, simplifies managing textures for rendering by moving our renderer to use bindless textures. We will also automate the pipeline layout generation by parsing the generated SPIR-V and demonstrate how to implement pipeline caching.

[*Chapter 3*](B18395_03.xhtml#_idTextAnchor045), *Unlocking Multi-Threading*, details the concept of task-based parallelism that will help us make use of multiple cores. We will leverage this technique to load resources asynchronously and record multiple command buffers in parallel.

[*Chapter 4*](B18395_04.xhtml#_idTextAnchor064), *Implementing a Frame Graph*, helps us develop the frame graph, a data structure that holds our render passes and how they depend on each other. We will leverage this data structure to automate resource barrier placement and improve memory usage with resource aliasing.

[*Chapter 5*](B18395_05.xhtml#_idTextAnchor075), *Unlocking Async Compute*, illustrates how to leverage the async compute queue in Vulkan. We introduce timeline semaphores, which make it easier to manage queue synchronization. Finally, we will implement a simple cloth simulation, which runs on a separate queue.

[*Chapter 6*](B18395_06.xhtml#_idTextAnchor092), *GPU-Driven Rendering*, moves our renderer from meshes to meshlets, which are small groups of triangles that are used to implement GPU culling. We will introduce mesh shaders and explain how they can be leveraged to implement modern culling techniques.

[*Chapter 7*](B18395_07.xhtml#_idTextAnchor105), *Rendering Many Lights with Clustered Deferred Rendering*, describes our G-buffer implementation before moving to clustered light rendering. We will demonstrate how to leverage screen tiles and depth binning for an efficient implementation.

[*Chapter 8*](B18395_08.xhtml#_idTextAnchor116), *Adding Shadows Using Mesh Shaders*, provides a brief history of shadow techniques and then proceeds to describe our chosen approach. We leverage our meshlets and mesh shaders support to efficiently render cubemap shadowmaps. We will also demonstrate how to use sparse resources to reduce memory usage.

[*Chapter 9*](B18395_09.xhtml#_idTextAnchor143), *Implementing Variable Rate Shading*, gives us an overview of variable rate shading and explains why it’s useful. We will then describe how to use the Vulkan extension to add this technique to our renderer.

[*Chapter 10*](B18395_10.xhtml#_idTextAnchor152), *Adding Volumetric Fog*, implements a volumetric effect from first principles. We will then discuss spatial and temporal filtering to improve the quality of the final result.

[*Chapter 11*](B18395_11.xhtml#_idTextAnchor178), *Temporal Anti-Aliasing*, walks through a brief history of anti-aliasing techniques. We will then describe all the steps required to implement a robust temporal anti-aliasing solution.

[*Chapter 12*](B18395_12.xhtml#_idTextAnchor205), *Getting Started with Ray Tracing*, outlines the key concepts required to make use of the ray-tracing extension in Vulkan. We will then provide the implementation details for creating ray-tracing pipelines, shader-binding tables, and Acceleration Structures.

[*Chapter 13*](B18395_13.xhtml#_idTextAnchor213), *Revisiting Shadows with Ray Tracing*, offers up an alternative implementation of shadows that uses ray tracing. We will describe an algorithm that leverages dynamic ray count per light, paired with a spatial and temporal filter to produce stable results.

[*Chapter 14*](B18395_14.xhtml#_idTextAnchor241), *Adding Dynamic Diffuse Global Illumination with Ray Tracing*, involves adding global illumination to our scene. We will describe our use of ray tracing to generate probe data and provide a solution to minimize light leaking.

[*Chapter 15*](B18395_15.xhtml#_idTextAnchor280), *Adding Reflections with Ray Tracing*, briefly covers screen-space reflections and their shortcomings. We will then describe our implementation of ray-traced reflections. Finally, we will implement a denoiser to make the result usable for the final lighting computation.

# To get the most out of this book


This book assumes the reader is familiar with the basic concepts of Vulkan or other modern rendering APIs such as DirectX 12 or Metal. You should be comfortable editing and compiling C or C++ code and GLSL shader code.









**Software/hardware covered in ****the book**



**Operating ****system requirements**





Vulkan 1.2



Windows or Linux





You will need a C++ compiler that supports C++17. The latest version of the Vulkan SDK also needs to be installed on the system. We provide a Visual Studio solution as well as CMake files to compile the project.

**If you are using the digital version of this book, we advise you to type the code yourself or access the code from the book’s GitHub repository (a link is available in the next section). Doing so will help you avoid any potential errors related to the copying and pasting ****of code.**

For each chapter, we recommend you run the code and make sure you understand how it works. Each chapter builds on the concepts from the previous one and it is important you have internalized those concepts before moving on. We also suggest making your own changes to experiment with different approaches.

# Download the example code files


You can download the example code files for this book from GitHub at [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan). If there’s an update to the code, it will be updated in the GitHub repository.

We also have other code bundles from our rich catalog of books and videos available at [https://github.com/PacktPublishing/](https://github.com/PacktPublishing/). Check them out!

# Download the color images


We also provide a PDF file that has color images of the screenshots and diagrams used in this book. You can download it here: [https://packt.link/ht2jV](https://packt.link/ht2jV).

# Conventions used


There are a number of text conventions used throughout this book.

**Code in text**: Indicates code words in text, database table names, folder names, filenames, file extensions, pathnames, dummy URLs, user input, and Twitter handles. Here is an example: “For each resource type, we call the relative method on the **DescriptorSetCreation** object.”

A block of code is set as follows:

```
export VULKAN_SDK=~/vulkan/1.2.198.1/x86_64
export PATH=$VULKAN_SDK/bin:$PATH
export LD_LIBRARY_PATH=$VULKAN_SDK/lib:$LD_LIBRARY_PATH
export VK_LAYER_PATH=$VULKAN_SDK/etc/vulkan/explicit_layer.d
```


When we wish to draw your attention to a particular part of a code block, the relevant lines or items are set in bold:

```
VkPhysicalDeviceFeatures2 device_features{ VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, &indexing_features };
&#160;&#160;&#160;&#160;vkGetPhysicalDeviceFeatures2( vulkan_physical_device,
&#160;&#160;&#160;&#160;&device_features );
&#160;&#160;&#160;&#160;bindless_supported = indexing_features.
&#160;&#160;&#160;&#160;descriptorBindingPartiallyBound && indexing_features.
&#160;&#160;&#160;&#160;runtimeDescriptorArray;
```


Any command-line input or output is written as follows:

```
$ tar -xvf vulkansdk-linux-x86_64-1.2.198.1.tar.gz
```


**Bold**: Indicates a new term, an important word, or words that you see onscreen. For instance, words in menus or dialog boxes appear in **bold**. Here is an example: “We then start the application by clicking on **Launch**, and we will notice an overlay reporting the frame time and the number of frames rendered.”

Tips or important notes

Appear like this.

# Get in touch


Feedback from our readers is always welcome.

**General feedback**: If you have questions about any aspect of this book, email us at [customercare@packtpub.com](mailto:customercare@packtpub.com) and mention the book title in the subject of your message.

**Errata**: Although we have taken every care to ensure the accuracy of our content, mistakes do happen. If you have found a mistake in this book, we would be grateful if you would report this to us. Please visit [www.packtpub.com/support/errata](http://www.packtpub.com/support/errata) and fill in the form.

**Piracy**: If you come across any illegal copies of our works in any form on the internet, we would be grateful if you would provide us with the location address or website name. Please contact us at [copyright@packt.com](mailto:copyright@packt.com) with a link to the material.

**If you are interested in becoming an author**: If there is a topic that you have expertise in and you are interested in either writing or contributing to a book, please visit [authors.packtpub.com](http://authors.packtpub.com).

# Share Your Thoughts


Once you’ve read *Mastering Graphics Programming with Vulkan*, we’d love to hear your thoughts! Please select [https://www.amazon.com/review/create-review/error?asin=1803244798](https://www.amazon.com/review/create-review/error?asin=1803244798) for this book and share your feedback.

Your review is important to us and the tech community and will help us make sure we’re delivering excellent quality content.

# Download a free PDF copy of this book


Thanks for purchasing this book!

Do you like to read on the go but are unable to carry your print books everywhere?

Is your eBook purchase not compatible with the device of your choice?

Don’t worry, now with every Packt book you get a DRM-free PDF version of that book at no cost.

Read anywhere, any place, on any device. Search, copy, and paste code from your favorite technical books directly into your application.

The perks don’t stop there, you can get exclusive access to discounts, newsletters, and great free content in your inbox daily

Follow these simple steps to get the benefits:

- Scan the QR code or visit the link below








 ![](image/B18395_QR_Free_PDF.jpg)


[https://packt.link/free-ebook/9781803244792]()

- Submit your proof of purchase


- That’s it! We’ll send your free PDF and other benefits to your email directly