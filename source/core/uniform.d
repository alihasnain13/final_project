module uniform;

import std.stdio, std.string;
import core.stdc.stdlib;

import linear;
import pipeline;
import bindbc.opengl;

/// This is a specific type to help with uniform management
/// The idea is that we can 'attach' uniforms to materials (or other data types)
/// and have them automatically update as needed
class Uniform{
    GLint mPipelineId;			// What graphics pipeline the uniform is part of
													  // This is assigned when a uniform is added to a material automatically.
    string mUniformName;		// The name of the uniform
    string     mDataType;		// A string representing the data type
    void*      mData;				// A pointer to the actual data that we will cast to
														// the appropriate value.
		double		 mPlainDataType;	// Equivalent to 'mData' but for primitive types.
																// I did this to make things a little easier.

		// We cache the value of the uniform location to otherwise make it faster to lookup.
    GLint mCachedUniformLocation;

    /// Add a new uniform with a specific type
    this(string uniformname, string datatype, void* data)
		{
			if(datatype=="vec2" || datatype=="vec3" || datatype=="mat4"){
        mUniformName    = uniformname;
        mDataType       = datatype;
        mData           = data;
			}else{
				assert(0,"unsupported uniform vector/matrix type");
			}
    }

		/// Add a new uniform with a specific type
		this(string uniformname, int data){
				mUniformName    = uniformname;
				mDataType       = "int";
				mPlainDataType  = data;
		}
    /// Add a new uniform with a specific type
    this(string uniformname, float data){
        mUniformName    = uniformname;
        mDataType       = "float";
        mPlainDataType  = data;
    }

    /// Set data for an already created uniform.
    void Set(void* data){
        mData           = data;
    }
    /// Set data for an already created uniform.
    void Set(int data){
        mPlainDataType  = data;
    }
    /// Set data for an already created uniform.
    void Set(float data){
        mPlainDataType  = data;
    }

    /// Transfer from CPU to GPU to the active GPU program uniforms
    void Transfer(){
        if(mDataType=="int"){
            glUniform1i(mCachedUniformLocation,cast(int)mPlainDataType);        
        }else if(mDataType=="float"){
            glUniform1f(mCachedUniformLocation,cast(float)mPlainDataType);        
        }else if(mDataType=="vec2"){
            vec2* v = cast(vec2*)mData;
            glUniform2f(mCachedUniformLocation,v.data[0],v.data[1]);
        }else if(mDataType=="vec3"){
            vec3* v = cast(vec3*)mData;
            glUniform3f(mCachedUniformLocation,v.data[0],v.data[1],v.data[2]);
        }else if(mDataType=="mat4"){
            mat4* m = cast(mat4*)mData;
            glUniformMatrix4fv(mCachedUniformLocation, 1, GL_TRUE, m.DataPtr());
        }else{
            assert(0,"unsupported type, perhaps add more types in 'Transfer'?");
        }
    }


    /// Check that the uniform name is found within the currently active shader.
    /// Will return the 'location' value otherwise
    /// NOTE: In theory, you should never have to spend computation in
    ///       a professional game software querying for the
    ///       uniform locations in a 'release' version of your software.
    ///       It should be possible to parse the shader code and
    ///       then you could hardcode the locations prior for shaders.
    GLint CheckAndCacheUniform(string pipelineName, string uniformName){

        // Validate the location
        mCachedUniformLocation = glGetUniformLocation(mPipelineId,uniformName.toStringz);

        // Provide some output if the uniform is not found
        if(mCachedUniformLocation == -1){
            writeln("=========================================");
            writeln("Error, could not find symbol: '"~uniformName~"'\n");
            GLint program;
            glGetIntegerv(GL_CURRENT_PROGRAM,&program);

            writeln("This program is: ",mPipelineId);
            PrintShaderAttributesAndUniforms(pipelineName,mPipelineId);
            if(program != mPipelineId){
                writeln("-----------------------------------------");
                writeln("Active program is: ",program);
                PrintShaderAttributesAndUniforms("unknown",program);
                writeln("=========================================");
            }
            exit(EXIT_FAILURE);
        }
        return mCachedUniformLocation;
    }

    /*
    /// Usage: SetUniform1f(string name, value);
    mixin SetUniform!("f",GLfloat);					
    /// Usage: SetUniform1i(string name, value);
    mixin SetUniform!("i",GLint);						
    /// Usage: SetUniform1ui(string name, value);
    mixin SetUniform!("ui",GLuint);			 
    /// Usage: SetUniform1fv(string name, value);
    mixin SetUniformVector!("1fv",GLfloat); 
    /// Usage: SetUniform2fv(string name, size_t count, value);
    mixin SetUniformVector!("2fv",GLfloat);
    ///
    mixin SetUniformVector!("3fv",GLfloat);
    ///
    mixin SetUniformVector!("4fv",GLfloat);
    ///
    mixin SetUniformVector!("1iv",GLint);
    ///
    mixin SetUniformVector!("2iv",GLint);
    ///
    mixin SetUniformVector!("3iv",GLint);
    ///
    mixin SetUniformVector!("4iv",GLint);
    ///
    mixin SetUniformVector!("1uiv",GLuint);
    ///
    mixin SetUniformVector!("2uiv",GLuint);
    ///
    mixin SetUniformVector!("3uiv",GLuint);
    ///
    mixin SetUniformVector!("4uiv",GLuint);
    /// Usage: SetUniformMatrix2fv(count,transpose,value);
    mixin SetUniformMatrix!"2fv"; 					
    mixin SetUniformMatrix!"3fv"; 	
    mixin SetUniformMatrix!"4fv"; 	
    mixin SetUniformMatrix!"2x3fv"; 
    mixin SetUniformMatrix!"3x2fv"; 
    mixin SetUniformMatrix!"2x4fv"; 
    mixin SetUniformMatrix!"4x2fv"; 
    mixin SetUniformMatrix!"3x4fv"; 
    mixin SetUniformMatrix!"4x3fv"; 
    */
}

/*
template SetUniform(string suffix, T){
    mixin("	
            void SetUniform1"~suffix~"(string name,T v0)
            {
            GLint location = CheckUniform(name);
            glUniform1"~suffix~"(location,v0);	
            }
            void SetUniform2"~suffix~"(string name,T v0,T v1)
            {
            GLint location = CheckUniform(name);
            glUniform2"~suffix~"(location,v0,v1);	
            }
            void SetUniform3"~suffix~"(string name,T v0, T v1, T v2)
            {
            GLint location = CheckUniform(name);
            glUniform3"~suffix~"(location,v0,v1,v2);	
            }
            void SetUniform4"~suffix~"(string name,T v0, T v1, T v2, T v3)
            {
            GLint location = CheckUniform(name);
            glUniform4"~suffix~"(location,v0,v1,v2,v3);	
            }
            ");
}

template SetUniformVector(string suffix, T){
    mixin("	
            void SetUniformVector"~suffix~"(string name,GLsizei count, const T* value)
            {
            GLint location = CheckUniform(name);
            glUniform"~suffix~"(location,count,value);
            }
            ");
}

template SetUniformMatrix(string suffix){
    mixin("	
            void SetUniformMatrix"~suffix~"(string name,GLsizei count, GLboolean transpose, const GLfloat* value)
            {
            GLint location = CheckUniform(name);
            glUniformMatrix"~suffix~"(location,count,transpose,value);
            }
            ");
}
*/
