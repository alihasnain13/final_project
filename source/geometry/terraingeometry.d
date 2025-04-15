// In source/geometry/terraingeometry.d
module terraingeometry; // Adjusted module name to match path

import bindbc.opengl;
import std.stdio;
import std.math; // For sin, cos if needed later, maybe approxEqual
import std.exception;
import std.conv : to; // For string conversion if needed

// Use specific imports from geometry package
import geometry;
import core;           // For PPM struct
import linear;               // For vec2, vec3, Normalize

/// Creates terrain geometry from a P3 PPM heightmap (expecting R=G=B grayscale).
class SurfaceTerrain : ISurface {
    // OpenGL handles (ensure mVAO is accessible, e.g., from ISurface)
    // GLuint mVAO; // If not inherited, declare here
    GLuint mVBO;
    GLuint mIBO;

    // Use vertex format with normals for lighting!
    VertexFormat3F3F2F[] mVertices;
    GLuint[] mIndices;

    // Store dimensions and scaling
    uint mGridWidth;
    uint mGridHeight;
    float mXZScale = 1.0f;
    float mYScale = 10.0f; // Controls terrain height exaggeration

    /// Constructor to make a new terrain from a P3 PPM file.
    /// Takes filename and optional scaling factors.
    this(string heightmap_p3_file, float scaleXZ = 1.0f, float scaleY = 10.0f) {
        // Store scaling factors
        mXZScale = scaleXZ;
        mYScale = scaleY;
        // Generate the terrain mesh
        MakeTerrain(heightmap_p3_file);
    }

     /// Destructor (important to clean up OpenGL resources if not done by base class)
    ~this() {
        if (mVBO != 0) glDeleteBuffers(1, &mVBO);
        if (mIBO != 0) glDeleteBuffers(1, &mIBO);
        // Make sure mVAO is declared/accessible in this class or base class
        if (mVAO != 0) glDeleteVertexArrays(1, &mVAO);
        writeln("Cleaned up SurfaceTerrain GL resources.");
    }


    // --- Helper: Reads height from interleaved RGB data (takes R component) ---
    private float getHeightFromRGB(int x, int y, const(ubyte)[] rgb_pixels, uint width, uint height, uint maxValue) {
        // Clamp coordinates to valid range to avoid errors at edges during normal calculation
        if (x < 0) x = 0;
        if (x >= width) x = width - 1;
        if (y < 0) y = 0;
        if (y >= height) y = height - 1;

        // Index points to the R component for pixel (x, y)
        size_t index = (y * width + x) * 3; // Stride is 3 bytes
        // Safety check for pixel array bounds
        if (index >= rgb_pixels.length) {
             stderr.writeln("getHeightFromRGB: Index out of bounds (", index, " >= ", rgb_pixels.length, ") for xy(", x, ",", y, ")");
             return 0.0f; // Return safe value on error
        }
        ubyte heightVal = rgb_pixels[index]; // Read the R value

        // Normalize 8-bit value (0-maxValue) to 0.0-1.0 and scale by mYScale
        // Use double for intermediate calculation for slightly better precision
        return (cast(double)heightVal / maxValue) * mYScale;
    }

    // --- Helper: Calculates normal using height derived from RGB data ---
    private vec3 calculateNormalFromRGB(int x, int z, const(ubyte)[] rgb_pixels, uint width, uint height, uint maxValue) {
        // Get heights of neighbouring pixels using the helper
        float heightL = getHeightFromRGB(x - 1, z, rgb_pixels, width, height, maxValue); // Left
        float heightR = getHeightFromRGB(x + 1, z, rgb_pixels, width, height, maxValue); // Right
        float heightD = getHeightFromRGB(x, z - 1, rgb_pixels, width, height, maxValue); // Down (towards -Z)
        float heightU = getHeightFromRGB(x, z + 1, rgb_pixels, width, height, maxValue); // Up (towards +Z)

        // Calculate normal vector using finite differences
        // The Y component affects steepness influence relative to XZ scale
        vec3 normal = vec3(heightL - heightR, 2.0f * mXZScale, heightD - heightU);
        // Handle cases where normal might be zero vector (perfectly flat plane)
        if (LengthSquared(normal) < 0.00001f) {
            return vec3(0.0f, 1.0f, 0.0f); // Return up vector if flat
        }
        return Normalize(normal); // Make it a unit vector
    }


