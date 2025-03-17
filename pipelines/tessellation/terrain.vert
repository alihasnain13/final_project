#version 410 core

// Input vertex attributes.
layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec2 aTexCoords;

// Outputs to the tessellation control shader.
out vec2 vTexCoords;
out vec4 vWorldCoords;

// Uniform transformation matrices.
uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

void main() {
    // Compute world coordinates.
    vWorldCoords = uModel * vec4(aPosition, 1.0);
    vTexCoords = aTexCoords;
    // Compute final vertex position.
    gl_Position = uProjection * uView * vWorldCoords;
}