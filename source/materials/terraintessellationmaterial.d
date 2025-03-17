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

        writefln("TerrainTessellationMaterial: created pipeline 'terrainTessellation'");

        // Initialize the base material with our new pipeline name.
        super("terrainTessellation");

        writeln ("TerrainTessellationMaterial: initialized base material");

        // Add transformation uniforms first (in the order expected by your shader).
        // AddUniform(new Uniform("uModel", "mat4", null));

        writeln ("TerrainTessellationMaterial: added transformation uniforms");

        AddUniform(new Uniform("uProjection", "mat4", null));
        AddUniform(new Uniform("uView", "mat4", null));
        // Then add tessellation-specific uniforms.
        AddUniform(new Uniform("uTessInner", tessInner));
        AddUniform(new Uniform("uTessOuter", tessOuter));


        writeln ("TerrainTessellationMaterial: added uniforms");
    }

    override void Update() {
        // Activate the tessellation pipeline.
        PipelineUse(mPipelineName);

        // Update tessellation level uniforms.
        mUniformMap["uTessInner"].Set(tessInner);
        mUniformMap["uTessOuter"].Set(tessOuter);

        // Transformation uniforms should be updated externally (e.g. by your scene or camera code)
        // or you can update them here if you have the pointers.
    }
}
