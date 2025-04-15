// Import your vector types
import vec;
// Import OpenGL types/functions
import bindbc.opengl;

/// A struct representing x,y,z and r,g,b
struct VertexFormat3F3F {
    vec3 aPosition; // Use vec3
    vec3 aColor;    // Use vec3 (OBJ loader will store normal here)

    // Attribute setup for Position (loc 0) and Color/Normal (loc 1)
    static void SetupAttributes() {
        // Position Attribute (location = 0)
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, VertexFormat3F3F.sizeof, cast(void*)0);
        // Color/Normal Attribute (location = 1)
        glEnableVertexAttribArray(1);
        // Offset is after the first vec3 (position)
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, VertexFormat3F3F.sizeof, cast(void*)(vec3.sizeof));
    }

    static void DisableAttributes() {
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
    }
}

/// A struct representing for x,y,z and s,t
struct VertexFormat3F2F {
    vec3 aPosition;     // Use vec3
    vec2 aTextureCoord; // Use vec2

    // Attribute setup for Position (loc 0) and TexCoord (loc 2 - common convention)
    static void SetupAttributes() {
        // Position Attribute (location = 0)
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, VertexFormat3F2F.sizeof, cast(void*)0);
        // Texture Coordinate Attribute (location = 2)
        glEnableVertexAttribArray(2);
         // Offset is after the first vec3 (position)
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, VertexFormat3F2F.sizeof, cast(void*)(vec3.sizeof));
    }

     static void DisableAttributes() {
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(2);
    }
}

/// A struct representing for x,y,z, nx,ny,nz, and s,t
struct VertexFormat3F3F2F {
    vec3 aPosition;     // Use vec3 (Fixed typo aPostition -> aPosition)
    vec3 aNormal;       // Use vec3
    vec2 aTextureCoord; // Use vec2

    // Attribute setup for Pos (0), Normal (1), TexCoord (2)
    static void SetupAttributes() {
        // Position Attribute (location = 0)
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, VertexFormat3F3F2F.sizeof, cast(void*)0);
        // Normal Attribute (location = 1)
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, VertexFormat3F3F2F.sizeof, cast(void*)(vec3.sizeof)); // Offset = sizeof(vec3)
        // Texture Coordinate Attribute (location = 2)
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, VertexFormat3F3F2F.sizeof, cast(void*)(vec3.sizeof + vec3.sizeof)); // Offset = sizeof(vec3)*2
    }

    static void DisableAttributes() {
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(2);
    }
}

/// A struct representing for x,y,z, nx,ny,nz, bnx,bny,bnz, tnx,tny,tnz, and s,t
struct VertexFormat3F3F2F3F3F {
     vec3 aPosition;     // Use vec3
     vec3 aNormal;       // Use vec3
     vec2 aTextureCoord; // Use vec2
     vec3 aBiNormal;     // Use vec3
     vec3 aBiTangent;    // Use vec3
     // Add static SetupAttributes/DisableAttributes if needed, calculating offsets carefully
}