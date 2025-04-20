/// OBJ File Creation
module objgeometry;

import bindbc.opengl;
import std.file;
import std.stdio;
import std.string;
import std.conv;
import geometry;
import linear;
import error;

// A struct to hold the parsed OBJ data.
struct OBJData {
    float[][] vertices;      // Each element: [x, y, z]
    float[][] normals;       // Each element: [nx, ny, nz]
    float[][] texCoords;     // Each element: [u, v]
    int[] vertexIndices;     // Flattened indices for vertex positions
    int[] normalIndices;     // Flattened indices for normals
    int[] texIndices;        // Flattened indices for texture coordinates
}

// Helper function to parse the OBJ file.
OBJData parseOBJFile(string filepath) {
    OBJData data;
    // Open the file for reading.
    auto file = File(filepath, "r");
    foreach (line; file.byLine()) {
        auto trimmed = line.strip();    // Now works because of "import std.string"
        if (trimmed.length == 0 || trimmed.startsWith("#"))
            continue;
        // Parse vertex positions.
        if (trimmed.startsWith("v ")) {
            auto tokens = trimmed.split(" ");
            if(tokens.length >= 4) {
                float x = tokens[1].to!float;
                float y = tokens[2].to!float;
                float z = tokens[3].to!float;
                data.vertices ~= [x, y, z];
            }
        }
        // Parse vertex normals.
        else if (trimmed.startsWith("vn ")) {
            auto tokens = trimmed.split(" ");
            if(tokens.length >= 4) {
                float nx = tokens[1].to!float;
                float ny = tokens[2].to!float;
                float nz = tokens[3].to!float;
                data.normals ~= [nx, ny, nz];
            }
        }
        // Parse texture coordinates.
        else if (trimmed.startsWith("vt ")) {
            auto tokens = trimmed.split(" ");
            if(tokens.length >= 3) {
                float u = tokens[1].to!float;
                float v = tokens[2].to!float;
                data.texCoords ~= [u, v];
            }
        }
        // Parse face definitions.
        else if (trimmed.startsWith("f ")) {
            auto tokens = trimmed.split(" ");
            // Process every face token (skip the "f" token at index 0).
            foreach(i; 1 .. tokens.length) {
                auto parts = tokens[i].split("/");
                // OBJ indices start at 1.
                data.vertexIndices ~= parts[0].to!int - 1;
                if(parts.length > 1 && parts[1].length > 0)
                    data.texIndices ~= parts[1].to!int - 1;
                if(parts.length > 2 && parts[2].length > 0)
                    data.normalIndices ~= parts[2].to!int - 1;
            }
        }
    }
    return data;
}

vec3 parseMTLDiffuseColor(string mtlFilename, string materialName) {
    string text = readText(mtlFilename);
    bool targetFound = false;
    foreach (line; text.splitLines()) {
        auto trimmed = line.strip();
        if (trimmed.length == 0 || trimmed.startsWith("#"))
            continue;
        if (trimmed.startsWith("newmtl")) {
            auto tokens = trimmed.split();
            if (tokens.length >= 2 && tokens[1] == materialName) {
                targetFound = true;
            } else if (targetFound) {
                // If we were reading the target material and now see another material declaration, exit.
                break;
            }
        } else if (targetFound && trimmed.startsWith("Kd")) {
            auto tokens = trimmed.split();
            if (tokens.length >= 4) {
                float r = tokens[1].to!float;
                float g = tokens[2].to!float;
                float b = tokens[3].to!float;
                return vec3(r, g, b);
            }
        }
    }
    // Return white if not found (or choose another default).
    return vec3(1.0f, 1.0f, 1.0f);
}

/// Geometry stores all of the vertices and/or indices for a 3D object.
/// Geometry also has the responsibility of setting up the 'attributes'
class SurfaceOBJ : ISurface {
    GLuint mVBO;
    GLuint mIBO;
    GLuint mVAO; // Added VAO
    GLfloat[] mVertexData;
    GLfloat[] mNormalData;
    GLfloat[] mTextureData;
    GLuint[] mIndexData;
    size_t mTriangles;

    /// Geometry data
    this(string filename) {
        MakeOBJ(filename);
    }

    /// Render our geometry
    override void Render() {
        // Bind to our geometry that we want to draw
        glBindVertexArray(mVAO);
        // Call our draw call
        glDrawElements(GL_TRIANGLES, cast(GLuint)mIndexData.length, GL_UNSIGNED_INT, null);
    }

    void MakeOBJ(string filepath) {
        // Use our helper function to parse the file.
        auto objData = parseOBJFile(filepath);

        // For simplicity, assume each face is a triangle and build the flat arrays.
        // This example aligns vertex positions and normals.
        foreach (vi; objData.vertexIndices) {
            // Append vertex position.
            auto v = objData.vertices[vi];
            mVertexData ~= v[0];
            mVertexData ~= v[1];
            mVertexData ~= v[2];
        }
        // Similarly, build normal data based on the parsed indices.
        foreach (ni; objData.normalIndices) {
            auto n = objData.normals[ni];
            mNormalData ~= n[0];
            mNormalData ~= n[1];
            mNormalData ~= n[2];
        }
        // mIndexData can be a simple sequential array.
        foreach(i; 0 .. (mVertexData.length / 3)) {
            mIndexData ~= cast(uint)i;  // <--- Cast i to uint
        }

        // Vertex Arrays Object (VAO) Setup
        glGenVertexArrays(1, &mVAO);
        glBindVertexArray(mVAO);

        // Index Buffer Object (IBO)
        glGenBuffers(1, &mIBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, mIndexData.length * GLuint.sizeof, mIndexData.ptr, GL_STATIC_DRAW);

        // Vertex Buffer Object (VBO) creation
        GLfloat[] allData;
        for(size_t i = 0; i < mVertexData.length; i += 3) {
            allData ~= mVertexData[i];
            allData ~= mVertexData[i + 1];
            allData ~= mVertexData[i + 2];
            allData ~= mNormalData[i];
            allData ~= mNormalData[i + 1];
            allData ~= mNormalData[i + 2];
        }

        glGenBuffers(1, &mVBO);
        glBindBuffer(GL_ARRAY_BUFFER, mVBO);
        glBufferData(GL_ARRAY_BUFFER, allData.length * VertexFormat3F3F.sizeof, allData.ptr, GL_STATIC_DRAW);

        // Function call to setup attributes
        SetVertexAttributes!VertexFormat3F3F();

        // Unbind our currently bound Vertex Array Object
        glBindVertexArray(0);
        // Turn off attributes
        DisableVertexAttributes!VertexFormat3F3F();
    }
}
