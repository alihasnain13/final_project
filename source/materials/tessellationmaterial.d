/// Material definition for Tessellated Terrain rendering using VS+TCS+TES+FS pipeline
module tessellationmaterial;

// Project Dependencies
import materials; // Base IMaterial interface
import texture;   // Texture class
import pipeline;  // PipelineUse function
import uniform;   // Uniform class
import bindbc.opengl;

// D Standard Libs
import std.stdio;
import std.exception;
import std.conv : to; // For error message formatting

/// Material designed for the tessellation pipeline.
/// Manages 4 surface color textures and binds a separate heightmap texture.
/// Sets sampler uniforms for all 5 textures in Update().
/// Assumes uniforms like uYScale, uYShift, MVP, Lighting are added externally
/// in graphics_app.d and handled by Uniform.Transfer().
class TessellationMaterial : IMaterial {
    // Surface Color Textures
    Texture mTexture1; // Dirt
    Texture mTexture2; // Grass
    Texture mTexture3; // Rock
    Texture mTexture4; // Snow

    // Heightmap Texture (Reference to a pre-loaded texture object)
    Texture mHeightMapTexture; // Does NOT own this texture

    /// Constructor
    /// Params:
    ///   pipelineName = Name of the VS+TCS+TES+FS pipeline (e.g., "tess_terrain")
    ///   texFile1..4 = Filenames for the surface textures (e.g., "dirt.ppm")
    ///   heightMapTex = The PRE-LOADED Texture object for the heightmap. Cannot be null.
    this(string pipelineName,
         string texFile1, string texFile2, string texFile3, string texFile4,
         Texture heightMapTex) // Takes pre-loaded heightmap Texture
    {
        super(pipelineName); // Initialize base IMaterial

        if (heightMapTex is null || heightMapTex.mTextureID == 0) {
             throw new Exception("TessellationMaterial requires a valid, pre-loaded heightmap Texture object.");
        }
        // Store the reference to the shared heightmap texture
        this.mHeightMapTexture = heightMapTex;

        // Load surface textures (using constructor that takes filename only)
        try {
            mTexture1 = new Texture(texFile1);
            mTexture2 = new Texture(texFile2);
            mTexture3 = new Texture(texFile3);
            mTexture4 = new Texture(texFile4);
        } catch (Exception e) {
            // Consider cleanup of partially loaded textures
            throw new Exception("TessellationMaterial failed to load surface textures: " ~ e.msg);
        }
         writeln("TessellationMaterial created for pipeline '", pipelineName, "'");
    }

    /// Destructor (Optional)
    ~this() {
         writeln("Destroying TessellationMaterial");
         // Owns mTexture1-4, relies on their destructors.
         // Does not own mHeightMapTexture.
    }

    /// Update method: Sets pipeline, binds textures, sets sampler uniforms.
    override void Update() {
        // 1. Activate the tessellation shader pipeline
        PipelineUse(mPipelineName);

        // Helper to bind texture and set sampler uniform via Uniform.Set(int)
        void bindSampler(string uniformName, uint texUnit, Texture tex) {
            // Check if the uniform was actually added in SetupScene
            if (uniformName in mUniformMap) {
                GLuint idToBind = (tex ? tex.mTextureID : 0);
                glActiveTexture(GL_TEXTURE0 + texUnit);
                glBindTexture(GL_TEXTURE_2D, idToBind);
                // Set sampler uniform to use the correct texture unit index
                mUniformMap[uniformName].Set(cast(int)texUnit);
            } else {
                 // This might happen if SetupScene doesn't add all expected uniforms
                 // writeln("Warning: Sampler uniform '", uniformName, "' not found in material map for pipeline '", mPipelineName, "'");
            }
        }

        // 2. Bind Surface Textures (Units 0-3) and set samplers
        bindSampler("sampler1",   0, mTexture1);
        bindSampler("sampler2",   1, mTexture2);
        bindSampler("sampler3",   2, mTexture3);
        bindSampler("sampler4",   3, mTexture4);

        // 3. Bind Heightmap Texture (Unit 4) and set sampler
        bindSampler("uHeightMap", 4, mHeightMapTexture); // Assuming unit 4 is unused

        if (mHeightMapTexture !is null && mHeightMapTexture.mTextureID != 0) {
            // Use NEAREST neighbor (point sampling), disables mipmaps implicitly for min filter
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            // writeln("DEBUG: Set heightmap filtering to NEAREST"); // Optional log
        }

        // Ensure unit 0 is active again afterwards (good practice)
        glActiveTexture(GL_TEXTURE0);

        // NOTE: Setting other uniforms like uYScale, uYShift, MVP, Lighting
        // is assumed to be handled by the Renderer calling Uniform.Transfer()
        // on uniforms added with pointers in graphics_app.d.
    }
}