#version 410 core

// Input from TES
in float vNormalizedHeight; // Normalized height (0-1)

// --- Uniform Declarations (Declare ALL added in D code) ---
uniform sampler2D sampler1, sampler2, sampler3, sampler4;
uniform sampler2D uHeightMap;
uniform float uYScale, uYShift;
uniform vec3 uLightPos, uLightColor, uViewPos;
uniform vec3 uMaterialAmbient, uMaterialDiffuse, uMaterialSpecular;
uniform float uShininess;

// Output
out vec4 fragColor;

void main()
{
    // --- DEBUG: Output normalized height as grayscale ---
    // Black = Min Height (-40), White = Max Height (210)
    fragColor = vec4(vNormalizedHeight, vNormalizedHeight, vNormalizedHeight, 1.0);
}