#version 410 core

in vec3  vWorldPos;
in vec2  vTexCoord;

// texture layers
uniform sampler2D sampler1, sampler2, sampler3, sampler4;

// lighting
uniform vec3  uLightPos;
uniform vec3  uLightColor;
uniform vec3  uViewPos;

uniform vec3  uMaterialAmbient;
uniform vec3  uMaterialDiffuse;
uniform vec3  uMaterialSpecular;
uniform float uShininess;

// height thresholds & blend range (same as your standard shader)
const float heightLayer1_End = -15.0;
const float heightLayer2_End =  40.0;
const float heightLayer3_End =  90.0;
const float blendRange       =   2.5;

// smooth blend helper
float getSmoothBlend(float threshold, float range, float h) {
    return smoothstep(threshold - range, threshold + range, h);
}

out vec4 fragColor;

void main() {
    // --- 1) blend the four terrain textures by world‐Y ---
    vec3 c1 = texture(sampler1, vTexCoord).rgb;
    vec3 c2 = texture(sampler2, vTexCoord).rgb;
    vec3 c3 = texture(sampler3, vTexCoord).rgb;
    vec3 c4 = texture(sampler4, vTexCoord).rgb;

    vec3 baseColor = c1;
    baseColor = mix(baseColor, c2, getSmoothBlend(heightLayer1_End, blendRange, vWorldPos.y));
    baseColor = mix(baseColor, c3, getSmoothBlend(heightLayer2_End, blendRange, vWorldPos.y));
    baseColor = mix(baseColor, c4, getSmoothBlend(heightLayer3_End, blendRange, vWorldPos.y));

    // --- 2) approximate the normal from the displaced mesh using derivatives ---
    vec3 normal = normalize(cross(dFdx(vWorldPos), dFdy(vWorldPos)));

    // --- 3) compute Blinn‑Phong lighting ---
    vec3 L = normalize(uLightPos - vWorldPos);
    vec3 V = normalize(uViewPos  - vWorldPos);
    vec3 R = reflect(-L, normal);

    // ambient
    vec3 ambient = uMaterialAmbient * uLightColor;

    // diffuse
    float diff = max(dot(normal, L), 0.0);
    vec3 diffuse = uMaterialDiffuse * uLightColor * diff;

    // specular
    float spec = pow(max(dot(V, R), 0.0), uShininess);
    vec3 specular = uMaterialSpecular * uLightColor * spec;

    // --- 4) combine ---
    vec3 color = baseColor * (ambient + diffuse) + specular;
    fragColor = vec4(color, 1.0);
}
