/// Module for generating terrain geometry (Hi-Res Triangles or Lo-Res Patches)
module terraingeometry;

// D Standard Libs
import std.stdio : writeln, stderr;
import std.math : sqrt; // Or wherever necessary math functions are
import std.exception;
import std.conv : to;

// OpenGL Bindings
import bindbc.opengl;

// Project Libs
import geometry;      // ISurface base class
import vertexformats; // VertexFormat3F3F2F struct
import linear;        // vec3, Cross, Normalize (ASSUMED)
import png_loader;    // loadHeightmap function
import gamut;         // Image type

/// Geometry Surface for Terrain. Can generate a high-resolution mesh
/// for standard rendering or a low-resolution patch grid for tessellation.
class SurfaceTerrain : ISurface {
    // --- Member Variables ---
    GLuint mVBO = 0;
    GLuint mIBO = 0;
    // mVAO is inherited from ISurface

    VertexFormat3F3F2F[] mVertices; // Vertex buffer data (Position, Normal, TexCoord)
    GLuint[] mIndices;              // Index buffer data (Triangles or Patch Control Points)

    // Information about the generated mesh
    size_t mTriangles;          // Number of triangles (only for HiRes mode)
    uint mGridWidth;            // Number of vertices wide (HiRes or LoRes grid)
    uint mGridHeight;           // Number of vertices high (HiRes or LoRes grid)
    GLenum mDrawMode = GL_TRIANGLES; // Primitive type to use for drawing
    int mPatchVertices = 0;      // Vertices per patch for GL_PATCHES (e.g., 4 for Quads)

    // these are needed as uniforms for the Tessellation Evaluation Shader.
    float mYScale = 1.0f;
    float mYShift = 0.0f;

    enum float TERRAIN_X_SCALE = 2.0f;
    enum float TERRAIN_Z_SCALE = 2.0f;

    // Define desired world height range ONCE for consistency
    enum float WORLD_MAX_HEIGHT = 210.0f;
    enum float WORLD_MIN_HEIGHT = -40.0f;

    uint  getHeightmapWidth()  { return mGridWidth;  }
    uint  getHeightmapHeight() { return mGridHeight; }

    /* world-space extents after TERRAIN_X/Z_SCALE have been applied */
    vec2  getWorldSize() const
    {
        return vec2( cast(float)mGridWidth  * TERRAIN_X_SCALE,
                    cast(float)mGridHeight * TERRAIN_Z_SCALE );
    }

    
    this(string heightmap_file, bool generatePatches = false, uint patchRez = 64) {
        // load heightmap ONCE to calculate scale/shift factors needed by both paths
        Image heightmapImage;
        try {
            heightmapImage = loadHeightmap(heightmap_file, PixelType.l8); // L8 is assumed / confirmed in image.d and  png_loader.d
        } catch (Exception e) {
            throw new Exception("SurfaceTerrain: Failed to load heightmap '"~heightmap_file~"' to calculate scale/shift: "~e.msg);
        }

        uint imgWidth = heightmapImage.width;
        uint imgHeight = heightmapImage.height;
        if (imgWidth < 2 || imgHeight < 2) { throw new Exception("Heightmap dimensions too small."); }

        // Calculate and store scale/shift based on loaded image (or constants)
        CalculateScaleShift(heightmapImage);

        // Generate the appropriate geometry
        if (generatePatches) {
            // calculating world size to keep in scale
            float targetWorldSizeX = imgWidth * TERRAIN_X_SCALE;
            float targetWorldSizeZ = imgHeight * TERRAIN_Z_SCALE;

            // Generate low-res grid covering the calculated world size
            MakeTerrainPatchQuadGrid(patchRez, patchRez, targetWorldSizeX, targetWorldSizeZ);
            this.mDrawMode = GL_PATCHES;
            this.mPatchVertices = 4; // using quads for tessellation
        } else {
            // Generate high-res mesh using the loaded image
            MakeTerrainHiRes(heightmapImage, heightmap_file); // Pass already loaded image
            this.mDrawMode = GL_TRIANGLES;
            this.mPatchVertices = 0;
        }
    }

    float getYScale() { return mYScale; }
    float getYShift() { return mYShift; }

    ~this() {
        if (mVAO != 0) { writeln("Destroying SurfaceTerrain VAO: ", mVAO); glDeleteVertexArrays(1, &mVAO); }
        if (mVBO != 0) { writeln("Destroying SurfaceTerrain VBO: ", mVBO); glDeleteBuffers(1, &mVBO); }
        if (mIBO != 0) { writeln("Destroying SurfaceTerrain IBO: ", mIBO); glDeleteBuffers(1, &mIBO); }
        writeln("SurfaceTerrain buffers destroyed.");
    }

