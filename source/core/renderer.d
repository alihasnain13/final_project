module renderer;

import bindbc.sdl;
import bindbc.opengl;

import camera, scene, mesh;
import std.stdio;
import std.algorithm;

// Helper function to recursively update transformation uniforms in each MeshNode.
void updateTransformationUniforms(ISceneNode node, Camera cam)
{
    auto mnode = cast(MeshNode)node;
    if(mnode !is null)
    {
        if("uView" in mnode.mMaterial.mUniformMap)
            mnode.mMaterial.mUniformMap["uView"].Set(cam.mViewMatrix.DataPtr());
        if("uProjection" in mnode.mMaterial.mUniformMap)
            mnode.mMaterial.mUniformMap["uProjection"].Set(cam.mProjectionMatrix.DataPtr());
        if("uModel" in mnode.mMaterial.mUniformMap)
            mnode.mMaterial.mUniformMap["uModel"].Set(mnode.mModelMatrix.DataPtr());
    }
    foreach(child; node.mChildren)
        updateTransformationUniforms(child, cam);
}


class Renderer {
    SDL_Window* mWindow;
    int mScreenWidth;
    int mScreenHeight;

    /// Constructor
    this(SDL_Window* window, int width, int height){
        mWindow = window;
        mScreenWidth = width;
        mScreenHeight = height;
    }

    /// Sets state at the start of a frame
    void StartingFrame(){
        glViewport(0, 0, mScreenWidth, mScreenHeight);
        glClearColor(0.0f, 0.6f, 0.8f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
    }

    /// Set or clear any state at end of a frame
    void EndingFrame(){
        SDL_GL_SwapWindow(mWindow);
    }

    /// Encapsulation of the rendering process of a scene tree with a camera.
    /// This version updates transformation uniforms externally.
    void Render(SceneTree s, Camera cam){
        // Set initial frame state.
        StartingFrame();

        // Set the camera in the scene tree.
        s.SetCamera(cam);

        // Update transformation uniforms for all MeshNodes in the scene.
        updateTransformationUniforms(s.GetRootNode(), cam);

        // Now traverse the scene tree to update each node (which will transfer uniforms and render geometry).
        s.StartTraversal();

        EndingFrame();
    }
}
