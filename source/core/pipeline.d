/// This module contains an abstraction for shaders pipelines.
module pipeline;
import std.stdio, std.string, std.file, std.conv;
import bindbc.opengl;

/// A pipeline consists of all of the shader programs (e.g. vertex shader and fragment shader) to create an OpenGL 
/// program object. The OpenGL program object represents the 'graphics pipeline' that we select prior to a glDraw* call.
class Pipeline{
    /// Map of all of the pipelines that have been loaded
    static GLuint[string] sPipeline;

    // Name of current pipeline
    string mPipelineName;
    // Name in OpenGL of the current pipeline
    GLint mProgramObjectID;


    /// Constructor to build a graphics pipeline with a vertex shader and fragment shader source file
    this(string pipelineName, string vertexShaderSourceFilename, string fragmentShaderSourceFilename){
        CompilePipeline(pipelineName, vertexShaderSourceFilename, fragmentShaderSourceFilename);
    }



    /// Create a shader and store it in our pipelines map
    GLuint CompilePipeline(string pipelineName, string vertexShaderSourceFilename, string fragmentShaderSourceFilename){
        // Local nested function -- not meant for otherwise calling freely
        void CheckShaderError(GLuint shaderObject){
            // Retrieve the result of our compilation
            int result;
            // Our goal with glGetShaderiv is to retrieve the compilation status
            glGetShaderiv(shaderObject, GL_COMPILE_STATUS, &result);

            if(result == GL_FALSE){
                int length;
                glGetShaderiv(shaderObject, GL_INFO_LOG_LENGTH, &length);
                GLchar[] errorMessages = new GLchar[length];
                glGetShaderInfoLog(shaderObject, length, &length, errorMessages.ptr);
                writeln(errorMessages);
            }
        }

        // Compile our shaders
        GLuint vertexShader;
        GLuint fragmentShader;

        // Use a string mixin to simply 'load' the text from a file into these
        // strings that will otherwise be processed.
        string vertexSource 	= readText(vertexShaderSourceFilename);
        string fragmentSource 	= readText(fragmentShaderSourceFilename);

        // Compile vertex shader
        vertexShader = glCreateShader(GL_VERTEX_SHADER);
        const char* vSource = vertexSource.ptr;
        glShaderSource(vertexShader, 1, &vSource, null);
        glCompileShader(vertexShader);
        CheckShaderError(vertexShader);

        // Compile fragment shader
        fragmentShader= glCreateShader(GL_FRAGMENT_SHADER);
        const char* fSource = fragmentSource.ptr;
        glShaderSource(fragmentShader, 1, &fSource, null);
        glCompileShader(fragmentShader);
        CheckShaderError(fragmentShader);

        // Create shader pipeline
        mProgramObjectID = glCreateProgram();

        // Link our two shader programs together.
        // Consider this the equivalent of taking two .cpp files, and linking them into
        // one executable file.
        glAttachShader(mProgramObjectID,vertexShader);
        glAttachShader(mProgramObjectID,fragmentShader);
        glLinkProgram(mProgramObjectID);

        // Validate our program
        glValidateProgram(mProgramObjectID);

        // Once our final program Object has been created, we can
        // detach and then delete our individual shaders.
        glDetachShader(mProgramObjectID,vertexShader);
        glDetachShader(mProgramObjectID,fragmentShader);
        // Delete the individual shaders once we are done
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);

        // Store in the static pipeline map
        mPipelineName                   = pipelineName;
        sPipeline[mPipelineName]        = mProgramObjectID;

        // For debugging purposes, print out all information about the pipeline that has ben created
        PrintShaderAttributesAndUniforms(mPipelineName,mProgramObjectID);

        return mProgramObjectID;
    }
}

/// Select a pipelie for use. 
/// Note: You may consider
///       'alias' 'Bind' for 'Use' for consistency to match your API
///       i.e. 
///             alias Bind = Use;
static void PipelineUse(string name){
		// First validate that the name is in the static map
		GLint id = PipelineCheckValidName(name);

		// Second, validate that the 'value' is indeed a graphics pipeline object.
		if(glIsProgram(id) == GL_FALSE){
				writeln("error: This shader '"~name~"' does not correspond to an active/valid pipeline");
				writeln("This shader is: ",Pipeline.sPipeline[name]);
				writeln("Candidates are: ", Pipeline.sPipeline.values());
				assert(0,"Shader Use error");
		}

		// Activate our shader
		glUseProgram(Pipeline.sPipeline[name]);
}

