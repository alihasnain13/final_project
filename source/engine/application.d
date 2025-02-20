module engine.application;

import std.stdio;
import std.string : toStringz, fromStringz;
import std.math : sin, cos;

// Import our custom abstraction modules.
import abstractions.sdl_abstraction;
import abstractions.opengl_abstraction;

alias GLint = int;
alias GLuint = uint;

// Import needed SDL symbols.
import bindbc.sdl : SDL_GL_SetAttribute,
                     SDL_CreateWindow,
                     SDL_GL_CreateContext,
                     SDL_GL_MakeCurrent,
                     SDL_GL_DeleteContext,
                     SDL_DestroyWindow,
                     SDL_PollEvent,
                     SDL_Quit,
                     SDL_GetError,
                     SDL_GL_SwapWindow,
                     SDL_Window,
                     SDL_WindowFlags,
                     SDL_WINDOW_OPENGL,
                     SDL_WINDOWPOS_UNDEFINED,
                     SDL_WINDOW_SHOWN,
                     SDL_Event,
                     SDL_SCANCODE_ESCAPE,
                     SDL_SCANCODE_W,
                     SDL_SCANCODE_S,
                     SDL_SCANCODE_A,
                     SDL_SCANCODE_D,
                     SDL_SCANCODE_Q,
                     SDL_SCANCODE_E,
                     SDL_QUIT,
                     SDL_GLContext,
                     SDL_GLattr,
                     SDL_GLprofile;

// Import our own modules.
import io.objparser;         // Provides LoadOBJFile() for OBJ parsing.
import engine.camera;        // Defines: struct Camera { Vec3 position; float yaw; float pitch; }
import engine.math;          // Defines: Vec3, Mat4, perspective(), lookAt(), Mat4.identity(), etc.
// Update the shader import to bring in buildShaderProg.
import rendering.shader : buildShaderProg;
import rendering.mesh : MakeQuadFactory, Mesh;  // Mesh type and quad factory function.

/// GraphicsApp sets up SDL/OpenGL, loads a shader expecting a "uMVP" uniform,
/// creates a test mesh (or loads an OBJ model), and integrates a basic free‑fly camera.
class GraphicsApp
{
    private bool mGameIsRunning = true;
    private SDL_GLContext mContext;
    private SDL_Window* mWindow;

    // Meshes (Mesh type defined in rendering.mesh)
    private Mesh mQuadMesh;
    private Mesh mCustomMesh;
    private Mesh mActiveMesh; // Either quad or custom model

    // Camera and transformation matrices.
    private Camera mCamera;
    private Mat4 mProjection; // Projection matrix.
    private Mat4 mModel;      // Model transform (identity for now).
    private GLint mMVPUniformLocation = -1; // Location of "uMVP" uniform.

    // Shader pipeline.
    private GLuint mBasicGraphicsPipeline;

    // Screen dimensions.
    private int mScreenWidth = 640;
    private int mScreenHeight = 480;

    // Path to custom model (OBJ file).
    private string mModelPath;

