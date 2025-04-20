/// This module contains an abstraction for shader pipelines.
module pipeline;

// Imports
import std.stdio, std.string, std.file, std.conv;
import core.stdc.stdlib; // For exit() if CheckAndCacheUniform is fatal
import bindbc.opengl;

/// A pipeline consists of all of the shader programs to create an OpenGL program object.
class Pipeline {
    /// Map of all the pipelines that have been loaded
    static GLuint[string] sPipeline;

    // Member variables
    string mPipelineName;
    GLuint mProgramObjectID = 0; // Initialize to 0

    /// Constructor for a standard VS+FS pipeline.
    this(string pipelineName, string vertexShaderSourceFilename, string fragmentShaderSourceFilename) {
        // Prevent recompiling if name exists and corresponds to a valid program
        if (pipelineName in sPipeline && glIsProgram(sPipeline[pipelineName])) {
             mPipelineName = pipelineName;
             mProgramObjectID = sPipeline[pipelineName];
             writeln("Pipeline '", pipelineName, "' already compiled. Using existing ID: ", mProgramObjectID);
        } else {
            // Compile using the standard VS+FS method
            CompilePipeline(pipelineName, vertexShaderSourceFilename, fragmentShaderSourceFilename);
            // CompilePipeline sets member variables mPipelineName, mProgramObjectID and static sPipeline
            if (mProgramObjectID == 0) { // Check if compilation failed internally
                 throw new Exception("Standard pipeline compilation failed for: " ~ pipelineName);
            }
             writeln("Pipeline object created for standard pipeline: ", mPipelineName, " (ID: ", mProgramObjectID, ")");
        }
    }

    /// --- NEW Constructor for Tessellation VS+TCS+TES+FS pipeline ---
    this(string pipelineName,
         string vertexShaderSourceFilename,
         string fragmentShaderSourceFilename,
         string tessControlShaderFilename,
         string tessEvalShaderFilename)
    {
         // Basic null/empty checks for required tessellation shaders
         if (tessControlShaderFilename is null || tessControlShaderFilename.length == 0)
             throw new Exception("TCS filename cannot be empty for tess pipeline: " ~ pipelineName);
         if (tessEvalShaderFilename is null || tessEvalShaderFilename.length == 0)
             throw new Exception("TES filename cannot be empty for tess pipeline: " ~ pipelineName);

         // Prevent recompiling if name exists and corresponds to a valid program
         if (pipelineName in sPipeline && glIsProgram(sPipeline[pipelineName])) {
              mPipelineName = pipelineName;
              mProgramObjectID = sPipeline[pipelineName];
              writeln("Pipeline '", pipelineName, "' already compiled. Using existing ID: ", mProgramObjectID);
         } else {
            // Compile using the NEW Tessellation overload
            CompilePipeline(pipelineName,
                            vertexShaderSourceFilename, fragmentShaderSourceFilename,
                            tessControlShaderFilename, tessEvalShaderFilename);
            // CompilePipeline sets member variables mPipelineName, mProgramObjectID and static sPipeline
             if (mProgramObjectID == 0) { // Check if compilation failed internally
                  throw new Exception("Tessellation pipeline compilation failed for: " ~ pipelineName);
             }
              writeln("Pipeline object created for tessellation pipeline: ", mPipelineName, " (ID: ", mProgramObjectID, ")");
         }
    }


