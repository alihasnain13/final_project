#version 410 core

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aNormal;
//layout(location = 2) in vec2 aTexture;

out VS_OUT {
    vec3 FragPos;    // World-space position
    vec3 Normal;     // Normal vector
    // vec2 TexCoord; // Uncomment if you add textures
} vs_out;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

void main()
{
    // Compute the world-space position of the vertex.
    vec4 worldPos = uModel * vec4(aPosition, 1.0);
    vs_out.FragPos = worldPos.xyz;

    // Properly transform the normal; note this assumes non-uniform scaling is not an issue,
    // otherwise consider using the inverse transpose of the model matrix.
    vs_out.Normal = mat3(transpose(inverse(uModel))) * aNormal;

    gl_Position = uProjection * uView * worldPos;
}
