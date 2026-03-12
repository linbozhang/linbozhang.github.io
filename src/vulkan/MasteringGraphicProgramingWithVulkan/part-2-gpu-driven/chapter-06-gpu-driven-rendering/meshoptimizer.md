# Meshoptimizer 库说明

**[meshoptimizer](https://github.com/zeux/meshoptimizer)** 是 Arseny Kapoulkine 开源的网格优化库，用于让网格**更小、更快地被 GPU 渲染**。库提供 C/C++ 接口，可从 C/C++ 或通过 FFI（如 P/Invoke）在其他语言中使用；Rust 可使用 [meshopt](https://crates.io/crates/meshopt) crate，部分算法有 [meshoptimizer.js](https://github.com/zeux/meshoptimizer.js) 的 JavaScript 接口。同仓库还提供 **gltfpack**（命令行优化 glTF）和 **clusterlod.h**（基于聚类简化的连续 LOD 单头库）。

与本章（第 6 章 GPU 驱动渲染）直接相关的是：**将网格拆成 meshlet**、**计算每个 meshlet 的包围与锥体**，以及可选的 **meshlet 内顶点/三角形顺序优化** 与 **meshlet 压缩**。下面先概括库的整体管线，再重点说明**簇化（Clusterization）/ Mesh Shading** 以及**在 meshlet 管线中的使用方式**。

---

## 库的目的

GPU 渲染三角网格时，管线各阶段都要处理顶点与索引数据；这些阶段的效率取决于你喂给它们的数据。meshoptimizer 提供：

- **针对管线阶段的优化**：顶点缓存、overdraw、顶点拉取、顶点量化等，使渲染更高效；
- **降低网格复杂度与存储**：索引化、简化（LOD）、压缩等。

库的算法假定网格具有**顶点缓冲**和**索引缓冲**；多数算法会**原地**或生成新缓冲，不改变几何外观（除量化和简化外）。

---

## 核心优化管线（顺序重要）

对**传统渲染**（非 meshlet），若希望最大化渲染效率，通常按以下顺序处理网格：

1. **索引化（Indexing）**  
   从无索引顶点或冗余索引生成/重排索引，使顶点无重复。  
   - `meshopt_generateVertexRemap`：根据顶点数据二元相等生成 remap 表；  
   - `meshopt_remapIndexBuffer` / `meshopt_remapVertexBuffer`：生成新索引与顶点缓冲。  
   若存在浮点误差导致本应相同的顶点被拆开，可先对法线/切线等做量化，或用 `meshopt_generateVertexRemapCustom` 自定义比较函数。

2. **顶点缓存优化（Vertex cache optimization）**  
   重排三角形顺序，提高顶点复用、适配 GPU 的顶点缓存/线程批处理。  
   - `meshopt_optimizeVertexCache(indices, indices, index_count, vertex_count)`  
   库使用自适应算法，在不同 GPU 上都能获得较好的局部性；也可用 `meshopt_optimizeVertexCacheFifo` 针对固定大小 FIFO 缓存（如 16）优化，速度更快但效果略差。

3. **（可选）Overdraw 优化**  
   重排三角形以降低从多方向看的 overdraw。  
   - `meshopt_optimizeOverdraw(indices, ..., threshold)`  
   需传入顶点位置（float3）；threshold 控制可接受的顶点缓存命中率损失（如 1.05 表示最多 5%）。在 tiled deferred（如部分移动端）上可能收益有限，需实测。

4. **顶点拉取优化（Vertex fetch optimization）**  
   在**最终三角形顺序**确定后，重排顶点缓冲以提高访存局部性，并重写索引以匹配。  
   - `meshopt_optimizeVertexFetch(vertices, indices, index_count, vertices, vertex_count, sizeof(Vertex))`  
   若顶点数据是多流（deinterleaved），用 `meshopt_optimizeVertexFetchRemap` 再对每流做 `meshopt_remapVertexBuffer`。

5. **顶点量化（Vertex quantization）**  
   将位置、法线、UV 等量化到更小类型（如 half、16 位归一化整数），减少带宽与存储。  
   库提供 `meshopt_quantizeSnorm`、`meshopt_quantizeHalf`、`meshopt_quantizeUnorm` 等；法线常用 8/10 位或八面体编码，位置常用相对 AABB 的 16 位或 half。

6. **（可选）Shadow 索引**  
   若管线有仅深度 pass（阴影、depth pre-pass），可用 `meshopt_generateShadowIndexBuffer` 生成仅含位置相关的第二套索引，减少深度 pass 的顶点数；再对 shadow 索引做一次顶点缓存优化。

**注意**：meshlet 构建通常基于**已经做过顶点缓存与顶点拉取优化**的索引/顶点数据，这样得到的 meshlet 内部局部性更好，便于后续压缩与 GPU 访问。

---

## 簇化与 Mesh Shading（与本章直接相关）

现代 GPU（Nvidia Turing 起、AMD RDNA2 起）提供 **mesh shader** 管线：不再以索引缓冲 + 顶点 shader 为核心，而是以** meshlet 为单元**向光栅器提交一批顶点与三角形。meshoptimizer 提供将网格**拆成 meshlet** 的算法，并可为每个 meshlet 计算**包围球与锥体**，用于视锥、背面和遮挡剔除。

### 构建 Meshlet 数据：`meshopt_buildMeshlets`

- **函数**：  
  `meshopt_buildMeshlets(meshlets, meshlet_vertices, meshlet_triangles, indices, index_count, vertex_positions, vertex_count, vertex_size, max_vertices, max_triangles, cone_weight)`

- **含义**：  
  将网格的索引缓冲拆成多个 **meshlet**。每个 meshlet 包含：  
  - 一组**顶点索引**（指向原始顶点缓冲），存放在 `meshlet_vertices` 中；  
  - 一组**微索引**（每个三角形 3 个字节），存放在 `meshlet_triangles` 中。  
  库在**拓扑效率**（meshlet 内顶点复用）与**剔除效率**（meshlet 半径与三角形朝向集中）之间做平衡。

- **参数要点**：  
  - `max_vertices`、`max_triangles`：每个 meshlet 的上限。**Nvidia** 推荐 64 顶点、126 三角形（Vulkan mesh shader 限制）；**AMD** 早期 GPU 常用 64/64 或 128/128。  
  - `cone_weight`：锥体剔除权重。0 表示不优化锥体；0.25 等可在锥体剔除与视锥/遮挡之间折中。  
  - 输出：`meshopt_Meshlet` 数组，每个元素有 `vertex_offset`、`triangle_offset`、`vertex_count`、`triangle_count`，均针对 `meshlet_vertices` / `meshlet_triangles` 的偏移与长度。

- **事前分配**：  
  先用 `meshopt_buildMeshletsBound(index_count, max_vertices, max_triangles)` 得到 meshlet 数量上界，再分配 `meshlets`、`meshlet_vertices`、`meshlet_triangles`。构建后可根据最后一个 meshlet 的 offset+count 对数组做 resize，再写入资源或上传 GPU。

- **可选：meshlet 内优化**  
  对每个 meshlet 调用 `meshopt_optimizeMeshlet(meshlet_vertices + m.vertex_offset, meshlet_triangles + m.triangle_offset, m.triangle_count, m.vertex_count)`，可进一步改善三角形与顶点的局部性，有利于顶点缓存与压缩。

### 计算 Meshlet 包围与锥体：`meshopt_computeMeshletBounds`

- **函数**：  
  `meshopt_computeMeshletBounds(meshlet_vertex_indices, meshlet_triangles, triangle_count, vertex_positions, vertex_count, vertex_position_stride)`

- **返回**：`meshopt_Bounds`，包含：  
  - **包围球**：`center[3]`、`radius`；  
  - **锥体**（用于背面剔除）：`cone_apex`、`cone_axis`、`cone_cutoff`，以及量化版 `cone_axis_s8`、`cone_cutoff_s8`（便于用更少字节存储）。

- **用法**：  
  在 CPU 端对每个 meshlet 调用一次，将得到的 center、radius、cone_axis、cone_cutoff（或量化值）写入 GPU buffer；task shader 或 compute 中做视锥剔除（球与六面体）、背面剔除（锥与视线）时直接使用这些数据。

### 其他与 meshlet 相关的 API

- **meshopt_buildMeshletsScan**：基于**已按顶点缓存优化**的索引，贪心地把连续三角形打成 meshlet，适合加载时快速构建，质量一般不如 `meshopt_buildMeshlets`。  
- **meshopt_buildMeshletsFlex**：支持 `min_triangles` / `max_triangles` 和 `split_factor`，可得到更偏空间局部性的 meshlet，适合层级 LOD 或高级剔除。  
- **簇光追**：若做基于 meshlet 的光追（如 Nvidia 的 cluster acceleration structure），可用 `meshopt_buildMeshletsSpatial` 按 SAH 做空间划分，得到更适合光追的簇；与光栅化用的 `meshopt_buildMeshlets` 侧重点不同。

---

## 在 Meshlet 管线中的使用方式（对应本章实现）

第 6 章将大 mesh 拆成 meshlet、在 GPU 上做视锥与背面剔除、再用 mesh shader 绘制，其**数据来源**正是 meshoptimizer。下面按流程说明如何在本章风格的管线中使用该库。

### 1. 准备输入

- 已有**顶点缓冲**（至少包含位置，如 `vec3`）和**索引缓冲**（三角形列表）。  
- 建议先对索引做 **顶点缓存优化**（`meshopt_optimizeVertexCache`），再做 **顶点拉取优化**（`meshopt_optimizeVertexFetch`），这样生成的 meshlet 更紧凑、后续压缩与 GPU 访问更友好。

### 2. 分配并构建 meshlet

```cpp
const size_t max_vertices = 64;
const size_t max_triangles = 124;  // 或 126，依 Vulkan 扩展限制
const float cone_weight = 0.0f;   // 不用锥体剔除时可设为 0

size_t max_meshlets = meshopt_buildMeshletsBound(
    index_count, max_vertices, max_triangles);

std::vector<meshopt_Meshlet> meshlets(max_meshlets);
std::vector<unsigned int>   meshlet_vertices(max_meshlets * max_vertices);
std::vector<unsigned char>  meshlet_triangles(max_meshlets * max_triangles * 3);

size_t meshlet_count = meshopt_buildMeshlets(
    meshlets.data(),
    meshlet_vertices.data(),
    meshlet_triangles.data(),
    indices, index_count,
    &vertices[0].x, vertex_count, sizeof(Vertex),
    max_vertices, max_triangles, cone_weight);
```

- `meshlet_vertices` 存的是**原始顶点缓冲中的顶点索引**；  
- `meshlet_triangles` 存的是**每个三角形 3 个字节**的局部顶点索引（0~63），即 meshlet 内的微索引。  
- 构建后根据 `meshlets[meshlet_count - 1]` 的 offset+count 对三个数组做 resize，再上传 GPU。

### 3. 为每个 meshlet 计算包围与锥体

```cpp
for (size_t m = 0; m < meshlet_count; ++m) {
    const meshopt_Meshlet& ml = meshlets[m];
    meshopt_Bounds b = meshopt_computeMeshletBounds(
        meshlet_vertices.data() + ml.vertex_offset,
        meshlet_triangles.data() + ml.triangle_offset,
        ml.triangle_count,
        &vertices[0].x, vertex_count, sizeof(Vertex));
    // 将 b.center, b.radius, b.cone_axis_s8, b.cone_cutoff_s8 等写入 GPU
}
```

- 本章实现中常用**量化后的锥体**（`cone_axis_s8`、`cone_cutoff_s8`）以节省每 meshlet 的存储；  
- task shader 中：将 `center`、`radius` 变换到世界/相机空间做视锥剔除，用 `cone_axis`、`cone_cutoff` 做背面剔除（如 `dot(normalize(camera - center), cone_axis) >= cone_cutoff` 则剔除）。

### 4. 可选：meshlet 内优化与压缩

- **优化**：对每个 meshlet 调用 `meshopt_optimizeMeshlet`，再上传 `meshlet_vertices` / `meshlet_triangles`，可略微提升顶点缓存命中与解码速度。  
- **压缩**：若需存储或流式传输，可用 `meshopt_encodeMeshlet` / `meshopt_decodeMeshlet` 对每个 meshlet 的顶点引用与三角形数据编码；解码端可在 CPU 或 GPU（如 compute）上做。编码前建议先做 `meshopt_optimizeMeshlet`。

### 5. 与 task / mesh shader 的对应关系

- **Task shader**：每 work group 处理一批 meshlet；根据 GPU buffer 中的 meshlet 包围球与锥体做视锥与背面剔除，通过 subgroup 等写出**可见 meshlet 索引**和 `gl_TaskCountNV`，驱动后续 mesh shader 的派发。  
- **Mesh shader**：每个 work group 对应一个**可见 meshlet**；根据 meshlet 的 `vertex_offset`、`triangle_offset`、`vertex_count`、`triangle_count` 从 `meshlet_vertices` 与 `meshlet_triangles` 中读取顶点索引与三角形，从**原始顶点缓冲**取顶点属性，输出 `gl_MeshVerticesNV` 与图元索引（如 `writePackedPrimitiveIndices4x8NV`），并设置 `gl_PrimitiveCountNV`。

因此，meshoptimizer 在本章管线中的角色是：**离线/加载时**生成 meshlet 几何与包围数据；**运行时** GPU 只消费这些缓冲，不再依赖库本身。

---

## 其他功能简述

- **网格压缩**：`meshopt_encodeVertexBuffer` / `meshopt_decodeVertexBuffer`、`meshopt_encodeIndexBuffer` / `meshopt_decodeIndexBuffer` 对顶点与索引做无损编码，体积通常可再缩小数倍，解码速度约 3–6 GB/s；可再配合 zstd/LZ4 等通用压缩。  
- **简化（LOD）**：`meshopt_simplify`、`meshopt_simplifyWithAttributes` 等可生成更少三角形的 LOD；若做层级 LOD，可与 meshlet 分区（`meshopt_partitionClusters`）结合。  
- **簇分区**：`meshopt_partitionClusters` 将多个 meshlet 分成若干分区，便于批处理或类似 Nanite 的层级简化。

---

## 构建与集成

- 库以 C++ 头文件 `src/meshoptimizer.h` 和若干 `src/*.cpp` 分发；可仅添加你使用的算法的源文件。  
- 使用前 `#include "meshoptimizer.h"`；头文件 C 兼容，实现为 C++。  
- 安装：可从 [GitHub](https://github.com/zeux/meshoptimizer) 克隆（如 `git clone -b v1.0 https://github.com/zeux/meshoptimizer.git`），或通过 vcpkg、Conan、各 Linux 发行版包安装。

---

## 许可与署名

meshoptimizer 采用 **MIT 许可证**。在用户可见的文档或致谢中建议包含类似说明：

> Uses meshoptimizer. Copyright (c) 2016-2026, Arseny Kapoulkine

---

**参考**：  
- 库主页与完整 API：[https://github.com/zeux/meshoptimizer](https://github.com/zeux/meshoptimizer)  
- Nvidia Turing mesh shader 介绍（max_vertices / max_primitives 等）：[Introduction to Turing Mesh Shaders](https://developer.nvidia.com/blog/introduction-turing-mesh-shaders/)
