#version 410 core

in  vec2 vTexCoords;
out vec4 fragColor;

uniform sampler2D sampler1;

void main()
{
	vec3 color = texture(sampler1,vTexCoords).rgb;

	fragColor = vec4(color, 1.0);
}
