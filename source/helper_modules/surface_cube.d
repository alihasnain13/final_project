module surface_cube;

import bindbc.opengl;
import geometry;
import std.stdio;

class SurfaceCube : ISurface {
    GLuint mVAO, mVBO, mIBO;
    // Hard-coded cube vertex data: 8 vertices, with positions only.
    // (A real implementation would include normals or colors if desired.)
    GLfloat[] vertices = [
        // positions for a cube of side length 1, centered at origin.
       -0.5f, -0.5f, -0.5f,
        0.5f, -0.5f, -0.5f,
        0.5f,  0.5f, -0.5f,
       -0.5f,  0.5f, -0.5f,
       -0.5f, -0.5f,  0.5f,
        0.5f, -0.5f,  0.5f,
        0.5f,  0.5f,  0.5f,
       -0.5f,  0.5f,  0.5f
    ];

    // Indices for 12 triangles (2 per cube face).
    GLuint[] indices = [
        0, 1, 2,  2, 3, 0, // back face
        4, 5, 6,  6, 7, 4, // front face
        0, 4, 7,  7, 3, 0, // left face
        1, 5, 6,  6, 2, 1, // right face
        3, 2, 6,  6, 7, 3, // top face
        0, 1, 5,  5, 4, 0  // bottom face
    ];

    this() {
        // Generate and bind VAO.
        glGenVertexArrays(1, &mVAO);
        glBindVertexArray(mVAO);

        // Setup VBO.
        glGenBuffers(1, &mVBO);
        glBindBuffer(GL_ARRAY_BUFFER, mVBO);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * GLfloat.sizeof, vertices.ptr, GL_STATIC_DRAW);

        // Setup IBO.
        glGenBuffers(1, &mIBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mIBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * GLuint.sizeof, indices.ptr, GL_STATIC_DRAW);

        // Setup attributes - assuming location 0 is for vertex positions.
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * GLfloat.sizeof, cast(void*)0);
        glEnableVertexAttribArray(0);

        // Unbind VAO.
        glBindVertexArray(0);
    }

    override void Render() {
        glBindVertexArray(mVAO);
        glDrawElements(GL_TRIANGLES, cast(GLuint)indices.length, GL_UNSIGNED_INT, null);
    }
}