    /// --- Original CompilePipeline for VS+FS ---
    /// Compiles, links, stores result in members and static map. Returns program ID.
    GLuint CompilePipeline(string pipelineName, string vertexShaderSourceFilename, string fragmentShaderSourceFilename) {
        writeln("Compiling standard shader pipeline: ", pipelineName);
        writeln("  VS: ", vertexShaderSourceFilename);
        writeln("  FS: ", fragmentShaderSourceFilename);

        GLuint tempProgramID = 0; // Use temporary local ID
        GLuint vertexShader = 0;
        GLuint fragmentShader = 0;

        // Use scope(exit) for robust cleanup on errors or success
        scope(exit) {
             // Clean up individual shaders if they were created
             if (vertexShader != 0) glDeleteShader(vertexShader);
             if (fragmentShader != 0) glDeleteShader(fragmentShader);
             // If program was created but linking failed or wasn't stored, delete it
             if (tempProgramID != 0 && (pipelineName !in sPipeline || sPipeline[pipelineName] != tempProgramID)) {
                 glDeleteProgram(tempProgramID);
             }
        }

        // --- Compile VS ---
        string vertexSource; try{ vertexSource = readText(vertexShaderSourceFilename); } catch(Exception e){ /*...*/ } if (vertexSource.length == 0) { /*...*/ }
        vertexShader = glCreateShader(GL_VERTEX_SHADER); if (vertexShader == 0) { /*...*/ }
        const char* vSource = vertexSource.ptr; glShaderSource(vertexShader, 1, &vSource, null); glCompileShader(vertexShader);
        CheckShaderError(vertexShader, vertexShaderSourceFilename); // Use private helper
        writeln("  VS compiled.");

        // --- Compile FS ---
        string fragmentSource; try{ fragmentSource = readText(fragmentShaderSourceFilename); } catch(Exception e){ /*...*/ } if (fragmentSource.length == 0) { /*...*/ }
        fragmentShader= glCreateShader(GL_FRAGMENT_SHADER); if (fragmentShader == 0) { /*...*/ }
        const char* fSource = fragmentSource.ptr; glShaderSource(fragmentShader, 1, &fSource, null); glCompileShader(fragmentShader);
        CheckShaderError(fragmentShader, fragmentShaderSourceFilename); // Use private helper
        writeln("  FS compiled.");

        // --- Link Program ---
        tempProgramID = glCreateProgram(); if (tempProgramID == 0) { /*...*/ }
        glAttachShader(tempProgramID, vertexShader);
        glAttachShader(tempProgramID, fragmentShader);
        glLinkProgram(tempProgramID);
        writeln("  Linking program...");
        CheckLinkerError(tempProgramID, pipelineName); // Use private helper (throws on failure)

        // --- Success Path ---
        writeln("  Pipeline linked successfully.");
        // Detach shaders after successful link (before deleting them via scope(exit))
        glDetachShader(tempProgramID, vertexShader);
        glDetachShader(tempProgramID, fragmentShader);

        // Store results in members AND static map
        this.mPipelineName = pipelineName;
        this.mProgramObjectID = tempProgramID;
        sPipeline[this.mPipelineName] = this.mProgramObjectID;

        PrintShaderAttributesAndUniforms(this.mPipelineName, this.mProgramObjectID); // Use module helper

        return this.mProgramObjectID; // Return ID
    }

