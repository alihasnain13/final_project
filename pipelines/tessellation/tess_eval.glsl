#version 410 core

// We're using quads with even spacing.
layout(quads, fractional_even_spacing, ccw) in;

in vec2 tcTexCoords[];
in vec4 tcWorldCoords[];

out vec2 teTexCoords;
out vec4 teWorldCoords;

uniform mat4 uView;
uniform mat4 uProjection;

void main() {
    // Interpolate texture coordinates and world coordinates across the patch.
    vec2 texA = mix(tcTexCoords[0], tcTexCoords[1], gl_TessCoord.x);
    vec2 texB = mix(tcTexCoords[3], tcTexCoords[2], gl_TessCoord.x);
    teTexCoords = mix(texA, texB, gl_TessCoord.y);
    
    vec4 worldA = mix(tcWorldCoords[0], tcWorldCoords[1], gl_TessCoord.x);
    vec4 worldB = mix(tcWorldCoords[3], tcWorldCoords[2], gl_TessCoord.x);
    teWorldCoords = mix(worldA, worldB, gl_TessCoord.y);

    // Compute final vertex position.
    gl_Position = uProjection * uView * teWorldCoords;
}
