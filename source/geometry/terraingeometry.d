/// Create a triangle strip for terrain
module terraingeometry;

import bindbc.opengl;
import std.stdio, std.math, std.exception;
import geometry;
import core;
import error;
import linear;

// might not need this?
import helper_modules;
import gamut;


/// Geometry stores all of the vertices and/or indices for a 3D object.
/// Geometry also has the responsibility of setting up the 'attributes'
class SurfaceTerrain: ISurface{
    GLuint mVBO;
    GLuint mIBO;
    // mVAO is inherited from ISurface

    VertexFormat3F3F2F[] mVertices;
    GLuint[] mIndices;
    size_t mTriangles;

    uint mXDimensions;
    uint mZDimensions;

    /// Constructor to make a new terrain.
    /// filename - heightmap filename
    this(string heightmap_file) {
        MakeTerrain(heightmap_file); // Generate mesh on construction
    }

    /// Destructor: Cleans up OpenGL buffer objects.
    ~this() {
        // Check if buffers exist before deleting (important!)
        // mVAO should always exist if constructor succeeded past glGenVertexArrays
        if (mVAO != 0) {
             writeln("Destroying SurfaceTerrain VAO: ", mVAO);
             glDeleteVertexArrays(1, &mVAO);
        }
        if (mVBO != 0) {
             writeln("Destroying SurfaceTerrain VBO: ", mVBO);
             glDeleteBuffers(1, &mVBO);
        }
        if (mIBO != 0) {
             writeln("Destroying SurfaceTerrain IBO: ", mIBO);
             glDeleteBuffers(1, &mIBO);
        }
         writeln("SurfaceTerrain buffers destroyed.");
    }

    /// Render our geometry
    // NOTE: It can be handy with terrains to draw them in wireframe
    //       mode to otherwise debug them.
    // NOTE: It can be handy with terrains to draw as 'points' to make sure
    //  		 the 'grid' is otherwise generated correctly if you have trouble
    // 			 with indexing.
    override void Render(){
        if(mVAO == 0) return;
        glBindVertexArray(mVAO);
        glDrawElements(GL_TRIANGLES, cast(GLsizei)mIndices.length, GL_UNSIGNED_INT, null);
        glBindVertexArray(0); // Optional unbind
    }

