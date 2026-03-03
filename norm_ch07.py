# -*- coding: utf-8 -*-
path = r"src/vulkan/MasteringGraphicProgramingWithVulkan/part-2-gpu-driven/chapter-07-clustered-deferred-rendering/README.md"
with open(path, "r", encoding="utf-8") as f:
    s = f.read()
s = s.replace("\u2019", "'")
with open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("Done")
