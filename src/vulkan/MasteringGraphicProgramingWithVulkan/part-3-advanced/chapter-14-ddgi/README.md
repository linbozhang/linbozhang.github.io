Adding Dynamic Diffuse Global
Illumination with Ray Tracing
So far in this book, illumination has been based on direct lighting
coming from point lights. In this chapter, we will enhance lighting by
adding indirect lighting, often referred to as global illumination in the
context of video games.
This type of illumination comes from emulating the behavior of light.
Without going into quantum physics and optics, the information we
need to consider is that light bounces off surfaces a few times until its
energy becomes zero.
Throughout movies and video games, global illumination has always
been an important aspect of lighting, but often impossible to perform in
real time.
With movies, it often took minutes (if not hours) to render a single
frame, until global illumination was pioneered. Video games were
inspired by this and now include it in their lighting.
In this chapter, we will discover how to implement real-time global
illumination by covering these topics:
• Introduction to indirect lighting
• Introduction to Dynamic Diffuse Global Illumination (DDGI)
• Implementing DDGI
Each topic will contain subsections so that you can expand upon the
knowledge provided.
The following figure shows how the code from this chapter helps
contribute to indirect lighting:
Figure 14.1 – Indirect lighting output
In Figure 14.1, the scene has a point light on the left. We can see the
green color from the light bouncing off the left curtain onto the floor
and the right pillars and curtains.
On the floor in the distance, we can see the color of the sky tinting the
walls. The occlusion given by its visibility provides a very low light
contribution to the arches.
Technical requirements
The code for this chapter can be found at the following URL: https://
github.com/PacktPublishing/Mastering-Graphics-Programming-with-
Vulkan/tree/main/source/chapter14.
Introduction to indirect lighting
Going back to direct and indirect lighting, direct lighting just shows the
first interaction between light and matter, but light continues to travel
in space, bouncing at times.
From a rendering perspective, we use the G-buffer information to
calculate the first light interaction with surfaces that are visible from
our point of view, but we have little data on what is outside of our
view.
The following diagram shows direct lighting:
Figure 14.2 – Direct lighting
Figure 14.2 describes the current lighting setup. There are light-emitting
rays, and those rays interact with surfaces. Light bounces off these
surfaces and is captured by the camera, becoming the pixel color. This
is an extremely simplified vision of the phenomena, but it contains all
the basics we need.
For indirect lighting, relying only on the camera’s point of view is
insufficient as we need to calculate how other lights and geometries can
contribute and still affect the visible part of the scene but are outside of
the view, as well as the visible surfaces.
For this matter, ray tracing is the best tool: it’s a way to query the
scene spacially as we can use it to calculate how different bounces of
light contribute to the final value of a given fragment.
Here is a diagram showing indirect lighting:
Figure 14.3 – Indirect lighting
Figure 14.3 shows indirect rays bouncing off surfaces until they hit the
camera again.
There are two rays highlighted in this figure:
• Indirect Ray 0, bouncing off a hidden surface onto the blue floor
and finally into the camera
• Indirect Ray 0, bouncing off another surface and bouncing off
the red wall, and finally into the camera
With indirect illumination, we want to capture the phenomena of rays
of light bouncing off surfaces, both hidden and not.
For example, in this setup, there are some rays between the red and
blue surfaces that will bounce within each other, tinting the closer parts
of the surfaces of the respective colors.
Adding indirect illumination to lighting enhances the realism and visual
quality of the image, but how can we achieve that?
In the next section, we will talk about the implementation that we
chose: Dynamic Diffuse Global Illumination, or DDGI, which was
developed mainly by researchers at Nvidia but is rapidly becoming one
of the most used solutions in AAA games.
Introduction to Dynamic Diffuse
Global Illumination (DDGI)
In this section, we will explain the algorithm behind DDGI. DDGI is
based on two main tools: light probes and irradiance volumes:
• Light probes are points in space, represented as spheres, that
encode light information
• Irradiance volumes are defined as spaces that contain three-
dimensional grids of light probes with fixed spacing between
them
Sampling is easier when the layout is regular, even though we will see
some improvements to placements later. Probes are encoded using
octahedral mapping, a convenient way to map a square to a sphere.
Links to the math behind octahedral mapping have been provided in the
Further reading section.
The core idea behind DDGI is to dynamically update probes using ray
tracing: for each probe, we will cast some rays and calculate the
radiance at the triangle intersection. Radiance is calculated with the
dynamic lights present in the engine, reacting in real time to any light
or geometry changes.
Given the low resolution of the grid compared to the pixels on the
screen, the only lighting phenomenon possible is diffuse lighting. The
following diagram provides an overview of the algorithm, showing the
relationships and the sequences between shaders (green rectangles) and
textures (yellow ellipses):
Figure 14.4 – Algorithm overview
Let’s provide a quick overview of the algorithm before looking at each
step in detail:
1. Perform ray tracing for each probe and calculate the radiance and
distance.
2. Update the irradiance of all probes with the radiance calculated
while applying some hysteresis.
3. Update the visibility data of all probes with the distance
calculated in the ray tracing pass, again with some hysteresis.
4. (Optional) Calculate the per-probe offset position using the ray
tracing distance.
5. Calculate indirect lighting by reading the updated irradiance,
visibility, and probe offsets.
In the following subsections, we will cover each step of the algorithm.
Ray tracing for each probe
This is the first step of the algorithm. For each ray of each probe that
needs an update, we must ray trace the scene using dynamic lighting.
In the ray tracing hit shader, we calculate the world position and
normal of the hit triangle and perform a simplified diffuse lighting
calculation. Optionally, but more expensive, we can read the other
irradiance probes to add an infinite number of bounces to the lighting
calculation, giving it an even more realistic look.
Especially important here is the texture layout: each row represents the
rays for a single probe. So, if we have 128 rays per probe, we will have
a row of 128 texels, while each column represents a probe.
Thus, a configuration with 128 rays and 24 probes will result in a
128x24 texture dimension. We store the lighting calculation as radiance
in the RGB channels of the texture, and the hit distance in the Alpha
channel.
Hit distance will be used to help with light leaks and calculating probe
offsets.
Probes offsetting
Probes offsetting is a step that’s done when an irradiance volume is
loaded into the world, or its properties are changed (such as spacing or
position). Using the hit distances from the ray tracing step, we can
calculate if a probe is placed straight into a surface and then create an
offset for it.
The offsetting amount cannot be bigger than half the distance to other
probes so that the grid still maintains some coherency between the grid
indices and their position. This step is only done a few times (normally,
around five is a suitable number) as having it run continuously will
indefinitely move the probes, thus causing light flickering.
Once the offsets have been calculated, every probe will have the final
world position, drastically increasing the visual quality of indirect
lighting.
Here, we can see the improvement after calculating these offsets:
Figure 14.5 – Global illumination with (left) and without (right) probe
offsets
As you can see, the probes that are inside a geometry not only give no
lighting contribution to the sampling but can create visual artifacts.
Thanks to probe offsetting, we can place probes in a better position.
Probes irradiance and visibility updates
We now have the result of each ray that’s been traced for each probe
with dynamic lighting applied. How can we encode this information? As
seen in the Introduction to Dynamic Diffuse Global Illumination (DDGI)
section, one of the ways is to use octahedral mapping, which unwraps a
sphere into a rectangle.
Given that we are storing each probe’s radiance as a 3D volume, we
need a texture that contains a rectangle for each probe. We will choose
to create a single texture with a row that contains a layer of probes as
MxN, while the height contains the other layers.
For example, if we have a grid of 3x2x4 probes, each row will contain 6
probes (3x2) and the final texture will have 4 rows. We will execute this
step two times, one to update the irradiance from the radiance, and the
other to update the visibility from the distance of each probe.
Visibility is crucial for minimizing light leaks, and irradiance and
visibility are stored in different textures and can have different sizes.
One thing to be aware of is that to add support for bilinear filtering, we
need to store an additional 1-pixel border around each rectangle; this
will be updated here as well.
The shader will read the new radiance and distances calculated and the
previous frame’s irradiance and visibility textures to blend the values to
avoid flickering, as Volumetric Fog does with temporal reprojection,
using a simple hysteresis.
Hysteresis can be changed dynamically if the lighting conditions change
drastically to counteract slow updates using hysteresis. The results will
normally be slower to react to light movements, but it is a drawback
needed to avoid flickering.
The last part of the shader involves updating the borders for bilinear
filtering. Bilinear filtering requires samples to be read in a specific
order, as highlighted in the following diagram:
Figure 14.6 – Bilinear filtering samples. The outer grid copies pixels
from the written pixel positions inside each rectangle
Figure 14.6 shows the coordinate calculations for copying pixels: the
center area is the one that did the full irradiance/visibility update,
while the borders copy the values from the pixels at the specified
coordinates.
We will run two different shaders – one to update probe irradiance and
one to update probe visibility.
In the shader code, we will see the actual code to do this. We are now
ready to sample the irradiance of the probes, as seen in the next
subsection.
Probes sampling
This step involves reading the irradiance probes and calculating the
indirect lighting contribution. We will render from the main camera’s
point of view, and we will sample the eight closest probes given a world
position and direction. The visibility texture is used to minimize leakage
and soften the lighting results.
Given the soft lighting nature of diffuse indirect components and to
obtain better performance, we have opted to sample this at a quarter
resolution, so we need to take extra care of where we sample to avoid
pixel inaccuracies.
While looking at probe ray tracing, irradiance updates, visibility
updates, probe offsetting, and probe sampling, we described all the
basic steps necessary to have a working DDGI implementation.
Other steps can be included to make the rendering even faster, such as
using the distances to calculate inactive probes. Other extensions can
also be included, such as those that contain a cascade of volumes and
hand-placed volumes that give DDGI the best flexibility needed to be
used in video games, where different hardware configurations can
dictate algorithmic choices.
In the next section, we will learn how to implement DDGI.
Implementing DDGI
The first shaders we will read are the ray tracing shaders. These, as we
saw in Chapter 12, Getting Started with Ray Tracing, come as a bundle
that includes the ray-generation, ray-hit, and ray-miss shaders.
There are a set of different methods that convert from world space into
grid indices and vice versa that will be used here; they are included
with the code.
First, we want to define the ray payload – that is, the information that’s
cached after the ray tracing query is performed:
struct RayPayload {
vec3 radiance;
float distance;
};
Ray-generation shader
The first shader is called ray-generation. It spawns rays from the probe’s
position using random directions on a sphere using spherical Fibonacci
sequences.
Like dithering for TAA and Volumetric Fog, using random directions
and temporal accumulation (which happens in the Probe Update
shader) allows us to have more information about the scene, thus
enhancing the visuals:
layout( location = 0 ) rayPayloadEXT RayPayload payload;
void main() {
const ivec2 pixel_coord = ivec2(gl_LaunchIDEXT.xy);
const int probe_index = pixel_coord.y;
const int ray_index = pixel_coord.x;
// Convert from linear probe index to grid probe
indices and then position:
ivec3 probe_grid_indices = probe_index_to_grid_indices(
probe_index );
vec3 ray_origin = grid_indices_to_world(
probe_grid_indices probe_index );
vec3 direction = normalize( mat3(random_rotation) *
spherical_fibonacci(ray_index, probe_rays) );
payload.radiance = vec3(0);
payload.distance = 0;
traceRayEXT(as, gl_RayFlagsOpaqueEXT, 0xff, 0, 0, 0,
ray_origin, 0.0, direction, 100.0, 0);
// Store the result coming from Hit or Miss shaders
 imageStore(global_images_2d[ radiance_output_index ],
pixel_coord, vec4(payload.radiance, payload.distance));
}
Ray-hit shader
This is where all the heavy lifting happens.
First, we must declare the payload and the barycentric coordinates to
calculate the correct triangle data:
layout( location = 0 ) rayPayloadInEXT RayPayload payload;
hitAttributeEXT vec2 barycentric_weights;
Then, check for back-facing triangles, storing only the distance as
lighting is not needed:
void main() {
vec3 radiance = vec3(0);
float distance = 0.0f;
if (gl_HitKindEXT == gl_HitKindBackFacingTriangleEXT) {
// Track backfacing rays with negative distance
distance = gl_RayTminEXT + gl_HitTEXT;
distance *= -0.2;
}
Otherwise, calculate the triangle data and perform lighting:
else {
Next, read the mesh instance data and read the index buffer:
uint mesh_index = mesh_instance_draws[
gl_GeometryIndexEXT ].mesh_draw_index;
MeshDraw mesh = mesh_draws[ mesh_index ];
 int_array_type index_buffer = int_array_type(
mesh.index_buffer );
int i0 = index_buffer[ gl_PrimitiveID * 3 ].v;
int i1 = index_buffer[ gl_PrimitiveID * 3 + 1 ].v;
int i2 = index_buffer[ gl_PrimitiveID * 3 + 2 ].v;
Now, we can read the vertices from the mesh buffer and calculate the
world space position:
float_array_type vertex_buffer = float_array_type(
mesh.position_buffer );
vec4 p0 = vec4(vertex_buffer[ i0 * 3 + 0 ].v,
vertex_buffer[ i0 * 3 + 1 ].v,
vertex_buffer[ i0 * 3 + 2 ].v, 1.0 );
// Calculate p1 and p2 using i1 and i2 in the same
way.
Calculate the world position:
const mat4 transform = mesh_instance_draws[
gl_GeometryIndexEXT ].model;
vec4 p0_world = transform * p0;
// calculate as well p1_world and p2_world
As we did for the vertex positions, read the UV buffer and calculate the
final UVs of the triangle:
float_array_type uv_buffer = float_array_type(
mesh.uv_buffer );
vec2 uv0 = vec2(uv_buffer[ i0 * 2 ].v, uv_buffer[
i0 * 2 + 1].v);
// Read uv1 and uv2 using i1 and i2
float b = barycentric_weights.x;
float c = barycentric_weights.y;
float a = 1 - b - c;
vec2 uv = ( a * uv0 + b * uv1 + c * uv2 );
Read the diffuse texture. We can also read a lower MIP to improve
performance:
vec3 diffuse = texture( global_textures[
nonuniformEXT( mesh.textures.x ) ], uv ).rgb;
Read the triangle normals and calculate the final normal. You don’t
need to read the normal texture as the cached result is so small that
those details are lost:
float_array_type normals_buffer =
float_array_type( mesh.normals_buffer );
vec3 n0 = vec3(normals_buffer[ i0 * 3 + 0 ].v,
normals_buffer[ i0 * 3 + 1 ].v,
normals_buffer[ i0 * 3 + 2 ].v );
// Similar calculations for n1 and n2 using i1 and
i2
vec3 normal = a * n0 + b * n1 + c * n2;
const mat3 normal_transform = mat3(mesh_instance_draws
[gl_GeometryIndexEXT ].model_inverse);
normal = normal_transform * normal;
We can calculate the world position and the normal, and then calculate
the direct lighting:
const vec3 world_position = a * p0_world.xyz + b *
p1_world.xyz + c * p2_world.xyz;
vec3 diffuse = albedo * direct_lighting(world_position,
normal);
// Optional: infinite bounces by samplying previous
frame Irradiance:
diffuse += albedo * sample_irradiance( world_position,
normal, camera_position.xyz ) *
infinite_bounces_multiplier;
Finally, we can cache the radiance and the distance:
 radiance = diffuse;
distance = gl_RayTminEXT + gl_HitTEXT;
}
Now, let’s write the results to the payload:
payload.radiance = radiance;
payload.distance = distance;
}
Ray-miss shader
In this shader, we simply return the sky color. Alternatively, if present,
an environment cube map can be added:
layout( location = 0 ) rayPayloadInEXT RayPayload payload;
void main() {
payload.radiance = vec3( 0.529, 0.807, 0.921 );
payload.distance = 1000.0f;
}
Updating probes irradiance and visibility
shaders
This compute shader will read the previous frame’s irradiance/visibility
and the current frame’s radiance/distance and update the octahedral
representation of each probe. This shader will be executed twice – once
to update the irradiance and once to update the visibility. It will also
update the borders to add support for bilinear filtering.
First, we must check if the current pixel is a border. If so, we must
change modes:
layout (local_size_x = 8, local_size_y = 8, local_size_z =
1) in;
void main() {
 ivec3 coords = ivec3(gl_GlobalInvocationID.xyz);
const uint probe_with_border_side = probe_side_length +
2;
const uint probe_last_pixel = probe_side_length + 1;
int probe_index = get_probe_index_from_pixels
(coords.xy, int(probe_with_border_side),
probe_texture_width);
// Check if thread is a border pixel
bool border_pixel = ((gl_GlobalInvocationID.x %
probe_with_border_side) == 0) ||
((gl_GlobalInvocationID.x % probe_with_border_side )
== probe_last_pixel );
border_pixel = border_pixel ||
((gl_GlobalInvocationID.y % probe_with_border_side)
== 0) || ((gl_GlobalInvocationID.y %
probe_with_border_side ) == probe_last_pixel );
For non-border pixels, calculate a weight based on ray direction and the
direction of the sphere encoded with octahedral coordinates, and
calculate the irradiance as the summed weight of the radiances:
if ( !border_pixel ) {
vec4 result = vec4(0);
uint backfaces = 0;
uint max_backfaces = uint(probe_rays * 0.1f);
Add the contribution from each ray:
for ( int ray_index = 0; ray_index < probe_rays;
++ray_index ) {
ivec2 sample_position = ivec2( ray_index,
probe_index );
vec3 ray_direction = normalize(
mat3(random_rotation) *
spherical_fibonacci(ray_index, probe_rays) );
vec3 texel_direction = oct_decode
(normalized_oct_coord(coords.xy));
float weight = max(0.0, dot(texel_direction,
 ray_direction));
Read the distance for this ray and early out if there are too many back
faces:
float distance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
sample_position,
0).w;
if ( distance < 0.0f &&
use_backfacing_blending() ) {
++backfaces;
// Early out: only blend ray radiance into
the probe if the backface threshold
hasn't been exceeded
if (backfaces >= max_backfaces) {
return;
}
continue;
}
At this point, depending on if we are updating the irradiance or the
visibility, we perform different calculations.
For irradiance, we must do the following:
if (weight >= EPSILON) {
vec3 radiance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
sample_position, 0).rgb;
radiance.rgb *= energy_conservation;
// Storing the sum of the weights in alpha
temporarily
result += vec4(radiance * weight, weight);
}
For visibility, we must read and limit the distance:
 float probe_max_ray_distance = 1.0f * 1.5f;
if (weight >= EPSILON) {
float distance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
sample_position, 0).w;
// Limit distance
distance = min(abs(distance),
probe_max_ray_distance);
vec3 value = vec3(distance, distance *
distance, 0);
// Storing the sum of the weights in alpha
temporarily
result += vec4(value * weight, weight);
}
}
Finally, apply the weight:
if (result.w > EPSILON) {
result.xyz /= result.w;
result.w = 1.0f;
}
Now, we can read the previous frame’s irradiance or visibility and blend
it using hysteresis.
For irradiance, we must do the following:
vec4 previous_value = imageLoad( irradiance_image,
coords.xy );
result = mix( result, previous_value, hysteresis );
imageStore(irradiance_image, coords.xy, result);
For visibility, we must do the following:
vec2 previous_value = imageLoad( visibility_image,
coords.xy ).rg;
 result.rg = mix( result.rg, previous_value,
hysteresis );
imageStore(visibility_image, coords.xy,
vec4(result.rg, 0, 1));
At this point, we end the shader for non-border pixels. We will wait for
the local group to finish and copy the pixels to the borders:
// NOTE: returning here.
return;
}
Next, we must operate on the border pixels.
Given that we are working on a local thread group that’s as big as each
square, when a group is finished, we can copy the border pixels with
the currently updated data. This is an optimization process that helps us
avoid dispatching two other shaders and adding barriers to wait for the
updates to be done.
After implementing the preceding code, we must wait for the group to
finish:
groupMemoryBarrier();
barrier();
Once those barriers are in the shader code, all the groups will be
completed.
We have the final irradiance/visibility stored in the texture, so we can
copy the border pixels to add bilinear sampling support. As shown in
Figure 14.6, we need to read the pixels in a specific order to ensure
bilinear filtering is working properly.
First, we must calculate the source pixel coordinates:
const uint probe_pixel_x = gl_GlobalInvocationID.x %
probe_with_border_side;
 const uint probe_pixel_y = gl_GlobalInvocationID.y %