    /// Renders the geometry using the mode set during construction.
    override void Render() {
        if (mVAO == 0) return; // don't render if setup failed
        glBindVertexArray(mVAO);
        glDrawElements(mDrawMode, cast(GLsizei)mIndices.length, GL_UNSIGNED_INT, null);
        
    }

    // --- Private Helper Methods ---

    /// Calculates scale/shift based on heightmap range and world constants.
    private void CalculateScaleShift(ref const(Image) heightmapImage) {
         mYScale = (WORLD_MAX_HEIGHT - WORLD_MIN_HEIGHT) / 255.0f;
         mYShift = WORLD_MIN_HEIGHT;
         writeln("Terrain Scale/Shift Calculated: Scale=", mYScale, ", Shift=", mYShift);
    }

    /// Generates the high-resolution triangle mesh from the heightmap.
    private void MakeTerrainHiRes(ref const(Image) heightmapImage, string filenameForLog) {
        uint width = heightmapImage.width;
        uint height = heightmapImage.height;
        mGridWidth = width; mGridHeight = height; // Store hi-res grid dimensions

        if (width < 2 || height < 2) { throw new Exception("Heightmap dimensions too small for HiRes generation."); }
        writeln("Generating HI-RES terrain mesh from ", width, "x", height, " heightmap...");

        // Use pre-calculated scale/shift members
        float yScale = mYScale;
        float yShift = mYShift;

        const float terrainXScale = TERRAIN_X_SCALE;
        const float terrainZScale = TERRAIN_Z_SCALE;
        float xOffset = -cast(float)width * terrainXScale / 2.0f;
        float zOffset = -cast(float)height * terrainZScale / 2.0f;

        mVertices.length = 0; mIndices.length = 0;
        mVertices.reserve(width * height);

        // Generate Vertices (Position, Placeholder Normal, TexCoord)
        for (uint z = 0; z < height; z++) {
            ubyte* rowPtr = cast(ubyte*)heightmapImage.scanptr(z); 
            for (uint x = 0; x < width; x++) {
                ubyte rawY = rowPtr[x];
                float vx = x * terrainXScale + xOffset;
                float vy = cast(float)rawY * yScale + yShift;
                float vz = z * terrainZScale + zOffset;
                float tu = cast(float)x / (width - 1);
                float tv = cast(float)z / (height - 1);
                mVertices ~= VertexFormat3F3F2F([vx, vy, vz],[0.0f, 1.0f, 0.0f],[tu, tv]);
            }
        }

        // Generate Indices for TRIANGLES
        mIndices.reserve((width - 1) * (height - 1) * 6);
        for (uint z = 0; z < height - 1; z++) {
            for (uint x = 0; x < width - 1; x++) {
                GLuint topLeft = z * width + x; GLuint topRight = topLeft + 1;
                GLuint bottomLeft = (z + 1) * width + x; GLuint bottomRight = bottomLeft + 1;
                // triangle 1: TL -> BL -> TR
                mIndices ~= topLeft; mIndices ~= bottomLeft; mIndices ~= topRight;
                // triangle 2: TR -> BL -> BR
                mIndices ~= topRight; mIndices ~= bottomLeft; mIndices ~= bottomRight;
            }
        }
        mTriangles = mIndices.length / 3;
        writeln("Generated ", mVertices.length, " vertices and ", mIndices.length, " indices (", mTriangles, " triangles).");

        // Calculate Normals for the generated vertices
        calculateNormals();

        // Setup OpenGL buffers for this mesh
        SetupOpenGLBuffers();
        writeln("OpenGL HI-RES buffers created.");
    }

    /// Generates vertices and indices for a low-res QUAD grid for tessellation.
    private void MakeTerrainPatchQuadGrid(uint patchesX, uint patchesZ, float worldSizeX, float worldSizeZ) {
        writeln("Generating terrain patch grid: ", patchesX, "x", patchesZ);
        mVertices.length = 0; mIndices.length = 0;
        uint vertsX = patchesX + 1; // Need one more vertex than patches in each dimension
        uint vertsZ = patchesZ + 1;
        mGridWidth = vertsX; mGridHeight = vertsZ; // Store low-res grid dimensions
        mVertices.reserve(vertsX * vertsZ);

        if (patchesX < 1 || patchesZ < 1) { throw new Exception("Patch grid resolution must be at least 1x1."); }

        float xOffset = -worldSizeX / 2.0f;
        float zOffset = -worldSizeZ / 2.0f;

        // Generate control point vertices (Y=0)
        for (uint z = 0; z < vertsZ; z++) {
             for (uint x = 0; x < vertsX; x++) {
                 float vx = x * (worldSizeX / patchesX) + xOffset;
                 float vy = 0.0f; // Flat grid, Y displacement happens in TES
                 float vz = z * (worldSizeZ / patchesZ) + zOffset;
                 float tu = cast(float)x / patchesX;
                 float tv = cast(float)z / patchesZ;

                 mVertices ~= VertexFormat3F3F2F([vx, vy, vz],[0.0f, 1.0f, 0.0f],[tu, tv]);
             }
        }

        // Generate indices for QUADS (4 vertices per patch)
        // Each element in IBO defines ONE patch (4 control points)
        mIndices.reserve(patchesX * patchesZ * 4);
        for (uint z = 0; z < patchesZ; z++) {
            for (uint x = 0; x < patchesX; x++) {
                 GLuint topLeft = z * vertsX + x;
                 GLuint bottomLeft = (z + 1) * vertsX + x;
                 GLuint bottomRight = bottomLeft + 1;
                 GLuint topRight = topLeft + 1;

                 mIndices ~= topLeft;
                 mIndices ~= bottomLeft;
                 mIndices ~= bottomRight;
                 mIndices ~= topRight;
             }
        }
        mTriangles = 0; // Not applicable for patches
        writeln("Generated ", mVertices.length, " patch vertices and ", mIndices.length, " patch indices.");

        // normals are NOT calculated for the flat patch grid

        // Setup OpenGL buffers for this grid
        SetupOpenGLBuffers();
        writeln("OpenGL PATCH buffers created.");
    }