static GLint PipelineCheckValidName(string name){
		if(name in Pipeline.sPipeline){
				return Pipeline.sPipeline[name];
		}
		writeln("'"~name~"' not found in pipelines");
		writeln("candidates are:",Pipeline.sPipeline);
		assert(0,"Pipeline User Error");
}


/// This is a handy debugging function for introspecting attribute and uniform information from shaders.
/// Translated From: https://web.archive.org/web/20240823152221/https://antongerdelan.net/opengl/shaders.html
void PrintShaderAttributesAndUniforms(string pipelineName, GLuint programme) {
    writeln("======="~pipelineName~" and # "~programme.to!string~"  (shader debug info)======");
    int params = -1;
    glGetProgramiv(programme, GL_LINK_STATUS, &params);
    writefln("GL_LINK_STATUS = %d", params);

    glGetProgramiv(programme, GL_ATTACHED_SHADERS, &params);
    writefln("GL_ATTACHED_SHADERS = %d", params);

    glGetProgramiv(programme, GL_ACTIVE_ATTRIBUTES, &params);
    writefln("GL_ACTIVE_ATTRIBUTES = %d", params);
    for (int i = 0; i < params; i++) {
        char[64] name;
        int max_length = 64;
        int actual_length = 0;
        int size = 0;
        GLenum type;
        glGetActiveAttrib (
                programme,
                i,
                max_length,
                &actual_length,
                &size,
                &type,
                name.ptr
                );
        if (size > 1) {
            for(int j = 0; j < size; j++) {
                char[64] long_name;
                writefln("%s[%d]", name, j);
                int location = glGetAttribLocation(programme, long_name.toStringz);
                writefln("  %d) type:%s\tname:%s\tlocation:%d",
                        i, GL_type_to_string(type), long_name, location);
            }
        } else {
            int location = glGetAttribLocation(programme, name.toStringz);
            writefln("  %d) type:%s\tname:%s\tlocation:%d",
                    i, GL_type_to_string(type), name, location);
        }
    }

    glGetProgramiv(programme, GL_ACTIVE_UNIFORMS, &params);
    printf("GL_ACTIVE_UNIFORMS = %d\n", params);
    for(int i = 0; i < params; i++) {
        char[64] name;
        int max_length = 64;
        int actual_length = 0;
        int size = 0;
        GLenum type;
        glGetActiveUniform(
                programme,
                i,
                max_length,
                &actual_length,
                &size,
                &type,
                name.ptr
                );
        if(size > 1) {
            for(int j = 0; j < size; j++) {
                char[64] long_name;
                writefln("%s[%d]", name, j);
                int location = glGetUniformLocation(programme, long_name.toStringz);
                writefln("  %d) type:%s\tname:%s\tlocation:%d\n",
                        i, GL_type_to_string(type), long_name, location);
            }
        } else {
            int location = glGetUniformLocation(programme, name.toStringz);
            writefln("  %d) type:%s\tname:%s\tlocation:%d",
                    i, GL_type_to_string(type), name, location);
        }
    }
    writeln("--------------------------------------");
}




// Helper function for printing out uniforms and attributes
// Translated From: https://web.archive.org/web/20240823152221/https://antongerdelan.net/opengl/shaders.html
private string GL_type_to_string(GLenum type) {
    switch(type) {
        case GL_BOOL: 				return "bool";
        case GL_INT: 				return "int";
        case GL_FLOAT: 				return "float";
        case GL_FLOAT_VEC2: 		return "vec2";
        case GL_FLOAT_VEC3: 		return "vec3";
        case GL_FLOAT_VEC4: 		return "vec4";
        case GL_FLOAT_MAT2: 		return "mat2";
        case GL_FLOAT_MAT3: 		return "mat3";
        case GL_FLOAT_MAT4: 		return "mat4";
        case GL_SAMPLER_2D: 		return "sampler2D";
        case GL_SAMPLER_3D: 		return "sampler3D";
        case GL_SAMPLER_CUBE: 		return "samplerCube";
        case GL_SAMPLER_2D_SHADOW: 	return "sampler2DShadow";
        default: break;
    }
    return "other";
}