probe_with_border_side;
bool corner_pixel = (probe_pixel_x == 0 ||
probe_pixel_x == probe_last_pixel) && (probe_pixel_y
== 0 || probe_pixel_y == probe_last_pixel);
bool row_pixel = (probe_pixel_x > 0 && probe_pixel_x <
probe_last_pixel);
ivec2 source_pixel_coordinate = coords.xy;
if ( corner_pixel ) {
source_pixel_coordinate.x += probe_pixel_x == 0 ?
probe_side_length : -probe_side_length;
source_pixel_coordinate.y += probe_pixel_y == 0 ?
probe_side_length : -probe_side_length;
}
else if ( row_pixel ) {
source_pixel_coordinate.x +=
k_read_table[probe_pixel_x - 1];
source_pixel_coordinate.y += (probe_pixel_y > 0) ?
-1 : 1;
}
else {
source_pixel_coordinate.x += (probe_pixel_x > 0) ?
-1 : 1;
source_pixel_coordinate.y +=
k_read_table[probe_pixel_y - 1];
}
Next, we must copy the source pixels to the current border.
For irradiance, we must do the following:
vec4 copied_data = imageLoad( irradiance_image,
source_pixel_coordinate );
imageStore( irradiance_image, coords.xy, copied_data );
For visibility, we must do the following:
 vec4 copied_data = imageLoad( visibility_image,
source_pixel_coordinate );
imageStore( visibility_image, coords.xy, copied_data );
}
We now have the updated irradiance and visibility ready to be sampled
by the scene.
Indirect lighting sampling
This compute shader is responsible for reading the indirect irradiance so
that it’s ready to be used by the illumination. It uses a utility method
called sample_irradiance, which is also used inside the ray-hit shader
to simulate an infinite bounce.
First, though, let’s look at the compute shader. When using the quarter
resolution, cycle through a neighborhood of 2x2 pixels and get the
closest depth, and save the pixel index:
layout (local_size_x = 8, local_size_y = 8, local_size_z =
1) in;
void main() {
ivec3 coords = ivec3(gl_GlobalInvocationID.xyz);
int resolution_divider = output_resolution_half == 1 ?
2 : 1;
vec2 screen_uv = uv_nearest(coords.xy, resolution /
resolution_divider);
float raw_depth = 1.0f;
int chosen_hiresolution_sample_index = 0;
if (output_resolution_half == 1) {
float closer_depth = 0.f;
for ( int i = 0; i < 4; ++i ) {
float depth = texelFetch(global_textures
[nonuniformEXT(depth_fullscreen_texture_index)
], (coords.xy) * 2 + pixel_offsets[i], 0).r;
if ( closer_depth < depth ) {
closer_depth = depth;
chosen_hiresolution_sample_index = i;
 }
}
raw_depth = closer_depth;
}
With the cached index of the closest depth, read the normal as well:
vec3 normal = vec3(0);
if (output_resolution_half == 1) {
vec2 encoded_normal = texelFetch(global_textures
[nonuniformEXT(normal_texture_index)],
(coords.xy) * 2 + pixel_offsets
[chosen_hiresolution_sample_index], 0).rg;
normal = normalize(octahedral_decode(encoded_normal)
);
}
Now that we have calculated the depth and the normal, we can gather
the world position and use the normal to sample the irradiance:
const vec3 pixel_world_position =
world_position_from_depth(screen_uv, raw_depth,
inverse_view_projection)
vec3 irradiance = sample_irradiance(
pixel_world_position, normal, camera_position.xyz );
imageStore(global_images_2d[ indirect_output_index ],
coords.xy, vec4(irradiance,1));
}
The second part of this shader is about the sample_irradiance function,
which does the actual heavy lifting.
It starts by calculating a bias vector to move the sampling so that it’s a
little bit in front of the geometry, to help with leaks:
vec3 sample_irradiance( vec3 world_position, vec3 normal,
vec3 camera_position ) {
 const vec3 V = normalize(camera_position.xyz –
world_position);
// Bias vector to offset probe sampling based on normal
and view vector.
const float minimum_distance_between_probes = 1.0f;
vec3 bias_vector = (normal * 0.2f + V * 0.8f) *
(0.75f minimum_distance_between_probes) *
self_shadow_bias;
vec3 biased_world_position = world_position +
bias_vector;
// Sample at world position + probe offset reduces
shadow leaking.
ivec3 base_grid_indices =
world_to_grid_indices(biased_world_position);
vec3 base_probe_world_position =
grid_indices_to_world_no_offsets( base_grid_indices
);
We now have the grid world position and indices at the sampling world
position (plus the bias).
Now, we must calculate a per-axis value of where the sampling position
is within the cell:
// alpha is how far from the floor(currentVertex)
position. on [0, 1] for each axis.
vec3 alpha = clamp((biased_world_position –
base_probe_world_position) , vec3(0.0f), vec3(1.0f));
At this point, we can sample the eight adjacent probes to the sampling
point:
vec3 sum_irradiance = vec3(0.0f);
float sum_weight = 0.0f;
For each probe, we must calculate its world space position from the
indices:
 // Iterate over adjacent probe cage
for (int i = 0; i < 8; ++i) {
// Compute the offset grid coord and clamp to the
probe grid boundary
// Offset = 0 or 1 along each axis
ivec3 offset = ivec3(i, i >> 1, i >> 2) &
ivec3(1);
ivec3 probe_grid_coord = clamp(base_grid_indices +
offset, ivec3(0), probe_counts - ivec3(1));
int probe_index =
probe_indices_to_index(probe_grid_coord);
vec3 probe_pos =
grid_indices_to_world(probe_grid_coord,
probe_index);
Compute the trilinear weights based on the grid cell vertex to smoothly
transition between probes:
vec3 trilinear = mix(1.0 - alpha, alpha, offset);
float weight = 1.0;
Now, we can see how the visibility texture is used. It stores depth and
depth squared values, and helps tremendously with light leaking.
This test is based on variance, such as Variance Shadow Map:
vec3 probe_to_biased_point_direction =
biased_world_position - probe_pos;
float distance_to_biased_point =
length(probe_to_biased_point_direction);
probe_to_biased_point_direction *= 1.0 /
distance_to_biased_point;
{
vec2 uv = get_probe_uv
(probe_to_biased_point_direction,
probe_index, probe_texture_width,
probe_texture_height,
 probe_side_length );
vec2 visibility = textureLod(global_textures
[nonuniformEXT(grid_visibility_texture_index)],
uv, 0).rg;
float mean_distance_to_occluder = visibility.x;
float chebyshev_weight = 1.0;
Check if the sampled probe is in “shadow” and calculate the Chebyshev
weight:
if (distance_to_biased_point >
mean_distance_to_occluder) {
float variance = abs((visibility.x *
visibility.x) - visibility.y);
const float distance_diff =
distance_to_biased_point –
mean_distance_to_occluder;
chebyshev_weight = variance / (variance +
(distance_diff * distance_diff));
// Increase contrast in the weight
chebyshev_weight = max((chebyshev_weight *
chebyshev_weight * chebyshev_weight),
0.0f);
}
// Avoid visibility weights ever going all of
the way to zero
chebyshev_weight = max(0.05f, chebyshev_weight);
weight *= chebyshev_weight;
}
With the weight calculated for this probe, we can apply the trilinear
offset, read the irradiance, and calculate its contribution:
vec2 uv = get_probe_uv(normal, probe_index,
probe_texture_width, probe_texture_height,
probe_side_length );
vec3 probe_irradiance =
 textureLod(global_textures
[nonuniformEXT(grid_irradiance_output_index)],
uv, 0).rgb;
// Trilinear weights
weight *= trilinear.x * trilinear.y * trilinear.z +
0.001f;
sum_irradiance += weight * probe_irradiance;
sum_weight += weight;
}
With all the probes sampled, the final irradiance is scaled accordingly
and returned:
vec3 irradiance = 0.5f * PI * sum_irradiance /
sum_weight;
return irradiance;
}
With that, we’ve finished looking at the irradiance sampling compute
shader and utility functions.
More filters can be applied to the sampling to further smooth the image,
but this is the most basic version that’s enhanced by the visibility data.
Now, let’s learn how the calculate_lighting method can be modified to
add diffuse indirect.
Modifications to the calculate_lighting
method
In our lighting.h shader file, add the following lines once the direct
lighting computations have been done:
vec3 F = fresnel_schlick_roughness(max(dot(normal, V),
0.0), F0, roughness);
vec3 kS = F;
vec3 kD = 1.0 - kS;
kD *= 1.0 - metallic;
 vec3 indirect_irradiance = textureLod(global_textures
[nonuniformEXT(indirect_lighting_texture_index)],
screen_uv, 0).rgb;
vec3 indirect_diffuse = indirect_irradiance *
base_colour.rgb;
const float ao = 1.0f;
final_color.rgb += (kD * indirect_diffuse) * ao;
Here, base_colour is the albedo coming from the G-buffer and
final_color is the pixel color with all the direct lighting contributions
calculated.
The basic algorithm is complete, but there is one last shader to have a
look at: the Probe Offset shader. It calculates a per-probe world-space
offset to avoid intersecting probes with geometries.
Probe offsets shader
This compute shader cleverly uses the per-ray distances coming from
the ray tracing pass to calculate the offset based on backface and
frontface counts.
First, we must check for an invalid probe index to avoid writing to the
wrong memory:
layout (local_size_x = 32, local_size_y = 1, local_size_z =
1) in;
void main() {
ivec3 coords = ivec3(gl_GlobalInvocationID.xyz);
// Invoke this shader for each probe
int probe_index = coords.x;
const int total_probes = probe_counts.x *
probe_counts.y * probe_counts.z;
// Early out if index is not valid
if (probe_index >= total_probes) {
return;
}
Now, we must search for front and backface hits based on the ray
tracing distance that’s been calculated.
First, declare all the necessary variables:
int closest_backface_index = -1;
float closest_backface_distance = 100000000.f;
int closest_frontface_index = -1;
float closest_frontface_distance = 100000000.f;
int farthest_frontface_index = -1;
float farthest_frontface_distance = 0;
int backfaces_count = 0;
For each ray of this probe, read the distance and calculate if it is a front
or backface. We store negative distances for backfaces in the hit shader:
// For each ray cache front/backfaces index and
distances.
for (int ray_index = 0; ray_index < probe_rays;
++ray_index) {
ivec2 ray_tex_coord = ivec2(ray_index,
probe_index);
float ray_distance = texelFetch(global_textures
[nonuniformEXT(radiance_output_index)],
ray_tex_coord, 0).w;
// Negative distance is stored for backface hits in
the Ray Tracing Hit shader.
if ( ray_distance <= 0.0f ) {
++backfaces_count;
// Distance is a positive value, thus negate
ray_distance as it is negative already if
// we are inside this branch.
if ( (-ray_distance) <
closest_backface_distance ) {
closest_backface_distance = ray_distance;
closest_backface_index = ray_index;
}
}
else {
 // Cache either closest or farther distance and
indices for this ray.
if (ray_distance < closest_frontface_distance)
{
closest_frontface_distance = ray_distance;
closest_frontface_index = ray_index;
} else if (ray_distance >
farthest_frontface_distance) {
farthest_frontface_distance = ray_distance;
farthest_frontface_index = ray_index;
}
}
}
We know the front and backface indices and distances for this probe.
Given that we incrementally move the probe, read the previous frame’s
offset:
vec4 current_offset = vec4(0);
// Read previous offset after the first frame.
if ( first_frame == 0 ) {
const int probe_counts_xy = probe_counts.x *
probe_counts.y;
ivec2 probe_offset_sampling_coordinates =
ivec2(probe_index % probe_counts_xy, probe_index
/ probe_counts_xy);
current_offset.rgb = texelFetch(global_textures
[nonuniformEXT(probe_offset_texture_index)],
probe_offset_sampling_coordinates, 0).rgb;
}
Now, we must check if the probe can be considered inside a geometry
and calculate an offset moving away from that direction, but within the
probe spacing limit, that we can call a cell:
vec3 full_offset = vec3(10000.f);
vec3 cell_offset_limit = max_probe_offset *
probe_spacing;
 // Check if a fourth of the rays was a backface, we can
assume the probe is inside a geometry.
const bool inside_geometry = (float(backfaces_count) /
probe_rays) > 0.25f;
if (inside_geometry && (closest_backface_index != -1))
{
// Calculate the backface direction.
const vec3 closest_backface_direction =
closest_backface_distance * normalize(
mat3(random_rotation) *
spherical_fibonacci(closest_backface_index,
probe_rays) );
Find the maximum offset inside the cell to move the probe:
const vec3 positive_offset = (current_offset.xyz +
cell_offset_limit) / closest_backface_direction;
const vec3 negative_offset = (current_offset.xyz –
cell_offset_limit) / closest_backface_direction;
const vec3 maximum_offset = vec3(max
(positive_offset.x, negative_offset.x),
max(positive_offset.y, negative_offset.y),
max(positive_offset.z, negative_offset.z));
// Get the smallest of the offsets to scale the
direction
const float direction_scale_factor = min(min
(maximum_offset.x, maximum_offset.y),
maximum_offset.z) - 0.001f;
// Move the offset in the opposite direction of the
backface one.
full_offset = current_offset.xyz –
closest_backface_direction *
direction_scale_factor;
}
If we have not hit a backface, we must move the probe slightly to put it
in a resting position:
 else if (closest_frontface_distance < 0.05f) {
// In this case we have a very small hit distance.
// Ensure that we never move through the farthest
frontface
// Move minimum distance to ensure not moving on a
future iteration.
const vec3 farthest_direction = min(0.2f,
farthest_frontface_distance) * normalize(
mat3(random_rotation) *
spherical_fibonacci(farthest_frontface_index,
probe_rays) );
const vec3 closest_direction = normalize(mat3
(random_rotation) * spherical_fibonacci
(closest_frontface_index, probe_rays));
// The farthest frontface may also be the closest
if the probe can only
// see one surface. If this is the case, don't move
the probe.
if (dot(farthest_direction, closest_direction) <
0.5f) {
full_offset = current_offset.xyz +
farthest_direction;
}
}
Update the offset only if it is within the spacing or inside the cell limits.
Then, store the value in the appropriate texture:
if (all(lessThan(abs(full_offset), cell_offset_limit)))
{
current_offset.xyz = full_offset;
}
const int probe_counts_xy = probe_counts.x *
probe_counts.y;
const int probe_texel_x = (probe_index %
probe_counts_xy);
const int probe_texel_y = probe_index /
probe_counts_xy;
imageStore(global_images_2d[ probe_offset_texture_index
 ], ivec2(probe_texel_x, probe_texel_y),
current_offset);
}
With that, we have calculated the probe offsets.
Again, this shader demonstrates how to cleverly use information you
already have – in this case, the per-ray probe distances – to move
probes outside of intersecting geometries.
We presented a fully funcitonal version of DDGI, but there are some
improvements that can be made and the technique can be expanded in
different directions. Some examples of improvements are a classification
system to disable non contributing probes, or adding a moving grid with
cascades of different grid spacing centered around the camera.
Combined with hand-placed volumes can create a complete diffuse
global-illumination system.
While having a GPU with ray-tracing capabilities is necessary for this
technique, we could bake irradiance and visibility for static scene parts
and use them on older GPUs. Another improvement can be changing
hysteresis based on probe luminance changes, or adding a staggered
probe update based on distance and importance.
All these ideas show how powerful and configurable DDGI is and we
encourage the reader to experiment and create other improvements.
Summary
In this chapter, we introduced the DDGI technique. We started by
talking about global illumination, the lighting phenomena that is
implemented by DDGI. Then, we provided an overview of the
algorithm, explaining each step in more detail.
Finally, we wrote and commented on all the shaders in the
implementation. DDGI already enhances the lighting of the rendered
frame, but it can be improved and optimized.
One of the aspects of DDGI that makes it useful is its configurability:
you can change the resolution of irradiance and visibility textures and
change the number of rays, number of probes, and spacing of probes to
support lower-end ray tracing-enabled GPUs.
In the next chapter we are going to add another element that will help
us increase the accuracy of our lighting solution: reflections!
Further reading
Global illumination is an incredibly big topic that’s covered extensively
in all rendering literature, but we wanted to highlight links that are
more connected to the implementation of DDGI.
DDGI itself is an idea that mostly came from a team at Nvidia in 2017,
with the central ideas described at https://morgan3d.github.io/
articles/2019-04-01-ddgi/index.html.
The original articles on DDGI and its evolution are as follows. They also
contain supplemental code that was incredibly helpful in implementing
the technique:
• https://casual-effects.com/research/McGuire2017LightField/
index.html
• https://www.jcgt.org/published/0008/02/01/
• https://jcgt.org/published/0010/02/01/
The following is a great overview of DDGI with Spherical Harmonics
support, and the only diagram to copy the border pixels for bilinear
interpolation. It also describes other interesting topics: https://
handmade.network/p/75/monter/blog/p/7288-
engine_work__global_illumination_with_irradiance_probes.
The DDGI presentation by Nvidia can be found at https://
developer.download.nvidia.com/video/gputechconf/gtc/2019/
presentation/s9900-irradiance-fields-rtx-diffuse-global-illumination-for-
local-and-cloud-graphics.pdf.
The following is an intuitive introduction to global illumination:
https://www.scratchapixel.com/lessons/3d-basic-rendering/global-
illumination-path-tracing.
Global Illumination Compendium: https://people.cs.kuleuven.be/
~philip.dutre/GI/.
Finally, here is the greatest website for real-time rendering: https://
www.realtimerendering.com/.