/// Interface for creating more geometry
module surface;

import bindbc.opengl;
import std.stdio;
import vertexformats;

/// Geometry stores all of the vertices and/or indices for a 3D object.
/// Geometry also has the responsibility of setting up the 'attributes'
abstract class ISurface{
    GLuint mVAO;

    /// Render function for geometry
    void Render();

    /// Helper function with some meta-programming that will allow you to generate
    /// the code that follows the layout of a struct for the attributes
    /// NOTE: Currently assumes all attributes are floating point values.
    void SetVertexAttributes(T)(){
        // Create an array of offsets
        mixin("ulong[",T.tupleof.length,"] offsets;");
        mixin("offsets[0] = 0;");

        // Vertex attributes
        static foreach (idx, m; T.tupleof) {
            mixin("glEnableVertexAttribArray(",idx,");");
            mixin("glVertexAttribPointer(",idx,", ",m.sizeof/float.sizeof,", GL_FLOAT, GL_FALSE, ",T.sizeof,", cast(GLvoid*)(GLfloat.sizeof*offsets[idx]));");
            static if(idx+1 < T.tupleof.length){
                mixin("offsets[",idx+1,"] = offsets[",idx,"] + ",m.sizeof/float.sizeof,";");
            }
        }

    }

    /// Turn off vertex attributegs
    void DisableVertexAttributes(T)(){
        // Disable attributes
        static foreach (idx, m; T.tupleof) {
            mixin("glDisableVertexAttribArray(",idx,");");
        }
    }

}

