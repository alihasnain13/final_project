module rendering.shader;

import std.file : readText;
import bindbc.opengl;
import std.string : toStringz;
import std.stdio;

GLuint buildShaderProg(string vsPath, string fsPath)
{
    string vsSrc = readText(vsPath);
    string fsSrc = readText(fsPath);

    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    const char* vsPtr = vsSrc.ptr;
    glShaderSource(vs, 1, &vsPtr, null);
    glCompileShader(vs);
    checkShaderError(vs, "Vertex");

    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    const char* fsPtr = fsSrc.ptr;
    glShaderSource(fs, 1, &fsPtr, null);
    glCompileShader(fs);
    checkShaderError(fs, "Fragment");

    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glLinkProgram(prog);

    // Optionally check program link error
    {
        GLint status;
        glGetProgramiv(prog, GL_LINK_STATUS, &status);
        if(status == GL_FALSE)
        {
            char[512] info;
            glGetProgramInfoLog(prog, info.length, null, info.ptr);
            writeln("Program link error:\n", info.ptr);
        }
    }

    // Clean up
    glDetachShader(prog, vs);
    glDetachShader(prog, fs);
    glDeleteShader(vs);
    glDeleteShader(fs);

    return prog;
}

private void checkShaderError(GLuint shader, string stage)
{
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if(status == GL_FALSE)
    {
        char[512] info;
        glGetShaderInfoLog(shader, info.length, null, info.ptr);
        writeln(stage, " shader error:\n", info.ptr);
    }
}
