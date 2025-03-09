#version 410 core

in vec2 vTexCoords;
in vec4 vWorldCoords;

out vec4 fragColor;

uniform sampler2D sampler1;
uniform sampler2D sampler2;
uniform sampler2D sampler3;
uniform sampler2D sampler4;

vec3 GetColor() {
    // Set the maximum height to match your geometry
    float maxHeight = 85.0;
    // Normalize the height (assuming vWorldCoords.y is in [0, maxHeight])
    float normHeight = clamp(vWorldCoords.y / maxHeight, 0.0, 1.0);

    // Sample each texture
    vec3 tex1Color = texture(sampler1, vTexCoords).rgb;
    vec3 tex2Color = texture(sampler2, vTexCoords).rgb;
    vec3 tex3Color = texture(sampler3, vTexCoords).rgb;
    vec3 tex4Color = texture(sampler4, vTexCoords).rgb;

    vec3 color;

    // Define narrow blending bands:
    if(normHeight < 0.20) {
        // Below 0.20: use texture 1
        color = tex1Color;
    } else if(normHeight < 0.33) {
        // Between 0.20 and 0.33: blend from texture 1 to texture 2
        float factor = smoothstep(0.20, 0.33, normHeight);
        color = mix(tex1Color, tex2Color, factor);
    } else if(normHeight < 0.66) {
        // From 0.33 to 0.66: use texture 2
        color = tex2Color;
    } else if(normHeight < 0.75) {
        // Between 0.66 and 0.80: blend from texture 2 to texture 3
        float factor = smoothstep(0.66, 0.75, normHeight);
        color = mix(tex2Color, tex3Color, factor);
    } else if(normHeight < 0.80) {
        // From 0.80 to 0.93: use texture 3
        color = tex3Color;
    } else {
        // Between 0.93 and 1.0: blend from texture 3 to texture 4
        float factor = smoothstep(0.80, 1.0, normHeight);
        color = mix(tex3Color, tex4Color, factor);
    }
    
    return color;
}

void main() {
    fragColor = vec4(GetColor(), 1.0);
}
