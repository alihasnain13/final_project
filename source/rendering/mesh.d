module rendering.mesh;
import bindbc.opengl;
struct Mesh {
    GLuint VAO;
    GLuint VBO;
    GLuint EBO;
    int count; // number of indices (or vertices)
}
Mesh MakeQuadFactory() {
    Mesh m;
    // Quad vertex data: position and color.
    const GLfloat[] vertexData = [
        -0.5f, -0.5f, 0.0f,  1,0,0,
         0.5f, -0.5f, 0.0f,  0,1,0,
         0.5f,  0.5f, 0.0f,  0,0,1,
        -0.5f,  0.5f, 0.0f,  1,1,0
    ];
    const GLuint[] indices = [0,1,2, 0,2,3];
    m.count = indices.length;
    glGenVertexArrays(1, &m.VAO);
    glBindVertexArray(m.VAO);
    glGenBuffers(1, &m.VBO);
    glBindBuffer(GL_ARRAY_BUFFER, m.VBO);
    glBufferData(GL_ARRAY_BUFFER, vertexData.length*float.sizeof, vertexData.ptr, GL_STATIC_DRAW);
    glGenBuffers(1, &m.EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m.EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length*uint.sizeof, indices.ptr, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*float.sizeof, cast(void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*float.sizeof, cast(void*)(3*float.sizeof));
    glBindVertexArray(0);
    return m;
}
