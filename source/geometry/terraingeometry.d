/// Create a triangle strip for terrain
module terraingeometry;

import bindbc.opengl;
import std.stdio;
import geometry;
import core;
import error;

// toggle tessellation on/off
shared bool useTessellation = false;


/// Geometry stores all of the vertices and/or indices for a 3D object.
/// Geometry also has the responsibility of setting up the 'attributes'
class SurfaceTerrain: ISurface{
    GLuint mVBO;
    GLuint mIBO;
    GLuint mTessIBO; // new IBO for tessellation indices

    VertexFormat3F2F[] mVertices;
    GLuint[] mIndices;
    GLuint[] mTessIndices;  // For tessellation (quad patches).
    size_t mTriangles;

    uint mXDimensions;
    uint mZDimensions;

    /// Constructor to make a new terrain.
    /// filename - heightmap filename
    this(uint xDim, uint zDim, string heightmap_file){
        mXDimensions = xDim;
        mZDimensions = zDim;
        MakeTerrain(xDim,zDim, heightmap_file);
    }

    /// Render our geometry
    // NOTE: It can be handy with terrains to draw them in wireframe
    //       mode to otherwise debug them.
    // NOTE: It can be handy with terrains to draw as 'points' to make sure
    //  		 the 'grid' is otherwise generated correctly if you have trouble
    // 			 with indexing.
    override void Render(){
        // Bind to our geometry that we want to draw
        glBindVertexArray(mVAO);
        // Call our draw call

        if(useTessellation) { // TODO: review this!!
            // Tessellation mode: use the patch draw call.
            glPatchParameteri(GL_PATCH_VERTICES, 4);
            // Bind the tessellation index buffer.
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mTessIBO);
            // The total number of patches is (mXDimensions - 1) * (mZDimensions - 1).
            int totalPatches = cast(int)((mXDimensions - 1) * (mZDimensions - 1));
            int totalIndices = totalPatches * 4; // 4 vertices per patch.
            glDrawElements(GL_PATCHES, totalIndices, GL_UNSIGNED_INT, cast(void*)0);
        } else {
            // Standard mode: use the triangle strip draw call.
            // Bind the original index buffer.
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO);
            for (uint z = 0; z < mZDimensions - 1; z++) {
                size_t indexCount = mXDimensions * 2;
                size_t offset = z * indexCount * GLuint.sizeof;
                glDrawElements(GL_TRIANGLE_STRIP, cast(int)indexCount, GL_UNSIGNED_INT, cast(void*)offset);
            }
        }

        glBindVertexArray(0);
    }

    /// Setup MeshNode as a Triangle
    void MakeTerrain(uint xDim, uint zDim, string heightmap_file){
        // Create a grid of vertices
        // Important to keep track of how we generate grid.
        // We iterate trough 'x' on inner loop, so we produce
        // 'rows' across first.
        PPM heights;
        ubyte[] height_values = heights.LoadPPMImage(heightmap_file);

        for(int z=0; z < zDim; z++){
            for(int x=0; x < xDim; x++){

                // Add vertices in a grid
                size_t currIndex = z * xDim + x;

                float heightValue = cast(float) height_values[currIndex];
                float maxHeight = 85.0f;  // maximum height in the heightmap
                float y = (heightValue / 255.0f) * maxHeight;

                // calculate x and z positions
                float posX = cast(float)x;
                float posZ = cast(float)z;

                // compute UV coordinates normalized over the grid
                float u = cast(float)x / (xDim - 1);
                float v = cast(float)(z) / (zDim - 1);

                // create and add the vertex
                mVertices ~= VertexFormat3F2F([posX, y, posZ], [u, v]);
            }
        }

        // Connect the grid of vertices with indices
        for(uint z=0; z < zDim-1; z++){
            for(uint x=0; x < xDim; x++){

                // compute the index for the vertex in the current row (z)
                int index1 = z * xDim + x;
                // and for the vertex in the next row (z + 1)
                int index2 = (z + 1) * xDim + x;

                mIndices ~= index1; 	
                mIndices ~= index2; 	
            }
        }

        // Generate tessellation indices for quads.
        // For each quad in the grid, create a patch with 4 vertices.
        for(uint z = 0; z < zDim - 1; z++) {
            for(uint x = 0; x < xDim - 1; x++) {
                int topLeft = z * xDim + x;
                int topRight = topLeft + 1;
                int bottomLeft = (z + 1) * xDim + x;
                int bottomRight = bottomLeft + 1;
                // Order: topLeft, topRight, bottomRight, bottomLeft.
                mTessIndices ~= topLeft;
                mTessIndices ~= topRight;
                mTessIndices ~= bottomRight;
                mTessIndices ~= bottomLeft;
            }
        }
        

        // Setup VAO and VBO (same as before).
        glGenVertexArrays(1, &mVAO);
        glBindVertexArray(mVAO);

        // Setup IBO for standard mode.
        glGenBuffers(1, &mIBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, mIndices.length * GLuint.sizeof, mIndices.ptr, GL_STATIC_DRAW);

        // Setup VBO.
        glGenBuffers(1, &mVBO);
        glBindBuffer(GL_ARRAY_BUFFER, mVBO);
        glBufferData(GL_ARRAY_BUFFER, mVertices.length * VertexFormat3F2F.sizeof, mVertices.ptr, GL_STATIC_DRAW);

        // Setup vertex attributes.
        SetVertexAttributes!VertexFormat3F2F();

        glBindVertexArray(0);
        DisableVertexAttributes!VertexFormat3F2F();

        // Setup IBO for tessellation mode.
        glGenBuffers(1, &mTessIBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mTessIBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, mTessIndices.length * GLuint.sizeof, mTessIndices.ptr, GL_STATIC_DRAW);
        // Unbind the buffer.
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    }
}


