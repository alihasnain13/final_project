/// Create a triangle strip for terrain
module terraingeometry;

import bindbc.opengl;
import std.stdio;
import geometry;
import core;
import error;

/// Geometry stores all of the vertices and/or indices for a 3D object.
/// Geometry also has the responsibility of setting up the 'attributes'
class SurfaceTerrain: ISurface{
    GLuint mVBO;
    GLuint mIBO;

    VertexFormat3F2F[] mVertices;
    GLuint[] mIndices;
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

        // draw the terrain as a triangle strip
        for (uint z = 0; z < mZDimensions - 1; z++) {

            // strip uses 2 * mXDimensions indices
            size_t indexCount = mXDimensions * 2;
            // calculate the offset into the index buffer
            size_t offset = z * indexCount * GLuint.sizeof;

            glDrawElements(GL_TRIANGLE_STRIP, cast(int) indexCount, GL_UNSIGNED_INT, cast(void*) offset);
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

        // Vertex Arrays Object (VAO) Setup
        glGenVertexArrays(1, &mVAO);
        // We bind (i.e. select) to the Vertex Array Object (VAO) that we want to work withn.
        glBindVertexArray(mVAO);

        // Index Buffer Object (IBO)
        glGenBuffers(1, &mIBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, mIndices.length* GLuint.sizeof, mIndices.ptr, GL_STATIC_DRAW);

        // Vertex Buffer Object (VBO) creation
        glGenBuffers(1, &mVBO);
        glBindBuffer(GL_ARRAY_BUFFER, mVBO);
        glBufferData(GL_ARRAY_BUFFER, mVertices.length* VertexFormat3F2F.sizeof, mVertices.ptr, GL_STATIC_DRAW);

        // Function call to setup attributes
        SetVertexAttributes!VertexFormat3F2F();

        // Unbind our currently bound Vertex Array Object
        glBindVertexArray(0);

        // Turn off attributes
        DisableVertexAttributes!VertexFormat3F2F();
    }
}


