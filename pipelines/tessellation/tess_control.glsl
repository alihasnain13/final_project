#version 410 core

// Specify that each patch consists of 4 vertices.
layout(vertices = 4) out;

in vec2 vTexCoords[];
in vec4 vWorldCoords[];

out vec2 tcTexCoords[];
out vec4 tcWorldCoords[];

uniform float uTessInner;
uniform float uTessOuter;

void main() {
    // Pass through the texture coordinates and world coordinates to the evaluation stage.
    tcTexCoords[gl_InvocationID] = vTexCoords[gl_InvocationID];
    tcWorldCoords[gl_InvocationID] = vWorldCoords[gl_InvocationID];

    // Only one invocation (usually the first) sets the tessellation levels.
    if (gl_InvocationID == 0) {
        // Set outer and inner tessellation levels. These values can be adjusted for LOD.
        gl_TessLevelOuter[0] = uTessOuter;
        gl_TessLevelOuter[1] = uTessInner;
        gl_TessLevelOuter[2] = uTessOuter;
        gl_TessLevelOuter[3] = uTessInner;
        gl_TessLevelInner[0] = uTessInner;
        gl_TessLevelInner[1] = uTessInner;
    }
}
