module io.objparser;

import std.file : readText;
import std.string : splitLines, strip, split;
import std.conv : to;
import std.array : appender;
import bindbc.opengl;

// Simple vertex with a position and normal.
struct Vertex {
    GLfloat[3] pos;
    GLfloat[3] norm;
}

// Struct to hold parsed OBJ data.
struct ParsedOBJData {
    Vertex[] vertices;
    uint[] indices;
}

// Helper function to parse an OBJ file.
ParsedOBJData parseOBJ(string filename) {
    GLfloat[3][] positions;
    GLfloat[3][] normals;
    ParsedOBJData parsedData;
    int[string] vertexMap;

    string fileText = readText(filename);
    auto lines = fileText.splitLines;
    foreach(line; lines) {
        auto tokens = line.strip.split(" ");
        if(tokens.length == 0 || tokens[0] == "#")
            continue;
        if(tokens[0] == "v") {
            if(tokens.length >= 4)
                positions ~= [tokens[1].to!GLfloat, tokens[2].to!GLfloat, tokens[3].to!GLfloat];
        }
        else if(tokens[0] == "vn") {
            if(tokens.length >= 4)
                normals ~= [tokens[1].to!GLfloat, tokens[2].to!GLfloat, tokens[3].to!GLfloat];
        }
        else if(tokens[0] == "f") {
            uint[] faceIndices;
            foreach(token; tokens[1 .. $]) {
                auto parts = token.split("/");
                int vIndex = parts[0].to!int;
                int vnIndex = 0;
                if(parts.length >= 3 && parts[2].length > 0)
                    vnIndex = parts[2].to!int;
                else if(parts.length == 2 && parts[1].length > 0)
                    vnIndex = parts[1].to!int;
                int posIndex = vIndex - 1;
                int normIndex = vnIndex - 1;
                string key = posIndex.to!string ~ "/" ~ normIndex.to!string;
                if(key in vertexMap)
                    faceIndices ~= cast(uint) vertexMap[key];
                else {
                    Vertex vert;
                    if(posIndex >= 0 && posIndex < positions.length)
                        vert.pos = positions[posIndex];
                    else
                        vert.pos = [0.0f, 0.0f, 0.0f];
                    if(normIndex >= 0 && normIndex < normals.length)
                        vert.norm = normals[normIndex];
                    else
                        vert.norm = [0.0f, 0.0f, 0.0f];
                    parsedData.vertices ~= vert;
                    uint newIndex = cast(uint)(parsedData.vertices.length - 1);
                    vertexMap[key] = newIndex;
                    faceIndices ~= newIndex;
                }
            }
            if(faceIndices.length == 3)
                parsedData.indices ~= faceIndices;
            else if(faceIndices.length > 3) {
                for(size_t i = 1; i < faceIndices.length - 1; i++) {
                    parsedData.indices ~= faceIndices[0];
                    parsedData.indices ~= faceIndices[i];
                    parsedData.indices ~= faceIndices[i+1];
                }
            }
        }
    }
    return parsedData;
}

// Import the Mesh type from rendering.mesh (to avoid duplicate definitions).
import rendering.mesh : Mesh;

// Create a Mesh from parsed OBJ data.
Mesh createMeshFromOBJ(ParsedOBJData parsedData) {
    Mesh m;
    size_t vertexCount = parsedData.vertices.length;
    GLfloat[] vertexArray;
    vertexArray.length = vertexCount * 6; // 3 floats for position, 3 for normal.
    for(size_t i = 0; i < vertexCount; i++) {
        for(int j = 0; j < 3; j++) {
            vertexArray[i * 6 + j] = parsedData.vertices[i].pos[j];
            vertexArray[i * 6 + 3 + j] = parsedData.vertices[i].norm[j];
        }
    }
    // Generate and bind VAO.
    glGenVertexArrays(1, &m.VAO);
    glBindVertexArray(m.VAO);
    // Generate and fill VBO.
    glGenBuffers(1, &m.VBO);
    glBindBuffer(GL_ARRAY_BUFFER, m.VBO);
    glBufferData(GL_ARRAY_BUFFER, vertexArray.length * GLfloat.sizeof, vertexArray.ptr, GL_STATIC_DRAW);
    // Generate and fill EBO.
    glGenBuffers(1, &m.EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m.EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, parsedData.indices.length * uint.sizeof, parsedData.indices.ptr, GL_STATIC_DRAW);
    // Configure vertex attributes: position at location 0, normal at location 1.
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * GLfloat.sizeof, cast(void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * GLfloat.sizeof, cast(void*)(3 * GLfloat.sizeof));
    glBindVertexArray(0);
    m.count = parsedData.indices.length;
    return m;
}

// Loads an OBJ file by parsing and creating a Mesh.
Mesh LoadOBJFile(string filename) {
    auto parsed = parseOBJ(filename);
    return createMeshFromOBJ(parsed);
}
