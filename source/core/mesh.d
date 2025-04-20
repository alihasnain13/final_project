/// This file represents a mesh abstraction.
module mesh;

// D Standard Libs
import std.stdio;
import core.runtime; // For typeid used in logging

// Project Libs
import linear;    // mat4, DataPtr(), MatrixMakeIdentity()
import materials; // IMaterial interface
import scene;     // ISceneNode base class
import geometry;  // ISurface interface
import uniform;   // Uniform class (used in Update)

// OpenGL Bindings (May not be directly needed if Uniform/Surface handle GL calls)
// import bindbc.opengl;

/// A MeshNode represents a renderable entity in the scene graph.
/// It holds geometry data (ISurface) and appearance information (IMaterial),
/// along with its own transformation (mModelMatrix inherited from ISceneNode).
class MeshNode : ISceneNode {
    // Use ISurface type, rename member for clarity
    ISurface mSurface;  // The geometry (vertices, indices, VAO)
    IMaterial mMaterial; // The shader, textures, and uniforms

    /// Constructor
    this(string name, ISurface surface, IMaterial material) {
        mNodeName = name;
        this.mSurface = surface;   // Assign injected surface
        this.mMaterial = material; // Assign injected material
        // Initialize model matrix (from ISceneNode) to identity
        this.mModelMatrix = MatrixMakeIdentity();
    }

    /// Update method called during scene traversal.
    /// Prepares material state and issues the draw call for this node's geometry.
    override void Update() {
        // --- Pre-Render Checks ---
        // Ensure we have valid material and surface before proceeding
        if (mMaterial is null) {
             // Logging this can be useful during debugging
             // writeln("Warning: MeshNode '", mNodeName, "' has null material in Update(). Skipping render.");
             return; // Cannot render without a material
        }
        if (mSurface is null) {
             // writeln("Warning: MeshNode '", mNodeName, "' has null surface in Update(). Skipping render.");
             return; // Cannot render without a surface
        }

        // --- 1. Update Material State ---
        // This typically involves:
        // - Calling PipelineUse(mMaterial.mPipelineName)
        // - Binding textures (glActiveTexture/glBindTexture)
        // - Setting sampler uniforms (glUniform1i via Uniform.Set(int))
        mMaterial.Update();

        // --- 2. Update and Transfer Uniforms ---
        // Iterate through all uniforms associated with the current material
        foreach (uniformName, u; mMaterial.mUniformMap) {
             // Special Handling for Model Matrix:
             // Ensure the uniform uses the *current* model matrix of this node.
             // We assume the 'uModel' Uniform was added with a pointer that
             // might become outdated OR was added with null. It's safest
             // to update its internal data pointer here IF Uniform supports it,
             // OR rely on Transfer reading from the correct place.
             // If Transfer reads from u.mData for mat4, update mData:
             if (uniformName == "uModel") {
                 u.Set(mModelMatrix.DataPtr()); // Update pointer via Set(void*)
             }
             // For other pointer-based uniforms (like View, Projection, ViewPos),
             // they usually point to Camera members which are updated elsewhere.
             // If camera matrices change address, they'd need updating too.

             // Transfer the current uniform data (from mData or mPlainDataType) to the GPU
             // Transfer() should handle skipping sampler2D types internally now.
             u.Transfer();
        }

        // --- 3. Render Geometry ---
        // Calls the Render method on the currently assigned surface.
        // This binds the VAO and calls glDrawElements with the correct mode
        // (GL_TRIANGLES or GL_PATCHES, handled internally by SurfaceTerrain).
        mSurface.Render();
    }

    /// Return the material associated with the mesh
    IMaterial GetMaterial() {
        return mMaterial;
    }

    /// Return the geometry surface associated with the mesh
    ISurface GetSurface() {
        return mSurface;
    }

    // *** ADDED SetSurface method for switching ***
    /// Assigns a new geometry surface to this node. Used for switching render modes.
    void SetSurface(ISurface surface) {
         if (surface is null) {
             writeln("Warning: Attempted to set null surface on MeshNode '", mNodeName, "'");
             // Consider throwing an exception if this is an invalid state
             return;
         }
         // Log the type change for debugging
         writeln("MeshNode '", mNodeName, "': Setting Surface (Type: ", typeid(surface).toString, ")");
         this.mSurface = surface; // Update the member variable
    }

    // *** ADDED SetMaterial method for switching ***
    /// Assigns a new material (pipeline, uniforms, textures) to this node. Used for switching render modes.
    void SetMaterial(IMaterial material) {
         if (material is null) {
             writeln("Warning: Attempted to set null material on MeshNode '", mNodeName, "'");
             // Consider throwing an exception if this is an invalid state
             return;
         }
         // Log the type change for debugging
         writeln("MeshNode '", mNodeName, "': Setting Material (Type: ", typeid(material).toString, ")");
         this.mMaterial = material; // Update the member variable
    }
}