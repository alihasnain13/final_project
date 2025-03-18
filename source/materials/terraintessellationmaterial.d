module terraintessellationmaterial;

import pipeline;
import material;        
import uniform;
import bindbc.opengl;
import std.stdio;

/// A material for terrain tessellation that uses a tessellation-enabled pipeline.
class TerrainTessellationMaterial : IMaterial {
    // Tessellation level parameters.
    float tessInner = 4.0f;
    float tessOuter = 4.0f;

    this() {
        // Create the tessellation-enabled pipeline instance.
        new Pipeline("terrainTessellation",
            "./pipelines/tessellation/terrain.vert",
            "./pipelines/tessellation/tess_control.glsl",
            "./pipelines/tessellation/tess_eval.glsl",
            "./pipelines/tessellation/terrain.frag");

        writeln("TerrainTessellationMaterial: created pipeline 'terrainTessellation'");

        // Initialize the base material with our new pipeline name.
        super("terrainTessellation");
        writeln("TerrainTessellationMaterial: initialized base material");

        auto tessID = Pipeline.sPipeline["terrainTessellation"];
        writeln("Tessellation pipeline ID: ", tessID);

        foreach (key, value; Pipeline.sPipeline) {
            writeln(key, " -> ", value);
        }


        // Activate the tessellation pipeline to ensure uniform locations are available.
        PipelineUse(mPipelineName);
        {
            GLint prog;
            glGetIntegerv(GL_CURRENT_PROGRAM, &prog);
            writeln("Active program before adding uniforms: ", prog);
        }

        // Add transformation uniforms.
        AddUniform(new Uniform("uProjection", "mat4", null));
        AddUniform(new Uniform("uView", "mat4", null));
        // Then add tessellation-specific uniforms.
        AddUniform(new Uniform("uTessInner", tessInner));
        AddUniform(new Uniform("uTessOuter", tessOuter));

        writeln("TerrainTessellationMaterial: added uniforms");
    }

    override void Update() {
        // Activate the tessellation pipeline.
        PipelineUse(mPipelineName);

        // Update tessellation level uniforms.
        mUniformMap["uTessInner"].Set(tessInner);
        mUniformMap["uTessOuter"].Set(tessOuter);
        // Transformation uniforms should be updated externally (by the renderer)
        // or here if you have valid pointers.
    }
}