    /// Setup MeshNode as a Triangle
    void MakeTerrain(string heightmap_file){
        // load up heightMap image
        Image heightmapImage;
        
        try {
             // Load as 8-bit grayscale. Use PixelType.l16 for 16-bit maps (and adjust yScale)
             heightmapImage = loadHeightmap(heightmap_file, PixelType.l8);
        } catch (Exception e) {
             stderr.writeln("FATAL: Failed to load heightmap: ", heightmap_file);
             stderr.writeln(e.msg);
             stderr.writeln("Cannot create terrain. Exiting or creating fallback.");
        }

        uint width = heightmapImage.width;
        uint height = heightmapImage.height;
        mXDimensions = width;
        mZDimensions = height;

        if (width < 2 || height < 2) {
             stderr.writeln("Error: Heightmap dimensions too small (must be at least 2x2).");
             return;
        }

        writeln("Generating terrain mesh from ", width, "x", height, " heightmap...");

        // --- 2. Generate Vertices ---
        mVertices.length = 0; // Clear any previous data
        mIndices.length = 0;
        mVertices.reserve(width * height);

        // --- Constants for terrain shape ---
        // Adjust these to control the scale and vertical range of your terrain
        const float MAX_HEIGHT = 210.0f; // Maximum world height difference
        const float MIN_HEIGHT = -40.0f; // Minimum world height
        float yScale = (MAX_HEIGHT - MIN_HEIGHT) / 255.0f; // Scale factor (for L8: 0-255 range)
        float yShift = MIN_HEIGHT;       // Shift to set the minimum height
        // For L16: Adjust denominator to 65535.0f

        const float terrainXScale = 1.0f; // Size of one grid cell in world X coord
        const float terrainZScale = 1.0f; // Size of one grid cell in world Z coord
        // Calculate offsets to center the generated mesh around X=0, Z=0
        float xOffset = -cast(float)width * terrainXScale / 2.0f;
        float zOffset = -cast(float)height * terrainZScale / 2.0f;

        for (uint z = 0; z < height; z++) {
            ubyte* rowPtr = cast(ubyte*)heightmapImage.scanptr(z); // Assuming L8
            // For L16 use: ushort* rowPtr = cast(ushort*)heightmapImage.scanptr(z);

            for (uint x = 0; x < width; x++) {
                ubyte rawY = rowPtr[x]; // For L16 use: ushort rawY = rowPtr[x];

                // Calculate vertex position
                float vx = x * terrainXScale + xOffset;
                float vy = cast(float)rawY * yScale + yShift; // Apply scale and shift
                float vz = z * terrainZScale + zOffset;

                // Calculate texture coordinates (normalized 0.0 to 1.0)
                float tu = cast(float)x / (width - 1);
                float tv = cast(float)z / (height - 1);

                // Add vertex data (Position, Placeholder Normal, TexCoord)
                // Normal is calculated later
                mVertices ~= VertexFormat3F3F2F(
                    [vx, vy, vz],              // aPosition
                    [0.0f, 1.0f, 0.0f],        // aNormal (placeholder)
                    [tu, tv]                   // aTextureCoord
                );
            }
        }

        // --- 3. Generate Indices (GL_TRIANGLES) ---
        // Create indices for a grid composed of triangles
        mIndices.reserve((width - 1) * (height - 1) * 6); // 2 triangles per quad = 6 indices
        for (uint z = 0; z < height - 1; z++) {
            for (uint x = 0; x < width - 1; x++) {
                // Calculate indices of the 4 vertices forming a quad
                GLuint topLeft = z * width + x;
                GLuint topRight = topLeft + 1;
                GLuint bottomLeft = (z + 1) * width + x;
                GLuint bottomRight = bottomLeft + 1;

                // Create two triangles for the quad
                // Triangle 1: Top-Left -> Bottom-Left -> Top-Right
                mIndices ~= topLeft;
                mIndices ~= bottomLeft;
                mIndices ~= topRight;

                // Triangle 2: Top-Right -> Bottom-Left -> Bottom-Right
                mIndices ~= topRight;
                mIndices ~= bottomLeft;
                mIndices ~= bottomRight;
            }
        }
        mTriangles = mIndices.length / 3; // Store triangle count
        writeln("Generated ", mVertices.length, " vertices and ", mIndices.length, " indices (", mTriangles, " triangles).");

        // --- 4. Calculate Normals ---
        // This replaces the placeholder normals calculated in step 2
        calculateNormals();

        // --- 5. Setup OpenGL Buffers ---
        // Vertex Array Object (VAO) - Manages attribute pointers and VBO/IBO bindings
        glGenVertexArrays(1, &mVAO); // Generate VAO ID and store in inherited mVAO
        glBindVertexArray(mVAO);     // Bind the VAO to make it active

        // Index Buffer Object (IBO) - Stores triangle indices
        glGenBuffers(1, &mIBO);      // Generate IBO ID
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO); // Bind IBO to element array target
        // Upload index data to the GPU
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, mIndices.length * GLuint.sizeof, mIndices.ptr, GL_STATIC_DRAW);

        // Vertex Buffer Object (VBO) - Stores vertex data (pos, normal, texcoord)
        glGenBuffers(1, &mVBO);      // Generate VBO ID
        glBindBuffer(GL_ARRAY_BUFFER, mVBO); // Bind VBO to array buffer target
        // Upload vertex data to the GPU
        glBufferData(GL_ARRAY_BUFFER, mVertices.length * VertexFormat3F3F2F.sizeof, mVertices.ptr, GL_STATIC_DRAW);

        // Setup Vertex Attributes using the helper function from ISurface base class
        // This tells OpenGL how the data is laid out in the VBO
        SetVertexAttributes!VertexFormat3F3F2F(); // Use the correct vertex format type

        // Unbind VAO - IMPORTANT: Unbind VAO *before* unbinding GL_ELEMENT_ARRAY_BUFFER
        glBindVertexArray(0);
        // Unbind other buffers (good practice, though less critical after VAO unbind)
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

        writeln("OpenGL buffers created (VAO: ", mVAO, ", VBO: ", mVBO, ", IBO: ", mIBO, ")");
    }

    /// Calculate vertex normals by averaging the normals of adjacent faces.
    void calculateNormals() {
        // (calculateNormals function remains the same as before)
        if (mVertices.length == 0 || mIndices.length == 0) return;

        writeln("Calculating normals...");
        
        foreach (ref v; mVertices) { v.aNormal = [0.0f, 0.0f, 0.0f]; }
        for (size_t i = 0; i < mIndices.length; i += 3) { /* ... face normal accumulation ... */
            GLuint i1 = mIndices[i]; GLuint i2 = mIndices[i+1]; GLuint i3 = mIndices[i+2];
            if (i1 >= mVertices.length || i2 >= mVertices.length || i3 >= mVertices.length) { continue; }

            vec3 v1 = vec3(mVertices[i1].aPosition[0], mVertices[i1].aPosition[1], mVertices[i1].aPosition[2]);
            vec3 v2 = vec3(mVertices[i2].aPosition[0], mVertices[i2].aPosition[1], mVertices[i2].aPosition[2]);
            vec3 v3 = vec3(mVertices[i3].aPosition[0], mVertices[i3].aPosition[1], mVertices[i3].aPosition[2]);
            
            // Calculate edge vectors
            vec3 edge1 = v2 - v1;
            vec3 edge2 = v3 - v1;

            vec3 faceNormal = Cross(edge1, edge2);
            mVertices[i1].aNormal[0] += faceNormal.x; mVertices[i1].aNormal[1] += faceNormal.y; mVertices[i1].aNormal[2] += faceNormal.z;
            mVertices[i2].aNormal[0] += faceNormal.x; mVertices[i2].aNormal[1] += faceNormal.y; mVertices[i2].aNormal[2] += faceNormal.z;
            mVertices[i3].aNormal[0] += faceNormal.x; mVertices[i3].aNormal[1] += faceNormal.y; mVertices[i3].aNormal[2] += faceNormal.z;
        }

        foreach (ref v; mVertices) { /* ... normalize accumulated normals ... */
            vec3 n = vec3(v.aNormal[0], v.aNormal[1], v.aNormal[2]);
            n = Normalize(n); // Assuming Normalize exists in linear.d
            v.aNormal = [n.x, n.y, n.z]; // Store normalized normal back in vertex
        }

        writeln("Normals calculated.");
    }



}


