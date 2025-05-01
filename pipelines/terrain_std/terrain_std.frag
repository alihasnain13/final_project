#version 410 core

// Inputs from Vertex Shader
in vec2 vTexCoord;
in vec3 vWorldPos;
in vec3 vNormal; // World-space normal

// Texture Samplers
uniform sampler2D sampler1; // Dirt
uniform sampler2D sampler2; // Grass
uniform sampler2D sampler3; // Rock
uniform sampler2D sampler4; // Snow

// --- Lighting Uniforms ---
uniform vec3 uLightPos;
uniform vec3 uLightColor;
uniform vec3 uViewPos;         
uniform vec3 uMaterialAmbient;
uniform vec3 uMaterialDiffuse;
uniform vec3 uMaterialSpecular;
uniform float uShininess;      

// Output color
out vec4 fragColor;

// --- Height Thresholds & Blending ---
const float heightLayer1_End = -15.0;
const float heightLayer2_End = 40.0;
const float heightLayer3_End = 90.0;
const float blendRange = 2.5;

float getSmoothBlend(float threshold, float range, float height) {
    return smoothstep(threshold - range, threshold + range, height);
}

void main()
{
    // --- 1. Calculate Blended Texture Color ---
    // (Same as before)
    vec3 colorLayer1 = texture(sampler1, vTexCoord).rgb;
    vec3 colorLayer2 = texture(sampler2, vTexCoord).rgb;
    vec3 colorLayer3 = texture(sampler3, vTexCoord).rgb;
    vec3 colorLayer4 = texture(sampler4, vTexCoord).rgb;
    float blendFactor12 = getSmoothBlend(heightLayer1_End, blendRange, vWorldPos.y);
    float blendFactor23 = getSmoothBlend(heightLayer2_End, blendRange, vWorldPos.y);
    float blendFactor34 = getSmoothBlend(heightLayer3_End, blendRange, vWorldPos.y);
    vec3 baseTextureColor = colorLayer1;
    baseTextureColor = mix(baseTextureColor, colorLayer2, blendFactor12);
    baseTextureColor = mix(baseTextureColor, colorLayer3, blendFactor23);
    baseTextureColor = mix(baseTextureColor, colorLayer4, blendFactor34);

    // --- 2. Calculate Lighting (Ambient + Diffuse + Specular) ---

    vec3 normal = normalize(vNormal);
    vec3 viewDir = normalize(uViewPos - vWorldPos); // Vector from surface point to camera/eye
    vec3 lightDir = normalize(uLightPos - vWorldPos); // Vector from surface point to light

    // Ambient
    vec3 ambient = uLightColor * uMaterialAmbient;

    // Diffuse
    float diffFactor = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diffFactor * uLightColor * uMaterialDiffuse;

    vec3 reflectDir = reflect(-lightDir, normal); // Calculate the light's reflection direction
    // Calculate the alignment between the view direction and the reflection direction
    // Raise to the power of shininess: higher shininess = smaller/sharper highlight
    float specFactor = pow(max(dot(viewDir, reflectDir), 0.0), uShininess);
    // Final specular color component
    vec3 specular = specFactor * uLightColor * uMaterialSpecular;

    // --- 3. Combine Lighting and Texture ---
    // Add the specular highlights on top of the ambient/diffuse lit texture
    vec3 finalColor = baseTextureColor * (ambient + diffuse) + specular;

    // Output final lit and textured color
    fragColor = vec4(finalColor, 1.0);
}