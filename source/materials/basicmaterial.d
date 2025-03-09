/// An example of a basic material
/// 
/// Consider this a 'template' 
module basicmaterial;

import pipeline, materials;
import bindbc.opengl;

/// Represents a simple material
class BasicMaterial : IMaterial{
    /// Construct a new material 
    this(string pipelineName){
				/// delegate to the base constructor to do initialization
				super(pipelineName);

				/// Any additional code for setup after
    }
    /// BasicMaterial Update
    override void Update(){
        // Set our active Shader graphics pipeline 
        PipelineUse(mPipelineName);
    }
}
