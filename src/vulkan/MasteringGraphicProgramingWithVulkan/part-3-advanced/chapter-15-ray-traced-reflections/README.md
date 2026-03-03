Adding Reflections with Ray
Tracing
In this chapter, we are going to implement reflections using ray tracing.
Before ray tracing hardware was introduced, applications implemented
reflections using screen-space techniques. However, this technique has
drawbacks as it can only use information from what’s visible on the
screen. If one of the rays goes outside the visible geometry on the
screen, we usually fall back to an environment map. Because of this
limitation, the rendered reflections can be inconsistent, depending on
the camera position.
By introducing ray tracing hardware, we can overcome this limitation
as we now have access to geometry that is not visible on the screen. The
downside is that we might need to perform some expensive lighting
computations. If the reflected geometry is outside the screen, this means
we don’t have the data from the G-buffer and we need to compute the
color, light, and shadow data from scratch.
To lower the cost of this technique, developers usually trace reflections
at half resolution or use ray tracing only if screen-space reflection fails.
Another approach is to use lower-resolution geometry in the ray tracing
path to lower the cost of ray traversal. In this chapter, we are going to
implement a ray tracing-only solution, as this gives the best-quality
results. Then, it will be easy to implement the optimizations mentioned
previously on top of it.
In this chapter, we’ll cover the following main topics:
• How screen-space reflections work
• Implementing ray-traced reflections
• Implementing a denoiser to make the ray-traced output usable
Technical requirements
By the end of the chapter, you will have a good understanding of the
different solutions available for reflections. You will also learn how to
implement ray-traced reflections and how to improve the final result
with the help of a denoiser.
The code for this chapter can be found at the following URL: https://
github.com/PacktPublishing/Mastering-Graphics-Programming-with-
Vulkan/tree/main/source/chapter15.
How screen-space reflections
work
Reflections are an important rendering element that can provide a
better sense of immersion in the scene. For this reason, developers have
developed a few techniques over the years to include this effect, even
before ray tracing hardware was available.
One of the most common approaches is to ray-march the scene after the
G-buffer data becomes available. Whether a surface will produce
reflections is determined by the material’s roughness. Only materials
with a low roughness will emit a reflection. This also helps reduce the
cost of this technique since usually, only a low number of surfaces will
satisfy this requirement.
Ray marching is a technique similar to ray tracing and was introduced
in Chapter 10, Adding Volumetric Fog. As a quick reminder, ray marching
works similarly to ray tracing. Instead of traversing the scene to
determine whether the ray hit any geometry, we move in the ray’s
direction by small increments for a fixed number of iterations.
This has both advantages and disadvantages. The advantage is that this
technique has a fixed cost independent of the scene’s complexity as the
maximum number of iterations per ray is pre-determined. The downside
is that the quality of the results depends on the step size and the
number of iterations.
For the best quality, we want a large number of iterations and a small
step size, but this would make the technique too expensive. The
compromise is to use a step size that gives good enough results and then
pass the result through a denoising filter to try and reduce the artifacts
introduced by the low-frequency sampling.
As the name implies, this technique works in screen space, similar to
other techniques such as Screen-Space Ambient Occlusion (SSAO).
For a given fragment, we start by determining whether it produces a
reflection or not. If it does, we determine the reflected ray’s direction
based on the surface normal and view direction.
Next, we move along the reflected ray direction for the given number of
iterations and step size. At each step, we check against the depth buffer
to determine whether we hit any geometry. Since the depth buffer has a
limited resolution, usually, we define a delta value that determines
whether we consider a given iteration a hit.
If the difference between the ray depth and the value stored in the
depth buffer is under this delta, we can exit the loop; otherwise, we
must continue. The size of this delta can vary, depending on the scene’s
complexity, and is usually tweaked manually.
If the ray marching loop hits visible geometry, we look up the color
value at that fragment and use it as the reflected color. Otherwise, we
either return black or determine the reflected color using an
environment map.
We are skipping over some implementation details here as they are not
relevant to this chapter. We have provided resources that go into more
detail in the Further reading section.
As mentioned previously, this technique is limited to information that is
visible on screen. The main drawback is that reflections will disappear
as the camera moves if the reflected geometry is no longer rendered on
the screen. The other downside comes from ray marching as we have
limited resolution in terms of the number and size of steps we can take.
This can introduce holes in the reflection, which is usually addressed
through aggressive filtering. This can result in blurry reflections and
makes it difficult to obtain crisp reflections, depending on the scene and
viewpoint.
In this section, we introduced screen space reflections. We explained the
main ideas behind this technique and some of its shortcomings. In the
next section, we are going to implement ray-traced reflections, which
can reduce some of the limitations of this technique.
Implementing ray-traced
reflections
In this section, we are going to leverage the hardware ray tracing
capabilities to implement reflections. Before diving into the code, here’s
an overview of the algorithm:
1. We start with the G-buffer data. We check whether the roughness
for a given fragment is below a certain threshold. If it is, we move
to the next step. Otherwise, we don’t process this fragment any
further.
2. To make this technique viable in real time, we cast only one
reflection ray per fragment. We will demonstrate two ways to
pick the reflection’s ray direction: one that simulates a mirror-like
surface and another that samples the GGX distribution for a given
fragment.
3. If the reflection ray hits some geometry, we need to compute its
surface color. We shoot another ray toward a light that has been
selected through importance sampling. If the selected light is
visible, we compute the color for the surface using our standard
lighting model.
4. Since we are using only one sample per fragment, the final output
will be noisy, especially since we are randomly selecting the
reflected direction at each frame. For this reason, the output of
the ray tracing step will be processed by a denoiser. We have
implemented a technique called spatiotemporal variance-
guided filtering (SVGF), which has been developed specifically
for this use case. The algorithm will make use of spatial and
temporal data to produce a result that contains only a small
amount of noise.
5. Finally, we use the denoised data during our lighting computation
to retrieve the specular color.
Now that you have a good overview of the steps involved, let’s dive in!
The first step is checking whether the roughness for a given fragment is
above a certain threshold:
if ( roughness <= 0.3 ) {
We have selected 0.3 as it gives us the results we are looking for,
though feel free to experiment with other values. If this fragment is
contributing to the reflection computation, we initialize our random
number generator and compute the two values needed to sample the
GGX distribution:
rng_state = seed( gl_LaunchIDEXT.xy ) + current_frame;
float U1 = rand_pcg() * rnd_normalizer;
float U2 = rand_pcg() * rnd_normalizer;
The two random functions can be implemented as follows:
uint seed(uvec2 p) {
} return 19u * p.x + 47u * p.y + 101u;
uint rand_pcg() {
uint state = rng_state;
rng_state = rng_state * 747796405u + 2891336453u;
uint word = ((state >> ((state >> 28u) + 4u)) ^ state)
277803737u;
return (word >> 22u) ^ word;
}
These two functions have been taken from the wonderful Hash Functions
for GPU Rendering paper, which we highly recommend. It contains many
other functions that you can experiment with. We selected this seed
function so that we can use the fragment’s position.
Next, we need to pick our reflection vector. As mentioned previously,
we have implemented two techniques. For the first technique, we
simply reflect the view vector around the surface normal for a mirror-
like surface. This can be computed as follows:
vec3 reflected_ray = normalize( reflect( incoming, normal ) );
When using this method, we get the following output:
Figure 15.1 – Mirror-like reflections
The other method computes the normal by randomly sampling the GGX
distribution:
vec3 normal = sampleGGXVNDF( incoming, roughness, roughness,
U1, U2 );
vec3 reflected_ray = normalize( reflect( incoming, normal ) );
The sampleGGXVNDF function has been taken from the Sampling the
GGX Distribution of Visible Normals paper. Its implementation is clearly
described in this paper; we suggest you read it for more details.
In brief, this method computes a random normal according to the BRDF
of the material and the view direction. This process is needed to make
sure the computed reflection is more physically accurate.
Next, we must trace a ray in the scene:
traceRayEXT( as, // topLevel
gl_RayFlagsOpaqueEXT, // rayFlags
0xff, // cullMask
sbt_offset, // sbtRecordOffset
sbt_stride, // sbtRecordStride
miss_index, // missIndex
world_pos, // origin
0.05, // Tmin
reflected_ray, // direction
100.0, // Tmax
0 // payload index
);
If the ray has a hit, we use importance sampling to select a light for our
final color computation. The main idea behind importance sampling is
to determine which element, which light in our case, is more likely to
be selected based on a given probability distribution.
We have adopted the importance value described in the Importance
Sampling of Many Lights on the GPU chapter from the book Ray Tracing
Gems.
We start by looping through all the lights in the scene:
for ( uint l = 0; l < active_lights; ++l ) {
Light light = lights[ l ];
Next, we compute the angle between the light and the normal of the
triangle that has been hit:
vec3 p_to_light = light.world_position - p_world.xyz;
float point_light_angle = dot( normalize( p_to_light ),
triangle_normal );
 float theta_i = acos( point_light_angle );
Then, we compute the distance between the light and the fragment
position in the world space:
float distance_sq = dot( p_to_light, p_to_light );
float r_sq = light.radius * light.radius;
After, we use these two values to determine whether this light should be
considered for this fragment:
bool light_active = ( point_light_angle > 1e-4 ) && (
distance_sq <= r_sq );
The next step involves computing an orientation parameter. This tells us
whether the light is shining directly on the fragment or at an angle:
float theta_u = asin( light.radius / sqrt( distance_sq
) );
float theta_prime = max( 0, theta_i - theta_u );
float orientation = abs( cos( theta_prime ) );
Finally, we must compute the importance value by also taking into
account the intensity of the light:
float importance = ( light.intensity * orientation ) /
distance_sq;
float final_value = light_active ? importance : 0.0;
lights_importance[ l ] = final_value;
If the given light is not considered active for this fragment, its
importance will have a value of 0. Finally, we must accumulate the
importance value for this light:
} total_importance += final_value;
Now that we have the importance values, we need to normalize them.
Like any other probability distribution function, our values need to sum
to 1:
for ( uint l = 0; l < active_lights; ++l ) {
lights_importance[ l ] /= total_importance;
}
We can now select the light to be used for this frame. First, we must
generate a new random value:
float rnd_value = rand_pcg() * rnd_normalizer;
Next, we must loop through the lights and accumulate the importance
of each light. Once the accumulated value is greater than our random
value, we have found the light to use:
for ( ; light_index < active_lights; ++light_index ) {
accum_probability += lights_importance[ light_index ];
if ( accum_probability > rnd_value ) {
break;
}
}
Now that we have selected the light, we must cast a ray toward it to
determine whether it’s visible or not. If it’s visible, we compute the final
color for the reflected surface using our lighting model.
We compute the shadow factor as described in Chapter 13, Revisiting
Shadows with Ray Tracing, and the color is calculated in the same way as
in Chapter 14, Adding Dynamic Diffuse Global Illumination with Ray
Tracing.
This is the result:
Figure 15.2 – The noisy output of the ray tracing step
In this section, we illustrated our implementation of ray-traced
reflections. First, we described two ways to select a ray direction. Then,
we demonstrated how to use importance sampling to select the light to
use in our computation. Finally, we described how the selected light is
used to determine the final color of the reflected surface.
The result of this step will be noisy and cannot be used directly in our
lighting computation. In the next section, we will implement a denoiser
that will help us remove most of this noise.
Implementing a denoiser
To make the output of our reflection pass usable for lighting
computations, we need to pass it through a denoiser. We have
implemented an algorithm called SVGF, which has been developed to
reconstruct color data for path tracing.
SVGF consists of three main passes:
1. First, we compute the integrated color and moments for
luminance. This is the temporal step of the algorithm. We
combine the data from the previous frame with the result of the
current frame.
2. Next, we compute an estimate for variance. This is done using the
first and second moment values we computed in the first step.
3. Finally, we perform five passes of a wavelet filter. This is the
spatial step of the algorithm. At each iteration, we apply a 5x5
filter to reduce the remaining noise as much as possible.
Now that you have an idea of the main algorithm, we can proceed with
the code details. We start by computing the moments for the current
frame:
float u_1 = luminance( reflections_color );
float u_2 = u_1 * u_1;
vec2 moments = vec2( u_1, u_2 );
Next, we use the motion vectors value – the same values we computed
in Chapter 11, Temporal Anti-Aliasing – to determine whether we can
combine the data for the current frame with the previous frame.
First, we compute the position on the screen of the previous frame:
bool check_temporal_consistency( uvec2 frag_coord ) {
vec2 frag_coord_center = vec2( frag_coord ) + 0.5;
vec2 motion_vector = texelFetch( global_textures[
motion_vectors_texture_index ],
ivec2( frag_coord ), 0 ).rg;
vec2 prev_frag_coord = frag_coord_center +
motion_vector;
Next, we check whether the old fragment coordinates are valid:
if ( any( lessThan( prev_frag_coord, vec2( 0 ) ) ) ||
any( greaterThanEqual( prev_frag_coord,
resolution ) ) ) {
return false;
 }
Then, we check whether the mesh ID is consistent with the previous
frame:
uint mesh_id = texelFetch( global_utextures[
mesh_id_texture_index ],
ivec2( frag_coord ), 0 ).r;
uint prev_mesh_id = texelFetch( global_utextures[
history_mesh_id_texture_index ],
ivec2( prev_frag_coord ), 0 ).r;
if ( mesh_id != prev_mesh_id ) {
return false;
}
Next, we check for large depth discontinuities, which can be caused by
disocclusion from the previous frame. We make use of the difference
between the current and previous frame’s depth, and also of the screen
space derivative of the depth for the current frame:
float z = texelFetch( global_textures[
depth_texture_index ],
ivec2( frag_coord ), 0 ).r;
float prev_z = texelFetch( global_textures[
history_depth_texture ],
ivec2( prev_frag_coord ), 0
).r;
vec2 depth_normal_dd = texelFetch( global_textures[
depth_normal_dd_texture_index ],
ivec2( frag_coord ), 0 ).rg;
float depth_diff = abs( z - prev_z ) / (
depth_normal_dd.x + 1e-2 );
if ( depth_diff > 10 ) {
return false;
}
The last consistency check is done by using the normal value:
float normal_diff = distance( normal, prev_normal ) / (
depth_normal_dd.y + 1e-2
);
if ( normal_diff > 16.0 ) {
return false;
}
If all of these tests pass, this means the values from the previous frame
can be used for temporal accumulation:
if ( is_consistent ) {
vec3 history_reflections_color = texelFetch(
global_textures[ history_reflections_texture_index ],
ivec2( frag_coord ), 0 ).rgb;
vec2 history_moments = texelFetch( global_textures[
history_moments_texture_index ],
ivec2( frag_coord ), 0 ).rg;
float alpha = 0.2;
integrated_color_out = reflections_color * alpha +
( 1 - alpha ) * history_reflections_color;
integrated_moments_out = moments * alpha + ( 1 - alpha
) * moments;
If the consistency check fails, we will only use the data from the current
frame:
} else {
integrated_color_out = reflections_color;
integrated_moments_out = moments;
}
This concludes the accumulation pass. This is the output we obtain:
Figure 15.3 – The color output after the accumulation step
The next step is to compute the variance. This can easily be done as
follows:
float variance = moments.y - pow( moments.x, 2 );
Now that we have our accumulated value, we can start implementing
the wavelet filter. As mentioned previously, this is a 5x5 cross-bilateral
filter. We start with the familiar double loop, being careful not to access
out-of-bounds values:
for ( int y = -2; y <= 2; ++y) {
for( int x = -2; x <= 2; ++x ) {
ivec2 offset = ivec2( x, y );
ivec2 q = frag_coord + offset;
if ( any( lessThan( q, ivec2( 0 ) ) ) || any(
greaterThanEqual( q, ivec2( resolution ) ) ) )
{
continue;
 }
Next, we compute the filter kernel value and weighting value, w:
float h_q = h[ x + 2 ] * h[ y + 2 ];
float w_pq = compute_w( frag_coord, q );
float sample_weight = h_q * w_pq;
We’ll explain the implementation of the weighting function in a
moment. Next, we load the integrated color and variance for the given
fragment:
vec3 c_q = texelFetch( global_textures[
integrated_color_texture_index ], q, 0 ).rgb;
float prev_variance = texelFetch( global_textures[
variance_texture_index ], q, 0 ).r;
Lastly, we accumulate the new color and variance values:
new_filtered_color += h_q * w_pq * c_q;
color_weight += sample_weight;
new_variance += pow( h_q, 2 ) * pow( w_pq, 2 ) *
prev_variance;
variance_weight += pow( sample_weight, 2 );
}
}
Before storing the newly computed values, we need to divide them by
the accumulated weight:
new_filtered_color /= color_weight;
new_variance /= variance_weight;
We repeat this process five times. The resulting color output will be
used for our lighting computation for the specular color.
As promised, we are now going to look at the weight computation.
There are three elements to the weight: normal, depth, and luminance.
In the code, we tried to follow the naming from the paper so that it’s
easier to match with our implementation of the formulas.
We start with the normals:
vec2 encoded_normal_p = texelFetch( global_textures[
normals_texture_index ], p, 0 ).rg;
vec3 n_p = octahedral_decode( encoded_normal_p );
vec2 encoded_normal_q = texelFetch( global_textures[
normals_texture_index ], q, 0 ).rg;
vec3 n_q = octahedral_decode( encoded_normal_q );
float w_n = pow( max( 0, dot( n_p, n_q ) ), sigma_n );
We compute the cosine between the normal of the current fragment and
the fragment from the filter to determine the weight of the normal
component.
We look at depth next:
float z_dd = texelFetch( global_textures[ depth_normal_dd_
texture_index ], p, 0 ).r;
float z_p = texelFetch( global_textures[ depth_texture_index ],
p, 0 ).r;
float z_q = texelFetch( global_textures[ depth_texture_index ],
q, 0 ).r;
float w_z = exp( -( abs( z_p – z_q ) / ( sigma_z * abs(
z_dd ) + 1e-8 ) ) );
In a similar fashion to the accumulation step, we make use of the
difference between the depth values between two fragments. The
screen-space derivative is also included. As before, we want to penalize
large depth discontinuities.
The last weight element is luminance. We start by computing the
luminance for the fragments we are processing:
vec3 c_p = texelFetch( global_textures[ integrated_color_
texture_index ], p, 0 ).rgb;
vec3 c_q = texelFetch( global_textures[ integrated_color_
texture_index ], q, 0 ).rgb;
float l_p = luminance( c_p );
float l_q = luminance( c_q );
Next, we pass the variance value through a Gaussian filter to reduce
instabilities:
float g = 0.0;
const int radius = 1;
for ( int yy = -radius; yy <= radius; yy++ ) {
for ( int xx = -radius; xx <= radius; xx++ ) {
ivec2 s = p + ivec2( xx, yy );
float k = kernel[ abs( xx ) ][ abs( yy ) ];
float v = texelFetch( global_textures[
variance_texture_index ], s, 0 ).r;
g += v * k;
}
}
Finally, we compute the luminance weight and combine it with the
other two weight values:
float w_l = exp( -( abs( l_p - l_q ) / ( sigma_l * sqrt
( g ) + 1e-8 ) ) );
return w_z * w_n * w_l;
This concludes our implementation of the SVGF algorithm. After five
passes, we get the following output:
Figure 15.4 – The output at the end of the denoising step
In this section, we described how to implement a common denoising
algorithm. The algorithm consists of three passes: an accumulation
phase for the color and luminance moments, a step for computing
luminance variance, and a step for the wavelet filter, which is repeated
five times.
Summary
In this chapter, we described how to implement ray-traced reflections.
We started with an overview of screen-space reflection, a technique that
was used for many years before ray tracing hardware was available. We
explained how it works and some of its limitations.
Next, we described our ray tracing implementation to determine
reflection values. We provided two methods to determine the reflected
ray direction and explained how the reflected color is computed if a hit
is returned.
Since we only use one sample per fragment, the result of this step is
noisy. To reduce as much of this noise as possible, we implemented a
denoiser based on SVGF. This technique consists of three passes. First,
there’s a temporal accumulation step to compute color and luminance
moments. Then, we compute the luminance variance. Finally, we
process the color output by passing it through five iterations of a
wavelet filter.
This chapter also concludes our book! We hope you enjoyed reading it
as much as we had fun writing it. When it comes to modern graphics
techniques, there is only so much that can be covered in a single book.
We have included what we thought are some of the most interesting
features and techniques when it comes to implementing them in
Vulkan. Our goal is to provide you with a starting set of tools that you
can build and expand upon. We wish you a wonderful journey on the
path to mastering graphics programming!
We very much welcome your feedback and corrections, so please feel
free to reach out to us.
Further reading
We have only provided a brief introduction to screen-space reflections.
The following articles go into more detail about their implementation,
their limitations, and how to improve the final results:
• https://lettier.github.io/3d-game-shaders-for-beginners/screen-
space-reflection.html
• https://bartwronski.com/2014/01/25/the-future-of-screenspace-
reflections/
• https://bartwronski.com/2014/03/23/gdc-follow-up-screenspace-
reflections-filtering-and-up-sampling/
We have only used one of the many hashing techniques presented in the
paper Hash Functions for GPU Rendering: https://jcgt.org/
published/0009/03/02/.
This link contains more details about the sampling technique we used to
determine the reflection vector by sampling the BRDF – Sampling the
GGX Distribution of Visible Normals: https://jcgt.org/
published/0007/04/01/.
For more details about the SVGF algorithm we presented, we
recommend reading the original paper and supporting material: https://
research.nvidia.com/publication/2017-07_spatiotemporal-variance-
guided-filtering-real-time-reconstruction-path-traced.
We used importance sampling to determine which light to use at each
frame. Another technique that has become popular in the last few years
is Reservoir Spatio-Temporal Importance Resampling (ReSTIR). We
highly recommend reading the original paper and looking up the other
techniques that have been inspired by it: https://research.nvidia.com/
publication/2020-07_spatiotemporal-reservoir-resampling-real-time-
Ray-Tracing-dynamic-direct.
In this chapter, we implemented the SVGF algorithm from scratch for
pedagogical purposes. Our implementation is a good starting point to
build upon, but we also recommend looking at production denoisers
from AMD and Nvidia to compare results:
• https://gpuopen.com/fidelityfx-denoiser/
• https://developer.nvidia.com/rtx/Ray-Tracing/rt-denoisers