#version 410 core

in  vec3 vColor;
out vec4 fragColor;

void main()
{
	fragColor = vec4(vColor.r,vColor.g,vColor.b, 1.0f);
}
