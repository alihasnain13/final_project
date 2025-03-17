#version 410 core

in vec2 teTexCoords;
in vec4 teWorldCoords;

out vec4 fragColor;

uniform sampler2D sampler1;
uniform sampler2D sampler2;
uniform sampler2D sampler3;
uniform sampler2D sampler4;

vec3 GetColor() {
    // Match the maximum height used in your terrain geometry.
    float maxHeight = 85.0;
    float normHeight = clamp(teWorldCoords.y / maxHeight, 0.0, 1.0);

    vec3 tex1Color = texture(sampler1, teTexCoords).rgb;
    vec3 tex2Color = texture(sampler2, teTexCoords).rgb;
    vec3 tex3Color = texture(sampler3, teTexCoords).rgb;
    vec3 tex4Color = texture(sampler4, teTexCoords).rgb;

    vec3 color;
    if (normHeight < 0.20) {
        color = tex1Color;
    } else if (normHeight < 0.33) {
        float factor = smoothstep(0.20, 0.33, normHeight);
        color = mix(tex1Color, tex2Color, factor);
    } else if (normHeight < 0.66) {
        color = tex2Color;
    } else if (normHeight < 0.75) {
        float factor = smoothstep(0.66, 0.75, normHeight);
        color = mix(tex2Color, tex3Color, factor);
    } else if (normHeight < 0.80) {
        color = tex3Color;
    } else {
        float factor = smoothstep(0.80, 1.0, normHeight);
        color = mix(tex3Color, tex4Color, factor);
    }
    return color;
}

void main() {
    fragColor = vec4(GetColor(), 1.0);
}
