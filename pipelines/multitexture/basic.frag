#version 410 core

// Inputs from Vertex Shader
in vec2 vTexCoord;  // Texture coordinates from vertex shader
in vec3 vWorldPos;  // World position from vertex shader (Y is height)

// Texture Samplers (needs 4 textures bound via MultiTextureMaterial)
// These names MUST match the names used in MultiTextureMaterial.Update()
uniform sampler2D sampler1; // e.g., Dirt/Low Ground texture
uniform sampler2D sampler2; // e.g., Grass texture
uniform sampler2D sampler3; // e.g., Rock texture
uniform sampler2D sampler4; // e.g., Snow/High Ground texture

// Output color for the fragment
out vec4 fragColor;

// --- Simple Height-Based Blending Parameters ---
// Adjust these world-space Y coordinate thresholds based on your terrain's
// height range (set by yScale/yShift in SurfaceTerrain) and desired look.
const float heightLayer1 = -2.0;  // Upper Y limit for Layer 1 (e.g., Dirt)
const float heightLayer2 = 5.0;   // Upper Y limit for Layer 2 (e.g., Grass)
const float heightLayer3 = 15.0;  // Upper Y limit for Layer 3 (e.g., Rock)
                                  // Layer 4 (e.g., Snow) covers everything above heightLayer3

// Controls how smoothly textures blend at the thresholds (larger value = smoother)
// Should generally be positive.
const float blendSharpness = 0.1; // Smaller value = sharper transition (like 0.05)
                                  // Larger value = smoother transition (like 0.2)

// Helper function for smooth blending based on height
// Returns a value between 0 and 1 indicating the blend factor towards the 'upper' texture.
float getHeightBlendFactor(float lowerBound, float height) {
    // Scale the height difference based on sharpness
    // Positive value makes upper texture appear, negative makes lower texture appear
    float scale = (height - lowerBound) / blendSharpness;
    // Clamp the result between 0 and 1
    return clamp(scale, 0.0, 1.0);
}


void main()
{
    // Sample all potential textures based on the vertex texture coordinates
    vec3 colorLayer1 = texture(sampler1, vTexCoord).rgb;
    vec3 colorLayer2 = texture(sampler2, vTexCoord).rgb;
    vec3 colorLayer3 = texture(sampler3, vTexCoord).rgb;
    vec3 colorLayer4 = texture(sampler4, vTexCoord).rgb;

    // Calculate blend factors based on world height (vWorldPos.y)
    // These factors determine how much of the 'next' layer to mix in.
    float blendFactor12 = getHeightBlendFactor(heightLayer1, vWorldPos.y);
    float blendFactor23 = getHeightBlendFactor(heightLayer2, vWorldPos.y);
    float blendFactor34 = getHeightBlendFactor(heightLayer3, vWorldPos.y);

    // Perform linear interpolation (mix) between layers
    // Start with the base layer (Layer 1)
    vec3 finalColor = colorLayer1;
    // Mix in Layer 2 based on blendFactor12
    finalColor = mix(finalColor, colorLayer2, blendFactor12);
    // Mix in Layer 3 based on blendFactor23
    finalColor = mix(finalColor, colorLayer3, blendFactor23);
    // Mix in Layer 4 based on blendFactor34
    finalColor = mix(finalColor, colorLayer4, blendFactor34);

    // Output the final blended color (no lighting) with full alpha
    fragColor = vec4(finalColor, 1.0);
}