    /// Generates the terrain mesh from the loaded P3 PPM data
    void MakeTerrain(string heightmap_p3_file) {
        PPM ppmImage;
        writeln("Loading terrain heightmap (P3 expected): ", heightmap_p3_file);
        // Call the P3 loader from core.image
        bool loaded = ppmImage.load(heightmap_p3_file); // <-- FIXED FUNCTION CALL

        if (!loaded || ppmImage.mWidth == 0 || ppmImage.mHeight == 0) {
             stderr.writeln("MakeTerrain: Failed P3 load. Creating flat placeholder plane.");
             // Create a small default flat plane (ensure correct VertexFormat)
             mGridWidth = 2; mGridHeight = 2; mYScale = 0; mXZScale = 1.0;
             mVertices = [ VertexFormat3F3F2F(vec3(-1,0,-1), vec3(0,1,0), vec2(0,0)),
                           VertexFormat3F3F2F(vec3( 1,0,-1), vec3(0,1,0), vec2(1,0)),
                           VertexFormat3F3F2F(vec3(-1,0, 1), vec3(0,1,0), vec2(0,1)),
                           VertexFormat3F3F2F(vec3( 1,0, 1), vec3(0,1,0), vec2(1,1)) ];
             mIndices = [ 0, 2, 1, 3 ]; // Simple quad strip
        } else {
             // Use loaded data
             mGridWidth = ppmImage.mWidth;
             mGridHeight = ppmImage.mHeight;
             uint maxValue = ppmImage.mMaxValue;
             auto rgb_pixels = ppmImage.mPixels; // ubyte[] (R,G,B,...)

             writeln("Generating terrain mesh: ", mGridWidth, "x", mGridHeight);

             // --- Generate Vertices ---
             mVertices.length = mGridWidth * mGridHeight; // Pre-allocate
             size_t vtxIdx = 0;
             for (uint z = 0; z < mGridHeight; z++) { // Use uint for consistency
                 for (uint x = 0; x < mGridWidth; x++) {
                     float yPos = getHeightFromRGB(x, z, rgb_pixels, mGridWidth, mGridHeight, maxValue);
                     // Center terrain around origin
                     float xPos = (cast(float)x - (mGridWidth - 1) / 2.0f) * mXZScale;
                     float zPos = (cast(float)z - (mGridHeight - 1) / 2.0f) * mXZScale;
                     // Calculate texture coords (0.0 to 1.0)
                     float u = (mGridWidth > 1) ? cast(float)x / (mGridWidth - 1) : 0.0f;
                     float v = (mGridHeight > 1) ? cast(float)z / (mGridHeight - 1) : 0.0f;
                     // Calculate normal
                     vec3 normal = calculateNormalFromRGB(x, z, rgb_pixels, mGridWidth, mGridHeight, maxValue);

                     // Assign vertex data (ensure vec types match VertexFormat)
                     mVertices[vtxIdx++] = VertexFormat3F3F2F(vec3(xPos, yPos, zPos), normal, vec2(u, v));
                 }
             }

             // --- Generate Indices for Triangle Strip ---
             if (mGridWidth < 2 || mGridHeight < 2) {
                 writeln("Terrain too small to generate indices.");
                 mIndices = null; // No strips possible
             } else {
                 mIndices.length = (mGridHeight - 1) * mGridWidth * 2; // Pre-allocate
                 size_t idx = 0;
                 for (uint z = 0; z < mGridHeight - 1; z++) {
                     for (uint x = 0; x < mGridWidth; x++) {
                         uint index1 = z * mGridWidth + x;
                         uint index2 = (z + 1) * mGridWidth + x;
                         mIndices[idx++] = index1;
                         mIndices[idx++] = index2;
                     }
                 }
             }
        } // end else (loaded successfully)

        writeln("Generated ", mVertices.length, " vertices and ", mIndices.length, " indices.");

        // --- OpenGL Buffer Setup ---
        // Check if we actually have something to buffer
        if (mVertices.length > 0 && mIndices.length > 0) {
             // Ensure VAO is generated (assuming mVAO=0 initially)
             if (mVAO == 0) glGenVertexArrays(1, &mVAO);
             glBindVertexArray(mVAO);

             // VBO
             if (mVBO == 0) glGenBuffers(1, &mVBO); // Generate if not already existing
             glBindBuffer(GL_ARRAY_BUFFER, mVBO);
             // Use VertexFormat3F3F2F size
             glBufferData(GL_ARRAY_BUFFER, mVertices.length * VertexFormat3F3F2F.sizeof, mVertices.ptr, GL_STATIC_DRAW);

             // IBO
             if (mIBO == 0) glGenBuffers(1, &mIBO); // Generate if not already existing
             glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO);
             glBufferData(GL_ELEMENT_ARRAY_BUFFER, mIndices.length * GLuint.sizeof, mIndices.ptr, GL_STATIC_DRAW);

             // Setup vertex attributes using the correct format
             SetVertexAttributes!VertexFormat3F3F2F(); // Make sure this template exists and works!

             glBindVertexArray(0); // Unbind VAO
             glBindBuffer(GL_ARRAY_BUFFER, 0); // Unbind VBO
             glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); // Unbind IBO
             writeln("OpenGL buffers created/updated for terrain.");
        } else {
             stderr.writeln("MakeTerrain: No vertices/indices generated, skipping GL setup.");
             // Optional: Clean up existing buffers if they should be empty now?
             // if (mVBO != 0) { glDeleteBuffers(1, &mVBO); mVBO = 0; }
             // if (mIBO != 0) { glDeleteBuffers(1, &mIBO); mIBO = 0; }
             // if (mVAO != 0) { glDeleteVertexArrays(1, &mVAO); mVAO = 0; }
        }
    }


    /// Render the terrain mesh
    override void Render() {
        // Check if geometry is valid before rendering
        if (mVAO == 0 || mIndices.length == 0) {
             return; // Don't attempt to render if VAO/IBO isn't set up or empty
        }

        glBindVertexArray(mVAO);

        // Draw using triangle strips and the generated indices
        glDrawElements(
            GL_TRIANGLE_STRIP,          // mode
            cast(GLsizei)mIndices.length, // count (number of indices)
            GL_UNSIGNED_INT,            // type of indices
            null                        // pointer (offset, null because IBO is bound)
        );

        glBindVertexArray(0); // Unbind VAO
    }

} // end class SurfaceTerrain


// --- Template functions for Vertex Attributes ---
// IMPORTANT: Ensure these templates are defined *somewhere* accessible
// by this module (e.g., in geometry.vertexformats or a common helper module)
// and that VertexFormat3F3F2F has the necessary static methods.

// Example placeholder if not defined elsewhere:
// template SetVertexAttributes(VertexFormat) {
//     static if (__traits(hasMember, VertexFormat, "SetupAttributes")) {
//         VertexFormat.SetupAttributes();
//     } else {
//         static assert(false, "VertexFormat missing static SetupAttributes method");
//     }
// }

// template DisableVertexAttributes(VertexFormat) {
//     static if (__traits(hasMember, VertexFormat, "DisableAttributes")) {
//         VertexFormat.DisableAttributes();
//     } else {
//         static assert(false, "VertexFormat missing static DisableAttributes method");
//     }
// }