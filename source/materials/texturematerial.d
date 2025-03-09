// An example of a texture material
module texturematerial;

import pipeline, materials, texture;
import bindbc.opengl;

/// Represents a simple material 
class TextureMaterial : IMaterial{
		Texture mTexture1;

    /// Construct a new material for a pipeline, and load a texture for that pipeline
    this(string pipelineName, string textureFileName){
				/// delegate to the base constructor to do initialization
				super(pipelineName);

				mTexture1 = new Texture(textureFileName,256,256);
    }

    /// TextureMaterial.Update()
    override void Update(){
        // Set our active Shader graphics pipeline 
        PipelineUse(mPipelineName);

				// Set any uniforms for our mesh if they exist in the shader
				if("sampler1" in mUniformMap){
						glActiveTexture(GL_TEXTURE0);
						glBindTexture(GL_TEXTURE_2D,mTexture1.mTextureID);
        		mUniformMap["sampler1"].Set(0);
				}
    }
}



