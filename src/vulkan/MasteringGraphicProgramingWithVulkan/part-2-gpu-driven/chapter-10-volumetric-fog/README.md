# Chapter 10: Adding Volumetric Fog

# 10



# Adding Volumetric Fog


After adding variable rate shading in the previous chapter, we will implement another modern technique that will enhance the visuals of the Raptor Engine: **Volumetric Fog**. Volumetric rendering and fog are very old topics in rendering literature, but until a few years ago, they were considered impossible for real-time usage.

The possibility of making this technique feasible in real-time stems from the observation that fog is a low-frequency effect; thus the rendering can be at a much lower resolution than the screen, increasing the performance in real-time usage.

Also, the introduction of compute shaders, and thus generic GPU programming, paired with clever observations about approximations and optimizations of the volumetric aspect of the technique, paved the way to unlocking real-time Volumetric Fog.

The main idea comes from the seminal paper by Bart Wronski ([https://bartwronski.files.wordpress.com/2014/08/bwronski_volumetric_fog_siggraph2014.pdf](https://bartwronski.files.wordpress.com/2014/08/bwronski_volumetric_fog_siggraph2014.pdf)) at Siggraph 2014, where he described what is still the core idea behind this technique even after almost 10 years.

Implementing this technique will also be important for learning more about the synergies between different rendering parts of a frame: developing a single technique can be challenging, but the interaction with the rest of the technology is a very important part as well and can add to the challenge of the technique

In this chapter, we’ll cover the following main topics:

- Introducing Volumetric Fog rendering


- Implementing the Volumetric Fog base technique


- Adding spatial and temporal filtering to improve visuals




By the end of this chapter, we will have Volumetric Fog integrated into the Raptor Engine, interacting with the scenery and all the dynamic lights, as shown in the following figure:



 ![Figure 10.1 – Volumetric Fog with a density volume and three shadow casting lights](image/B18395_10_01.jpg)


Figure 10.1 – Volumetric Fog with a density volume and three shadow casting lights

# 技术需求
本章代码见以下链接： [https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter10](https://github.com/PacktPublishing/Mastering-Graphics-Programming-with-Vulkan/tree/main/source/chapter10).

# Introducing Volumetric Fog Rendering


What exactly is **Volumetric Fog Rendering**? As the name suggests, it is the combination of Volumetric Rendering and the fog phenomena. We will now give some background on those components and see how they are combined in the final technique.

Let’s begin with Volumetric Rendering.

## Volumetric Rendering


This rendering technique describes the visuals associated with what happens to light when it travels through a participating medium. A participating medium is a volume that contains local changes to density or albedo.

The following diagram summarizes what happens to photons in a participating medium:



 ![Figure 10.2 – Light behavior in a participating medium](image/B18395_10_02.jpg)


Figure 10.2 – Light behavior in a participating medium

What we are trying to describe is how light changes when going through a participating medium, namely a fog volume (or clouds or atmospheric scattering).

There are three main phenomena that happen, as follows:

- **Absorption**: This happens when light is simply trapped inside the medium and does not go outside. It is a net loss of energy.


- **Out-scattering**: This is depicted using green arrows in *Figure 10**.2* and is again a loss of energy coming out (and thus visible) from the medium.


- **In-scattering**: This is the energy coming from the lights that are interacting with the medium.




While these three phenomena are enough to describe what happens to light, there are three other components that need to be understood before having a complete picture of volumetric rendering.

### Phase function


The first component is the **phase function**. This function describes the scattering of light in different directions. It is dependent on the angle between the light vector and the outgoing directions.

This function can be complex and tries to describe scattering in a realistic way, but the most commonly used is the Henyey-Greenstein function, a function that also takes into consideration anisotropy.

The formula for the Henyey-Greenstein function is as follows:



 ![Figure 10.3 – The Henyey-Greenstein function](image/B18395_10_03.jpg)


Figure 10.3 – The Henyey-Greenstein function

In the preceding equation, the angle theta is the angle between the view vector and the light vector. We will see in the shader code how to translate this to something usable.

### Extinction


The second component is **extinction**. Extinction is a quantity that describes how much light is scattered. We will use this in the intermediate steps of the algorithm, but to apply the calculated fog, we will need transmittance.

### Transmittance


The third and final component is **transmittance**. Transmittance is the extinction of light through a segment of the medium, and it is calculated using the Beer-Lambert law:



 ![Figure 10.4 – The Beer-Lambert law](image/B18395_10_04.jpg)


Figure 10.4 – The Beer-Lambert law

In the final integration step, we will calculate the transmittance and use it to choose how to apply fog to the scene. The important thing here is to get a basic grasp of the concepts; there will be links provided to deepen your understanding of the mathematical background at the end of the chapter.

We now have all the concepts needed to see the implementation details of Volumetric Fog.

## Volumetric Fog


Now that we have an idea of the different components that contribute to Volumetric Rendering, we can take a bird’s-eye view of the algorithm. One of the first and most clever ideas that Bart Wronski had while developing this technique is the usage of a Frustum Aligned Volume Texture, like so:



 ![Figure 10.5 – Frustum Aligned Volume Texture](image/B18395_10_05.jpg)


Figure 10.5 – Frustum Aligned Volume Texture

Using a volume texture and math associated with standard rasterization rendering, we can create a mapping between the camera frustum and the texture. This mapping is already happening in the different stages of rendering, for example, when multiplying a vertex position for the view-projection matrix, so it is not something new.

What is new is storing information in a volume texture to calculate the volumetric rendering. Each element of this texture is commonly called the **froxel**, that stands for **frustum voxel**.

We chose to have a texture with a width, height, and depth of 128 units, but other solutions use a width and height dependent on the screen resolution, similar to clustered shading.

We will use different textures with this resolution as an intermediate step, and for additional filtering, we will discuss this later. One additional decision is to increase the resolution of the camera by using a non-linear depth distribution to map a linear range to an exponential one.

We will use a distribution function, such as the one used by Id in their iD Tech engine, like so:



 ![Figure 10.6 – Volume texture depth slice on the Z coordinate function](image/B18395_10_06.jpg)


Figure 10.6 – Volume texture depth slice on the Z coordinate function

Now that we have decided on the mapping between the volumetric texture and world units, we can describe the steps needed to have a fully working Volumetric Fog solution.

The algorithm is outlined in the following diagram, where rectangles represent shader executions while ellipses represent textures:



 ![Figure 10.7 – Algorithm overview](image/B18395_10_07.jpg)


Figure 10.7 – Algorithm overview

We will now see each step of the algorithm to create a mind model of what is happening, and we will review the shader later in the chapter.

### Data injection


The first step is the data injection. This shader will add some colored fog in the form of color and density into the first Frustum Aligned Texture containing only data. We decided to add a constant fog, a height-based fog, and a fog volume to mimic a more realistic game development setup.

### Light scattering


When performing the light scattering, we calculate the in-scattering coming from the lights in the scene.

Having a working Clustered Lighting algorithm, we will reuse the same data structures to calculate the light contribution for each froxel, paying attention to treating the light in a different way than the standard Clustered Lighting – we don’t have diffuse or specular here, but just a global term given by attenuation, shadow, and phase.

We also sample shadow maps associated with the lights for even more realistic behavior.

### Spatial filtering


To remove some of the noise, we apply a Gaussian filter only on the *X* and *Y* axis of the Frustum Aligned Texture, and then we pass to the most important filter, the temporal one.

### Temporal filtering


This filter is what really improves the visuals by giving the possibility of adding some noise at different steps of the algorithm to remove some banding. It will read the previous frame’s final texture (the one before the integration) and blend the current light scattering result with the previous one based on some constant factor.

This is a very difficult topic, as temporal filtering and reprojection can cause a few issues. We will have a much bigger discussion in the next chapter when talking about **Temporal ****Anti-Aliasing** (**TAA**)

With the scattering and extinction finalized, we can perform the light integration and thus prepare the texture that will be sampled by the scene.

### Light integration


This step prepares another Frustum Aligned Volumetric Texture to contain an integration of the fog. Basically, this shader simulates a low-resolution ray marching so that this result can be sampled by the scene.

Ray marching normally starts from the camera toward the far plane of the scene. The combination of the Frustum Aligned Texture and this integration gives, for each froxel, a cached ray marching of the light scattering to be easily sampled by the scene. In this step, from all the extinction saved in previous textures, we finally calculate the transmittance with the Beer-Lambert law and use that to merge the fog into the scene.

This and temporal filtering are some of the big innovations that unlocked the real-time possibility of this algorithm. In more advanced solutions, such as in the game Red Dead Redemption 2, an additional ray marching can be added to simulate fog at much further distances.

It also allows for blending fog and Volumetric Clouds, which use a pure ray marching approach, to have an almost seamless transition. This is explained in detail in the Siggraph presentation about Red Dead Redemption 2 rendering.

### Scene application in Clustered Lighting


The final step is to read the Volumetric Texture in the lighting shader using the world position. We can read the depth buffer, calculate the world position, calculate the froxel coordinates and sample the texture.

An additional step to further smooth the volumetric look is to render to a half-resolution texture the scene application and then apply it to the scene with a geometry-aware upsampling, but this will be left as an exercise for you to complete.

# Implementing Volumetric Fog Rendering


We now have all the knowledge necessary to read the code needed to get this algorithm fully working. From a CPU perspective, it is just a series of compute shaders dispatches, so it is straightforward.

The core of this technique is implemented throughout various shaders, and thus on the GPU, working for almost all steps on the frustum aligned Volumetric Texture we talked about in the previous section.

*Figure 10**.7* shows the different algorithm steps, and we will see each one individually in the following sections.

## Data injection


In the first shader, we will write scattering and extinction, starting from the color and density of different fog phenomena.

We decided to add three different fog effects, as follows:

- A constant fog


- Height fog


- Fog in a volume




For each fog, we need to calculate scattering and extinction and accumulate them.

The following code converts color and density to scattering and extinction:

```
vec4 scattering_extinction_from_color_density( vec3 color,
&#160;&#160;&#160;&#160;float density ) {
&#160;&#160;&#160;&#160;const float extinction = scattering_factor * density;
&#160;&#160;&#160;&#160;return vec4( color * extinction, extinction );
}
```


We can now have a look at the main shader. This shader, as most of the others in this chapter, will be scheduled to have one thread for one froxel cell.

In the first section, we will see the dispatch and code to calculate world position:

```
layout (local_size_x = 8, local_size_y = 8, local_size_z =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1) in;
void main() {
&#160;&#160;&#160;&#160;ivec3 froxel_coord = ivec3(gl_GlobalInvocationID.xyz);
&#160;&#160;&#160;&#160;vec3 world_position = world_from_froxel(froxel_coord);
&#160;&#160;&#160;&#160;vec4 scattering_extinction = vec4(0);
```


We add an optional noise to animate the fog and break the constant density:

```
&#160;&#160;&#160;&#160;vec3 sampling_coord = world_position *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;volumetric_noise_position_multiplier +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(1,0.1,2) * current_frame *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;volumetric_noise_speed_multiplier;
&#160;&#160;&#160;&#160;vec4 sampled_noise = texture(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;global_textures_3d[volumetric_noise_texture_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;sampling_coord);
&#160;&#160;&#160;&#160;float fog_noise = sampled_noise.x;
```


Here, we add and accumulate constant fog:

```
&#160;&#160;&#160;&#160;// Add constant fog
&#160;&#160;&#160;&#160;float fog_density = density_modifier * fog_noise;
&#160;&#160;&#160;&#160;scattering_extinction +=
&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction_from_color_density(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(0.5), fog_density );
```


Then, add and accumulate height fog:

```
&#160;&#160;&#160;&#160;// Add height fog
&#160;&#160;&#160;&#160;float height_fog = height_fog_density *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;exp(-height_fog_falloff * max(world_position.y, 0)) *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;fog_noise;
&#160;&#160;&#160;&#160;scattering_extinction +=
&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction_from_color_density(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3(0.5), height_fog );
```


And finally, add density from a box:

```
&#160;&#160;&#160;&#160;// Add density from box
&#160;&#160;&#160;&#160;vec3 box = abs(world_position - box_position);
&#160;&#160;&#160;&#160;if (all(lessThanEqual(box, box_size))) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4 box_fog_color = unpack_color_rgba( box_color
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction +=
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction_from_color_density(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;box_fog_color.rgb, box_fog_density *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;fog_noise);
&#160;&#160;&#160;&#160;}
```


We finally store the scattering and extinction, ready to be lit in the next shader:

```
&#160;&#160;&#160;&#160;imageStore(global_images_3d[froxel_data_texture_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord.xyz, scattering_extinction );
}
```



## Calculating the lighting contribution


Lighting will be performed using the Clustered Lighting data structures already used in general lighting functions. In this shader, we calculate the in-scattering of light.

Shader dispatching is the same as for the previous shader, one thread for one froxel:

```
layout (local_size_x = 8, local_size_y = 8, local_size_z =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1) in;
void main() {
&#160;&#160;&#160;&#160;ivec3 froxel_coord = ivec3(gl_GlobalInvocationID.xyz);
&#160;&#160;&#160;&#160;vec3 world_position = world_from_froxel(froxel_coord);
&#160;&#160;&#160;&#160;vec3 rcp_froxel_dim = 1.0f / froxel_dimensions.xyz;
```


We read scattering and extinction from the result of the injection shader:

```
vec4 scattering_extinction = texture(global_textures_3d
&#160;&#160;&#160;[nonuniformEXT(froxel_data_texture_index)],
&#160;&#160;&#160;froxel_coord * rcp_froxel_dim);
&#160;&#160;&#160;float extinction = scattering_extinction.a;
```


We then start accumulating light and using clustered bins.

Notice the cooperation between different rendering algorithms: having the clustered bin already developed, we can use that to query lights in a defined volume starting from the world space position:

```
vec3 lighting = vec3(0);
vec3 V = normalize(camera_position.xyz - world_position);
// Read clustered lighting data
// Calculate linear depth
float linear_d = froxel_coord.z * 1.0f /
&#160;&#160;&#160;froxel_dimension_z;
linear_d = raw_depth_to_linear_depth(linear_d,
&#160;&#160;&#160;froxel_near, froxel_far) / froxel_far;
// Select bin
int bin_index = int( linear_d / BIN_WIDTH );
uint bin_value = bins[ bin_index ];
// As in calculate_lighting method, cycle through
// lights to calculate contribution
for ( uint light_id = min_light_id;
&#160;&#160;&#160;&#160;light_id <= max_light_id;
&#160;&#160;&#160;&#160;++light_id ) {
&#160;&#160;&#160;&#160;// Same as calculate_lighting method
&#160;&#160;&#160;&#160;// Calculate point light contribution
&#160;&#160;&#160;&#160;// Read shadow map for current light
&#160;&#160;&#160;&#160;float shadow = current_depth –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;bias < closest_depth ? 1 : 0;
&#160;&#160;&#160;&#160;const vec3 L = normalize(light_position –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_position);
&#160;&#160;&#160;&#160;float attenuation = attenuation_square_falloff(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;L, 1.0f / light_radius) * shadow;
```


Up until now, the code is almost identical to the one used in lighting, but we add **phase_function** to finalize the lighting factor:

```
&#160;&#160;&#160;&#160;lighting += point_light.color *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;point_light.intensity *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;phase_function(V, -L,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;phase_anisotropy_01) *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;attenuation;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
```


Final scattering is calculated and stored, as follows:

```
vec3 scattering = scattering_extinction.rgb * lighting;
imageStore( global_images_3d
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;[light_scattering_texture_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec3(froxel_coord.xyz), vec4(scattering,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;extinction) );
}
```


We will now have a look at the integration/ray marching shader to conclude the main shaders needed to have the algorithm work for the volumetric part.

## Integrating scattering and extinction


This shader is responsible for performing the ray marching in the froxel texture and performing the intermediate calculations in each cell. It will still write in a frustum-aligned texture, but each cell will contain the accumulated scattering and transmittance starting from that cell.

Notice that we now use transmittance instead of extinction, transmittance being a quantity that integrates extinction to a certain space. The dispatch is just on the *X* and *Y* axis of the frustum texture, reading the light scattering texture, as we will perform the integration steps and write to each froxel in the main loop.

The final stored result is scattering and transmittance, so it can be easier to apply it to the scene:

```
// Dispatch with Z = 1 as we perform the integration.
layout (local_size_x = 8, local_size_y = 8, local_size_z =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1) in;
void main() {
&#160;&#160;&#160;&#160;ivec3 froxel_coord = ivec3(gl_GlobalInvocationID.xyz);
&#160;&#160;&#160;&#160;vec3 integrated_scattering = vec3(0,0,0);
&#160;&#160;&#160;&#160;float integrated_transmittance = 1.0f;
&#160;&#160;&#160;&#160;float current_z = 0;
&#160;&#160;&#160;&#160;vec3 rcp_froxel_dim = 1.0f / froxel_dimensions.xyz;
```


We integrate on the *Z* axis as this texture is frustum aligned.

First, we calculate the depth difference to have the thickness needed for the extinction integral:

```
&#160;&#160;&#160;&#160;for ( int z = 0; z < froxel_dimension_z; ++z ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord.z = z;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float next_z = slice_to_exponential_depth(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_near, froxel_far, z + 1,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;int(froxel_dimension_z) );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const float z_step = abs(next_z - current_z);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;current_z = next_z;
```


We will calculate scattering and transmittance and accumulate them for the following cell on the *Z* axis:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Following equations from Physically Based Sky,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;Atmosphere and Cloud Rendering by Hillaire
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const vec4 sampled_scattering_extinction =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture(global_textures_3d[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(light_scattering_texture_index)],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord * rcp_froxel_dim);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const vec3 sampled_scattering =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sampled_scattering_extinction.xyz;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const float sampled_extinction =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sampled_scattering_extinction.w;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const float clamped_extinction =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;max(sampled_extinction, 0.00001f);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const float transmittance = exp(-sampled_extinction
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;* z_step);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const vec3 scattering = (sampled_scattering –
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(sampled_scattering *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;transmittance)) /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;clamped_extinction;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;integrated_scattering += scattering *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;integrated_transmittance;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;integrated_transmittance *= transmittance;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;imageStore( global_images_3d[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;integrated_light_scattering_texture_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord.xyz,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4(integrated_scattering,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;integrated_transmittance) );
&#160;&#160;&#160;&#160;}
}
```


We now have a volume texture containing ray marched scattering and transmittance values that can be queried from anywhere in the frame to know how much fog there is and what color it is at that point.

This concludes the main volumetric rendering aspect of the algorithm. We will now have a look at how easy it is to apply the fog to a scene.

## Applying Volumetric Fog to the scene


We can finally apply the Volumetric Fog. To do that, we use the screen space coordinates to calculate the sampling coordinates for the texture. This function will be used at the end of the lighting calculations for both deferred and forward rendering paths.

We first calculate the sampling coordinates:

```
vec3 apply_volumetric_fog( vec2 screen_uv, float raw_depth,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 color ) {
&#160;&#160;&#160;&#160;const float near = volumetric_fog_near;
&#160;&#160;&#160;&#160;const float far = volumetric_fog_far;
&#160;&#160;&#160;&#160;// Fog linear depth distribution
&#160;&#160;&#160;&#160;float linear_depth = raw_depth_to_linear_depth(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;raw_depth, near, far );
&#160;&#160;&#160;&#160;// Exponential
&#160;&#160;&#160;&#160;float depth_uv = linear_depth_to_uv( near, far,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;linear_depth, volumetric_fog_num_slices );
vec4 scattering_transmittance =
&#160;&#160;&#160;texture(global_textures_3d
&#160;&#160;&#160;[nonuniformEXT(volumetric_fog_texture_index)],
&#160;&#160;&#160;froxel_uvw);
```


After we read the scattering and transmittance at the specified position, we use the transmittance to modulate the current scene color and add the fog scattered color, like so:

```
&#160;&#160;&#160;&#160;color.rgb = color.rgb * scattering_transmittance.a +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_transmittance.rgb;
&#160;&#160;&#160;&#160;return color;
}
```


And this concludes the necessary steps to fully implement Volumetric Fog rendering. But still, there is a big problem: **banding**.

This is a large topic covered in several papers, but for the sake of simplicity, we can say that having a low-resolution volume texture adds banding problems, but it is necessary for achieving real-time performance.

## Adding filters


To further improve the visuals, we add two different filters: a temporal and a spatial one.

The temporal filter is what really makes the difference because it gives us the possibility of adding noise in different parts of the algorithm and thus removing banding. The spatial filter smooths out the fog even further.

### Spatial filtering


This shader will smooth out the volumetric texture in the *X* and *Y* axis by applying a Gaussian filter. It will read the result of the light scattering and write into the froxel data texture, unused at this point of the frame, removing the need to create a temporary texture.

We first define the Gaussian function and its representing code:

```
#define SIGMA_FILTER 4.0
#define RADIUS 2
float gaussian(float radius, float sigma) {
&#160;&#160;&#160;&#160;const float v = radius / sigma;
&#160;&#160;&#160;&#160;return exp(-(v*v));
}
```


We then read the light scattering texture and accumulate values and weight only if the calculated coordinates are valid:

```
&#160;&#160;&#160;&#160;vec4 scattering_extinction =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture( global_textures_3d[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(light_scattering_texture_index)],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord * rcp_froxel_dim );
&#160;&#160;&#160;&#160;if ( use_spatial_filtering == 1 ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float accumulated_weight = 0;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4 accumulated_scattering_extinction = vec4(0);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;for (int i = -RADIUS; i <= RADIUS; ++i ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;for (int j = -RADIUS; j <= RADIUS; ++j ) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec3 coord = froxel_coord + ivec3(i, j,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;0);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// if inside
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if (all(greaterThanEqual(coord, ivec3(0)))
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&& all(lessThanEqual(coord,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ivec3(froxel_dimension_x,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_dimension_y,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_dimension_z)))) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const float weight =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;gaussian(length(ivec2(i, j)),
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;SIGMA_FILTER);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;const vec4 sampled_value =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture(global_textures_3d[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;light_scattering_texture_index)],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;coord * rcp_froxel_dim);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accumulated_scattering_extinction.rgba +=
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sampled_value.rgba * weight;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accumulated_weight += weight;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accumulated_scattering_extinction /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;accumulated_weight;
&#160;&#160;&#160;&#160;}
```


We store the result in the froxel data texture:

```
&#160;&#160;&#160;&#160;imageStore(global_images_3d[froxel_data_texture_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord.xyz, scattering_extinction );
}
```


The next step is temporal filtering.

### Temporal filtering


This shader will take the currently calculated 3D light scattering texture and apply a temporal filter. In order to do that it will need two textures, one for the current and one for the previous frame, and thanks to bindless, we just need to change the indices to use them.

Dispatch is like most of the shaders in this chapter, with one thread for each froxel element of the volume texture. Let’s begin with reading the current light scattering texture.

This currently resides in **froxel_data_texture**, coming from the spatial filtering:

```
&#160;&#160;&#160;&#160;vec4 scattering_extinction =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;texture( global_textures_3d[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(froxel_data_texture_index)],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord * rcp_froxel_dim );
```


We need to calculate the previous screen space position to read the previous frame texture.

We will calculate the world position and then use the previous view projection to get the UVW coordinates to read the texture:

```
&#160;&#160;&#160;&#160;// Temporal reprojection
&#160;&#160;&#160;&#160;if (use_temporal_reprojection == 1) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 world_position_no_jitter =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;world_from_froxel_no_jitter(froxel_coord);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4 sceen_space_center_last =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;previous_view_projection *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4(world_position_no_jitter, 1.0);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 ndc = sceen_space_center_last.xyz /
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;sceen_space_center_last.w;
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float linear_depth = raw_depth_to_linear_depth(
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;ndc.z, froxel_near, froxel_far
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float depth_uv = linear_depth_to_uv( froxel_near,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_far, linear_depth,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;int(froxel_dimension_z) );
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec3 history_uv = vec3( ndc.x * .5 + .5, ndc.y * -
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;.5 + .5, depth_uv );
```


We then check whether the calculated UVWs are valid and if so, we will read the previous texture:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// If history UV is outside the frustum, skip
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;if (all(greaterThanEqual(history_uv, vec3(0.0f)))
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&& all(lessThanEqual(history_uv, vec3(1.0f)))) {
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;// Fetch history sample
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;vec4 history = textureLod(global_textures_3d[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;previous_light_scattering_texture_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;history_uv, 0.0f);
```


Once we read the sample, we can merge the current result with the previous one based on a user-defined percentage:

```
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction.rgb = mix(history.rgb,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction.rgb,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;temporal_reprojection_percentage);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction.a = mix(history.a,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scattering_extinction.a,
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;temporal_reprojection_percentage);
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;}
&#160;&#160;&#160;&#160;}
```


We store the result back into the light scattering texture so that the integration can use it for the last step of the volumetric side of the algorithm.

```
&#160;&#160;&#160;&#160;imageStore(global_images_3d[light_scattering_texture_in
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;dex],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;froxel_coord.xyz, scattering_extinction );
}
```


At this point, we have seen all of the steps for the complete algorithm for the Volumetric Fog.

The last thing to see is the volumetric noise generation used to animate the fog and briefly talk about noise and jittering used to remove banding.

## Volumetric noise generation


To break the fog density up a bit so that it is more interesting, we can sample a volumetric noise texture to modify the density a little. We can add a single execution compute shader that creates and stores Perlin noise in a 3D texture and then reads it when sampling the fog density.

Additionally, we can animate this noise to simulate wind animation. The shader is straightforward and uses Perlin noise functions as follows:

```
layout (local_size_x = 8, local_size_y = 8, local_size_z =
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;1) in;
void main() {
&#160;&#160;&#160;&#160;ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);
&#160;&#160;&#160;&#160;vec3 xyz = pos / volumetric_noise_texture_size;
&#160;&#160;&#160;&#160;float perlin_data = get_perlin_7_octaves(xyz, 4.0);
&#160;&#160;&#160;&#160;imageStore( global_images_3d[output_texture_index],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;pos, vec4(perlin_data, 0, 0, 0) );
}
```


The result is a volume texture with a single channel and Perlin noise to be sampled. We also use a special Sampler that has a repeat filter on the *U*, *V,* and *W* axes.

## Blue noise


As an additional noise used to offset sampling in different areas of the algorithm, we use blue noise, reading it from a texture and adding a temporal component to it.

There are many interesting properties of blue noise and much literature on why it is a great noise for visual perception, and we will post links at the end of this chapter, but for now, we just read the noise from a texture with two channels and map it to the **–1** to **1** range.

The mapping function is as follows:

```
float triangular_mapping( float noise0, float noise1 ) {
&#160;&#160;&#160;&#160;return noise0 + noise1 - 1.0f;
}
```


And the following is performed to read the blue noise:

```
float generate_noise(vec2 pixel, int frame, float scale) {
&#160;&#160;&#160;&#160;vec2 uv = vec2(pixel.xy / blue_noise_dimensions.xy);
&#160;&#160;&#160;&#160;// Read blue noise from texture
&#160;&#160;&#160;&#160;vec2 blue_noise = texture(global_textures[
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;nonuniformEXT(blue_noise_128_rg_texture_index)],
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;uv ).rg;
&#160;&#160;&#160;&#160;const float k_golden_ratio_conjugate = 0.61803398875;
&#160;&#160;&#160;&#160;float blue_noise0 = fract(ToLinear1(blue_noise.r) +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float(frame % 256) * k_golden_ratio_conjugate);
&#160;&#160;&#160;&#160;float blue_noise1 = fract(ToLinear1(blue_noise.g) +
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;float(frame % 256) * k_golden_ratio_conjugate);
&#160;&#160;&#160;&#160;return triangular_noise(blue_noise0, blue_noise1) *
&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;scale;
}
```


The final value will be between **–1** and **1** and can be scaled to any need and used everywhere.

There is an animated blue noise paper that promises even better quality, but due to licensing problems, we opted to use this free version.

# 小结
In this chapter, we introduced the Volumetric Fog rendering technique. We provided a brief mathematical background and algorithmic overview before showing the code. We also showed the different techniques available to improve banding – a vast topic that requires a careful balance of noise and temporal reprojection.

The algorithm presented is also an almost complete implementation that can be found behind many commercial games. We also talked about filtering, especially the temporal filter, which is linked to the next chapter, where we will talk about an anti-aliasing technique that uses temporal reprojection.

In the next chapter, we will see how the synergy between Temporal Anti-Aliasing and noises used to jitter the sampling in Volumetric Fog will ease out the visual bandings. We will also show a feasible way to generate custom textures with a single-use compute shader used to generate a volumetric noise.

This technique is also used for other volumetric algorithms, such as Volumetric Clouds, to store more custom noises used for generating the cloud shapes.

# 延伸阅读
There are many different papers that are referenced in this chapter, but the most important is the *Real-Time Volumetric Rendering* paper for general GPU-based volumetric rendering: [https://patapom.com/topics/Revision2013/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes.pdf](https://patapom.com/topics/Revision2013/Revision%202013%20-%20Real-time%20Volumetric%20Rendering%20Course%20Notes.pdf).

The algorithm is still a derivation of the seminal paper from Bart Wronski: [https://bartwronski.files.wordpress.com/2014/08/bwronski_volumetric_fog_siggraph2014.pdf](https://bartwronski.files.wordpress.com/2014/08/bwronski_volumetric_fog_siggraph2014.pdf).

With some evolutions and mathematical improvements in the following link: [https://www.ea.com/frostbite/news/physically-based-unified-volumetric-rendering-in-frostbite](https://www.ea.com/frostbite/news/physically-based-unified-volumetric-rendering-in-frostbite).

For the depth distribution, we referenced the formula used in iD Tech 6: [https://advances.realtimerendering.com/s2016/Siggraph2016_idTech6.pdf](https://advances.realtimerendering.com/s2016/Siggraph2016_idTech6.pdf).

For banding and noise, the most comprehensive papers come from Playdead:

- [https://loopit.dk/rendering_inside.pdf](https://loopit.dk/rendering_inside.pdf)


- [https://loopit.dk/banding_in_games.pdf](https://loopit.dk/banding_in_games.pdf)




For information on animated blue noise: [https://blog.demofox.org/2017/10/31/animating-noise-for-integration-over-time/](https://blog.demofox.org/2017/10/31/animating-noise-for-integration-over-time/)

For information on dithering, blue noise, and the golden ratio sequence:[ https://bartwronski.com/2016/10/30/dithering-part-two-golden-ratio-sequence-blue-noise-and-highpass-and-remap/](https://bartwronski.com/2016/10/30/dithering-part-two-golden-ratio-sequence-blue-noise-and-highpass-and-remap/)

A free blue noise texture can be found here: [http://momentsingraphics.de/BlueNoise.html](http://momentsingraphics.de/BlueNoise.html).