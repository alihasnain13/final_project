#version 410 core

layout (location = 0) in vec3 aPosition;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aTextureCoord;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

out vec2 vTexCoord;
out vec3 vWorldPos;
out vec3 vNormal; // Ok to keep outputting this

void main()
{
    vec4 worldPos4 = uModel * vec4(aPosition, 1.0);
    vWorldPos = worldPos4.xyz;
    vTexCoord = aTextureCoord;
    vNormal = normalize(mat3(uModel) * aNormal); // Keep passing normal
    gl_Position = uProjection * uView * worldPos4;
}