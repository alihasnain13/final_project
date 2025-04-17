#version 410 core

// Input: Control point vertices for the LOW-RES grid
// Matches your VertexFormat3F3F2F layout VBO
layout (location = 0) in vec3 aPosition;     // Base Position (Y=0 from Lo-Res Grid)
layout (location = 1) in vec3 aNormal;       // Received but likely unused here (Normal of flat grid)
layout (location = 2) in vec2 aTextureCoord; // TexCoord spanning patch/terrain (0..1)

// Output: Data per control point for the TCS
out vec3 tcPosition;     // Pass position through
out vec2 tcTexCoord;     // Pass texcoord through
// out vec3 tcNormal;    // We could pass the base normal if needed later

void main()
{
    // Pass the relevant control point data directly to the TCS.
    // The actual height displacement and MVP transformation for the
    // final detailed vertices will happen in the TES.
    tcPosition = aPosition;
    tcTexCoord = aTextureCoord;
    // tcNormal = aNormal; // Optionally pass if TES/TCS needs base normal

    // DO NOT calculate gl_Position here.
}