    /// Helper to setup VAO/VBO/IBO after vertices/indices are generated.
    private void SetupOpenGLBuffers() {
         // Clean up old buffers if they exist (e.g., if switching modes later)
         if (mVAO != 0) { glDeleteVertexArrays(1, &mVAO); mVAO = 0; }
         if (mVBO != 0) { glDeleteBuffers(1, &mVBO); mVBO = 0; }
         if (mIBO != 0) { glDeleteBuffers(1, &mIBO); mIBO = 0; }

         // Check if data exists before proceeding
         if (mVertices.length == 0 || mIndices.length == 0) {
              stderr.writeln("Warning: Attempting to setup OpenGL buffers with no vertex or index data.");
              return;
         }

         glGenVertexArrays(1, &mVAO);
         glBindVertexArray(mVAO);

         glGenBuffers(1, &mIBO);
         glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO);
         glBufferData(GL_ELEMENT_ARRAY_BUFFER, mIndices.length * GLuint.sizeof, mIndices.ptr, GL_STATIC_DRAW);

         glGenBuffers(1, &mVBO);
         glBindBuffer(GL_ARRAY_BUFFER, mVBO);
         glBufferData(GL_ARRAY_BUFFER, mVertices.length * VertexFormat3F3F2F.sizeof, mVertices.ptr, GL_STATIC_DRAW);

         SetVertexAttributes!VertexFormat3F3F2F();

         glBindVertexArray(0);
         glBindBuffer(GL_ARRAY_BUFFER, 0);
         glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
         writeln("OpenGL buffers setup complete (VAO:", mVAO, ")");
    }

    /// Calculates vertex normals for the Hi-Res mesh.
    private void calculateNormals() {
        if (mDrawMode != GL_TRIANGLES || mVertices.length == 0 || mIndices.length == 0) return; // Only for triangles

        writeln("Calculating normals...");
        foreach (ref v; mVertices) { v.aNormal = [0.0f, 0.0f, 0.0f]; }
        for (size_t i = 0; i < mIndices.length; i += 3) {
            GLuint i1 = mIndices[i]; GLuint i2 = mIndices[i+1]; GLuint i3 = mIndices[i+2];
            if (i1 >= mVertices.length || i2 >= mVertices.length || i3 >= mVertices.length) { continue; }

            vec3 v1 = vec3(mVertices[i1].aPosition[0], mVertices[i1].aPosition[1], mVertices[i1].aPosition[2]);
            vec3 v2 = vec3(mVertices[i2].aPosition[0], mVertices[i2].aPosition[1], mVertices[i2].aPosition[2]);
            vec3 v3 = vec3(mVertices[i3].aPosition[0], mVertices[i3].aPosition[1], mVertices[i3].aPosition[2]);
            vec3 edge1 = v2 - v1; vec3 edge2 = v3 - v1;

            vec3 faceNormal = Cross(edge1, edge2); 
            mVertices[i1].aNormal[0] += faceNormal.x; mVertices[i1].aNormal[1] += faceNormal.y; mVertices[i1].aNormal[2] += faceNormal.z;
            mVertices[i2].aNormal[0] += faceNormal.x; mVertices[i2].aNormal[1] += faceNormal.y; mVertices[i2].aNormal[2] += faceNormal.z;
            mVertices[i3].aNormal[0] += faceNormal.x; mVertices[i3].aNormal[1] += faceNormal.y; mVertices[i3].aNormal[2] += faceNormal.z;
        }
        foreach (ref v; mVertices) {
             vec3 n = vec3(v.aNormal[0], v.aNormal[1], v.aNormal[2]);
             n = Normalize(n); // Use Normalize from linear
             v.aNormal = [n.x, n.y, n.z];
        }
        writeln("Normals calculated.");
    }
}