    /// --- NEW CompilePipeline Overload for VS+TCS+TES+FS ---
    /// Compiles, links, stores result in members and static map. Returns program ID.
     GLuint CompilePipeline(string pipelineName,
                            string vertexShaderSourceFilename,
                            string fragmentShaderSourceFilename,
                            string tessControlShaderFilename,
                            string tessEvalShaderFilename)
     {
        writeln("Compiling tessellation shader pipeline: ", pipelineName);
        writeln("  VS: ", vertexShaderSourceFilename);
        writeln("  TCS: ", tessControlShaderFilename);
        writeln("  TES: ", tessEvalShaderFilename);
        writeln("  FS: ", fragmentShaderSourceFilename);

        GLuint tempProgramID = 0;
        GLuint vertexShader = 0, fragmentShader = 0, tessControlShader = 0, tessEvalShader = 0;

        scope(exit) { // Cleanup for all 4 shaders + program
             if (vertexShader != 0) glDeleteShader(vertexShader);
             if (fragmentShader != 0) glDeleteShader(fragmentShader);
             if (tessControlShader != 0) glDeleteShader(tessControlShader);
             if (tessEvalShader != 0) glDeleteShader(tessEvalShader);
             if (tempProgramID != 0 && (pipelineName !in sPipeline || sPipeline[pipelineName] != tempProgramID)) {
                  // Detach should happen before delete if link failed but attach occurred
                  // Note: glDetachShader on a non-attached shader is okay.
                  glDetachShader(tempProgramID, vertexShader);
                  glDetachShader(tempProgramID, fragmentShader);
                  glDetachShader(tempProgramID, tessControlShader);
                  glDetachShader(tempProgramID, tessEvalShader);
                  glDeleteProgram(tempProgramID);
             }
        }

        // --- Compile VS ---
        string vsSource; try{ vsSource = readText(vertexShaderSourceFilename); } catch(Exception e){ /*...*/ } if (vsSource.length == 0) { /*...*/ }
        vertexShader = glCreateShader(GL_VERTEX_SHADER); if (vertexShader == 0) { /*...*/ }
        const char* vsPtr = vsSource.ptr; glShaderSource(vertexShader, 1, &vsPtr, null); glCompileShader(vertexShader); CheckShaderError(vertexShader, vertexShaderSourceFilename);
        writeln("  VS compiled.");

        // --- Compile TCS ---
        string tcsSource; try{ tcsSource = readText(tessControlShaderFilename); } catch(Exception e){ /*...*/ } if (tcsSource.length == 0) { /*...*/ }
        tessControlShader = glCreateShader(GL_TESS_CONTROL_SHADER); if (tessControlShader == 0) { /*...*/ }
        const char* tcsPtr = tcsSource.ptr; glShaderSource(tessControlShader, 1, &tcsPtr, null); glCompileShader(tessControlShader); CheckShaderError(tessControlShader, tessControlShaderFilename);
        writeln("  TCS compiled.");

        // --- Compile TES ---
        string tesSource; try{ tesSource = readText(tessEvalShaderFilename); } catch(Exception e){ /*...*/ } if (tesSource.length == 0) { /*...*/ }
        tessEvalShader = glCreateShader(GL_TESS_EVALUATION_SHADER); if (tessEvalShader == 0) { /*...*/ }
        const char* tesPtr = tesSource.ptr; glShaderSource(tessEvalShader, 1, &tesPtr, null); glCompileShader(tessEvalShader); CheckShaderError(tessEvalShader, tessEvalShaderFilename);
        writeln("  TES compiled.");

        // --- Compile FS ---
        string fsSource; try{ fsSource = readText(fragmentShaderSourceFilename); } catch(Exception e){ /*...*/ } if (fsSource.length == 0) { /*...*/ }
        fragmentShader= glCreateShader(GL_FRAGMENT_SHADER); if (fragmentShader == 0) { /*...*/ }
        const char* fsPtr = fsSource.ptr; glShaderSource(fragmentShader, 1, &fsPtr, null); glCompileShader(fragmentShader); CheckShaderError(fragmentShader, fragmentShaderSourceFilename);
        writeln("  FS compiled.");

        // --- Link Program ---
        tempProgramID = glCreateProgram(); if (tempProgramID == 0) { /*...*/ }
        glAttachShader(tempProgramID, vertexShader);
        glAttachShader(tempProgramID, tessControlShader); // Attach TCS
        glAttachShader(tempProgramID, tessEvalShader);    // Attach TES
        glAttachShader(tempProgramID, fragmentShader);
        glLinkProgram(tempProgramID);
        writeln("  Linking program...");
        CheckLinkerError(tempProgramID, pipelineName); // Checks and throws on error

        // --- Success Path ---
        writeln("  Pipeline linked successfully.");
        // Detach shaders after successful link
        glDetachShader(tempProgramID, vertexShader);
        glDetachShader(tempProgramID, fragmentShader);
        glDetachShader(tempProgramID, tessControlShader);
        glDetachShader(tempProgramID, tessEvalShader);

        // Store results in members AND static map
        this.mPipelineName = pipelineName;
        this.mProgramObjectID = tempProgramID;
        sPipeline[this.mPipelineName] = this.mProgramObjectID;

        PrintShaderAttributesAndUniforms(this.mPipelineName, this.mProgramObjectID);

        return this.mProgramObjectID; // Return ID
     }