    /// Constructor: initialize SDL/OpenGL, set camera defaults, and create context.
    this(int width, int height, string[] args) {
        mScreenWidth = width;
        mScreenHeight = height;

        // Set SDL OpenGL attributes.
        SDL_GL_SetAttribute(SDL_GLattr.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        SDL_GL_SetAttribute(SDL_GLattr.SDL_GL_CONTEXT_MINOR_VERSION, 1);
        SDL_GL_SetAttribute(SDL_GLattr.SDL_GL_CONTEXT_PROFILE_MASK, SDL_GLprofile.SDL_GL_CONTEXT_PROFILE_CORE);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

        // Create an SDL window.
        mWindow = SDL_CreateWindow("dlang - OpenGL with Camera".toStringz,
                                     SDL_WINDOWPOS_UNDEFINED,
                                     SDL_WINDOWPOS_UNDEFINED,
                                     mScreenWidth,
                                     mScreenHeight,
                                     SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);
        if(mWindow is null) {
            writeln("Failed to create SDL window: ", fromStringz(SDL_GetError()));
            mGameIsRunning = false;
            return;
        }

        // Create the OpenGL context.
        mContext = SDL_GL_CreateContext(mWindow);
        if(mContext is null) {
            writeln("Failed to create GL context: ", fromStringz(SDL_GetError()));
            mGameIsRunning = false;
            return;
        }
        SDL_GL_MakeCurrent(mWindow, mContext);

        // Load OpenGL function pointers using our abstraction.
        if(LoadOpenGLLib() != 0) {
            writeln("Failed to load OpenGL functions.");
            mGameIsRunning = false;
            return;
        }
        GetOpenGLVersionInfo();

        // Set default camera values.
        mCamera.position = Vec3(0, 0, 3);  // Start 3 units back.
        mCamera.yaw = 0;
        mCamera.pitch = 0;

        // Setup projection matrix: 60° FOV, proper aspect ratio, near=0.1, far=100.
        mProjection = perspective(60.0f, cast(float)mScreenWidth/mScreenHeight, 0.1f, 100.0f);

        // Model transform is identity.
        mModel = Mat4.identity();

        // Set model path from command-line arguments, or use default.
        if(args.length > 1) {
            mModelPath = args[1];
            writeln("Model path from command line: ", mModelPath);
        } else {
            mModelPath = "./assets/bunny_centered.obj";
            writeln("No model path specified, using default: ", mModelPath);
        }
    }

    ~this() {
        SDL_GL_DeleteContext(mContext);
        SDL_DestroyWindow(mWindow);
        SDL_Quit();
    }

    /// Main loop.
    void run() {
        SetupScene();
        while(mGameIsRunning) {
            Input();
            Update();
            Render();
        }
    }

    /// Process input: move the camera using WASD for horizontal movement and Q/E for vertical movement.
    void Input() {
        SDL_Event event;
        while(SDL_PollEvent(&event) != 0) {
            if(event.type == SDL_QUIT) {
                mGameIsRunning = false;
            }
            if(event.type == SDL_KEYDOWN) {
                auto sc = event.key.keysym.scancode;
                if(sc == SDL_SCANCODE_ESCAPE)
                    mGameIsRunning = false;
                else if(sc == SDL_SCANCODE_W)
                    mCamera.position.z -= 0.1f; // move forward
                else if(sc == SDL_SCANCODE_S)
                    mCamera.position.z += 0.1f; // move backward
                else if(sc == SDL_SCANCODE_A)
                    mCamera.position.x -= 0.1f; // strafe left
                else if(sc == SDL_SCANCODE_D)
                    mCamera.position.x += 0.1f; // strafe right
                else if(sc == SDL_SCANCODE_Q)
                    mCamera.position.y -= 0.1f; // move down
                else if(sc == SDL_SCANCODE_E)
                    mCamera.position.y += 0.1f; // move up
            }
        }
    }

    /// Update: compute view matrix from camera and send the MVP (projection * view * model) to the shader.
    void Update() {
        // Compute forward vector from camera's yaw and pitch.
        float forwardX = cos(mCamera.pitch) * sin(mCamera.yaw);
        float forwardY = sin(mCamera.pitch);
        float forwardZ = cos(mCamera.pitch) * cos(mCamera.yaw);
        Vec3 forward = Vec3(forwardX, forwardY, forwardZ);
        // Compute view matrix using lookAt: camera.position and (camera.position + forward)
        Mat4 view = lookAt(mCamera.position, mCamera.position + forward, Vec3(0, 1, 0));

        // Compute MVP: projection * view * model.
        Mat4 mvp = mProjection * view * mModel;
        glUseProgram(mBasicGraphicsPipeline);
        glUniformMatrix4fv(mMVPUniformLocation, 1, GL_FALSE, mvp.m.ptr);
    }

    /// Render the scene.
    void Render() {
        glViewport(0, 0, mScreenWidth, mScreenHeight);
        glClearColor(0.0f, 0.6f, 0.8f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);

        glUseProgram(mBasicGraphicsPipeline);
        glBindVertexArray(mActiveMesh.VAO);
        if(mActiveMesh.EBO != 0)
            glDrawElements(GL_TRIANGLES, cast(int)mActiveMesh.count, GL_UNSIGNED_INT, null);
        else
            glDrawArrays(GL_TRIANGLES, 0, cast(int)mActiveMesh.count);

        SDL_GL_SwapWindow(mWindow);
    }

    /// Setup the scene: load shader and meshes.
    void SetupScene() {
        // Build a basic shader that expects a "uMVP" uniform.
        mBasicGraphicsPipeline = buildShaderProg("./pipelines/basic/basic.vert", "./pipelines/basic/basic.frag");
        mMVPUniformLocation = glGetUniformLocation(mBasicGraphicsPipeline, "uMVP".toStringz);
        if(mMVPUniformLocation == -1)
            writeln("Warning: uniform 'uMVP' not found in shader!");

        // Build a test quad and load a custom OBJ model.
        mQuadMesh = MakeQuadFactory();
        mCustomMesh = LoadOBJFile(mModelPath);
        mActiveMesh = mQuadMesh; // Start with the quad.
    }
}
