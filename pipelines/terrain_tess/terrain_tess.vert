#version 410 core

layout (location = 0) in vec3 aPosition;
layout (location = 1) in vec3 aNormal;       // Ignored
layout (location = 2) in vec2 aTextureCoord;

out vec3 tcPosition;
out vec2 tcTexCoord;

void main() {
    tcPosition = aPosition;
    tcTexCoord = aTextureCoord;
}