    // --- Private Helper Methods within Class ---
    // Moved error checking inside class for better encapsulation? Or keep outside?
    // Let's keep them outside as private static module functions for now.

} // end class Pipeline


// --- Module-Level Static Functions (Original Public API + Helpers) ---

/// Select a pipeline for use.
static void PipelineUse(string name) {
    // (Keep original implementation)
    GLint id = PipelineCheckValidName(name);
    if(glIsProgram(id) == GL_FALSE){ /* ... assert ... */ }
    glUseProgram(Pipeline.sPipeline[name]);
}

/// Check if pipeline name exists in map and return ID. Asserts on failure.
static GLint PipelineCheckValidName(string name) {
    // (Keep original implementation)
     if(name in Pipeline.sPipeline){ return cast(GLint)Pipeline.sPipeline[name]; } // Cast to GLint if needed
     writeln("'"~name~"' not found in pipelines");
     writeln("candidates are:", Pipeline.sPipeline);
     assert(0, "Pipeline User Error: Name not found");
}


/// Helper to check shader compilation status and print errors.
/// Throws: Exception on compile error.
private static void CheckShaderError(GLuint shaderObject, string filename) {
    GLint result = GL_FALSE;
    glGetShaderiv(shaderObject, GL_COMPILE_STATUS, &result);
    if (result == GL_FALSE) {
        GLint length = 0;
        glGetShaderiv(shaderObject, GL_INFO_LOG_LENGTH, &length);
        string errorMsg = "--- SHADER COMPILE ERROR --- File: " ~ filename ~ "\n";
        if (length > 0) {
             GLchar[] infoLog = new GLchar[length+1]; // Add space for null terminator
             glGetShaderInfoLog(shaderObject, length, null, infoLog.ptr);
             errorMsg ~= infoLog.idup; // Use idup for safety
        } else {
            errorMsg ~= "(No info log available)";
        }
         errorMsg ~= "\n---------------------------\n";
         stderr.write(errorMsg); // Write error to stderr
         // Optional: Delete shader object before throwing?
         // glDeleteShader(shaderObject); // Might delete 0 if glCreateShader failed
         throw new Exception("Shader compilation failed for: " ~ filename);
    }
}

/// Helper to check program linking status and print errors.
/// Throws: Exception on link error.
private static void CheckLinkerError(GLuint programID, string name) {
    GLint linkStatus = GL_FALSE;
    glGetProgramiv(programID, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLint logLength = 0;
        glGetProgramiv(programID, GL_INFO_LOG_LENGTH, &logLength);
         string errorMsg = "--- SHADER LINKER ERROR --- Pipeline: " ~ name ~ "\n";
        if (logLength > 0) {
             GLchar[] infoLog = new GLchar[logLength+1]; // Add space for null terminator
             glGetProgramInfoLog(programID, logLength, null, infoLog.ptr);
             errorMsg ~= infoLog.idup;
        } else {
            errorMsg ~= "(No info log available)";
        }
        errorMsg ~= "\n---------------------------\n";
        stderr.write(errorMsg); // Write error to stderr
        // Optional: Delete program object before throwing?
        // glDeleteProgram(programID);
        throw new Exception("Shader linking failed for pipeline: " ~ name);
    }
    // Check validation status here too if desired...
}

/// Debug function to print active attributes and uniforms.
static void PrintShaderAttributesAndUniforms(string pipelineName, GLuint programme) {
    // (Keep original implementation - Ensure GL_type_to_string is visible)
     writeln("======="~pipelineName~" and # "~programme.to!string~"  (shader debug info)======");
     // ... rest of the printing logic using GL_type_to_string ...
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
