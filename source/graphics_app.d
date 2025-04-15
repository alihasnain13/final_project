/// The main graphics application with the main graphics loop.
module graphics_app;
import std.stdio;
import core;
import mesh, linear, scene, materials, geometry;
import platform;

import bindbc.sdl;
import bindbc.opengl;
import std.math;

// Import your light marker (cube) surface.

struct GraphicsApp {
    bool mGameIsRunning = true;
    bool mRenderWireframe = false;
    SDL_GLContext mContext;
    SDL_Window* mWindow;

    // Scene, Camera, and Renderer.
    SceneTree mSceneTree;
    Camera mCamera;
    Renderer mRenderer;
    
    // Persistent light and material properties.
    vec3 mLightPos;
    vec3 mLightColor;
    vec3 mMaterialAmbient;
    vec3 mMaterialDiffuse;
    vec3 mMaterialSpecular;
    float mShininess;
    
    // New: Persistent object color.
    vec3 mObjectColor = vec3(1.0f, 1.0f, 1.0f);


    /// Constructor: Setup OpenGL and other libraries.
    this(int major_ogl_version, int minor_ogl_version) {
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, major_ogl_version);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, minor_ogl_version);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

        mWindow = SDL_CreateWindow("dlang - OpenGL 4+ Graphics Framework",
            SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED,
            640, 480,
            SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);

        mContext = SDL_GL_CreateContext(mWindow);
        auto retVal = LoadOpenGLLib();
        GetOpenGLVersionInfo();

        mRenderer = new Renderer(mWindow, 640, 480);
        mCamera = new Camera();
        mSceneTree = new SceneTree("root");

        // initialize persistent light and material properties
        mLightPos = vec3(1.0f, 1.0f, 1.0f);
        mLightColor = vec3(1.0f, 1.0f, 1.0f);
        mMaterialAmbient = vec3(0.5f, 0.5f, 0.5f);
        mMaterialDiffuse = vec3(0.8f, 0.8f, 0.8f);
        mMaterialSpecular = vec3(0.5f, 0.5f, 0.5f);
        mShininess = 32.0f;
    }

    /// Destructor.
    ~this() {
        SDL_GL_DeleteContext(mContext);
        SDL_DestroyWindow(mWindow);
    }

    /// Handle input.
    void Input() {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                writeln("Exit event triggered");
                mGameIsRunning = false;
            }
            if (event.type == SDL_KEYDOWN) {
                if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
                    writeln("Pressed escape key");
                    mGameIsRunning = false;
                } else if (event.key.keysym.sym == SDLK_TAB) {
                    mRenderWireframe = !mRenderWireframe;
                } else if (event.key.keysym.sym == SDLK_DOWN) {
                    mCamera.MoveBackward();
                } else if (event.key.keysym.sym == SDLK_UP) {
                    mCamera.MoveForward();
                } else if (event.key.keysym.sym == SDLK_LEFT) {
                    mCamera.MoveLeft();
                } else if (event.key.keysym.sym == SDLK_RIGHT) {
                    mCamera.MoveRight();
                } else if (event.key.keysym.sym == SDLK_a) {
                    mCamera.MoveUp();
                } else if (event.key.keysym.sym == SDLK_z) {
                    mCamera.MoveDown();
                }
                writeln("Camera Position: ", mCamera.mEyePosition);
            }
        }
        int mouseX, mouseY;
        SDL_GetMouseState(&mouseX, &mouseY);
        mCamera.MouseLook(mouseX, mouseY);
    }

    /// Setup the scene.
    void SetupScene() {
        // Create the pipeline and material for the bunny.
        Pipeline basicPipeline = new Pipeline("basic", "./pipelines/basic/basic.vert", "./pipelines/basic/basic.frag");
        IMaterial basicMaterial = new BasicMaterial("basic");

        // // Load the bunny OBJ.
        // ISurface obj = new SurfaceOBJ("./assets/bunny_centered.obj");
        // MeshNode bunnyNode = new MeshNode("bunny", obj, basicMaterial);
        // mSceneTree.GetRootNode().AddChildSceneNode(bunnyNode);

		// // auto matData = parseMTL("./assets/bunny_centered_247_faces.mtl", "None");
		// mObjectColor = vec3(1.0f, 1.0f, 1.0f);
		// // NOTE: The material properties are set in the constructor of the BasicMaterial class, I'm not pulling from the MTL file here! (except the color)

        // select P3 heightmap file
        string heightmapFile = "./assets/heightmap.ppm"; // Or heightmap.ppm
        // Choose scaling (XZ scale, Y scale)
        float terrainXZScale = 20.0f;
        float terrainYScale = 4.0f; // Adjust height exaggeration
        ISurface terrainSurface = new SurfaceTerrain(heightmapFile, terrainXZScale, terrainYScale);

        MeshNode terrainNode = new MeshNode("terrain", terrainSurface, basicMaterial);

        terrainNode.mModelMatrix = MatrixMakeTranslation(vec3(0.0f, -2.0f, 0.0f)); // Example
        mObjectColor = vec3(0.3f, 0.6f, 0.2f);

        // Add lighting and material uniforms using persistent member variables.
        basicMaterial.AddUniform(new Uniform("uLightPos", "vec3", &mLightPos));
        basicMaterial.AddUniform(new Uniform("uLightColor", "vec3", &mLightColor));
        basicMaterial.AddUniform(new Uniform("uViewPos", "vec3", mCamera.mEyePosition.DataPtr()));
        basicMaterial.AddUniform(new Uniform("uMaterialAmbient", "vec3", &mMaterialAmbient));
        basicMaterial.AddUniform(new Uniform("uMaterialDiffuse", "vec3", &mMaterialDiffuse));
        basicMaterial.AddUniform(new Uniform("uMaterialSpecular", "vec3", &mMaterialSpecular));
        basicMaterial.AddUniform(new Uniform("uShininess", mShininess));

        // Add transformation uniforms.
        basicMaterial.AddUniform(new Uniform("uModel", "mat4", null));
        basicMaterial.AddUniform(new Uniform("uView", "mat4", mCamera.mViewMatrix.DataPtr()));
        basicMaterial.AddUniform(new Uniform("uProjection", "mat4", mCamera.mProjectionMatrix.DataPtr()));

        // Add the object inherent color uniform.
        basicMaterial.AddUniform(new Uniform("uObjectColor", "vec3", &mObjectColor));

        // // --- Create a light marker for debugging ---
        // ISurface lightMarkerSurface = new SurfaceCube();
        // // Use the same pipeline ("basic") for the light marker material.
        // IMaterial lightMarkerMaterial = new BasicMaterial("basic");
        // lightMarkerMaterial.AddUniform(new Uniform("uModel", "mat4", null));
        // lightMarkerMaterial.AddUniform(new Uniform("uView", "mat4", mCamera.mViewMatrix.DataPtr()));
        // lightMarkerMaterial.AddUniform(new Uniform("uProjection", "mat4", mCamera.mProjectionMatrix.DataPtr()));

		// vec3 whiteColor = vec3(1.0f, 1.0f, 1.0f);
		// lightMarkerMaterial.AddUniform(new Uniform("uObjectColor", "vec3", &whiteColor));


        // MeshNode lightMarkerNode = new MeshNode("light_marker", lightMarkerSurface, lightMarkerMaterial);
        // mSceneTree.GetRootNode().AddChildSceneNode(lightMarkerNode);
    }

    /// Update game state.
    void Update() {
        // Animate the bunny.
        // static float yRotation = 0.0f;
        // yRotation += 0.01f;
        // MeshNode bunnyNode = cast(MeshNode) mSceneTree.FindNode("bunny");
        // bunnyNode.mModelMatrix = MatrixMakeTranslation(vec3(0.0f, 0.0f, -1.0f))
        //                         * MatrixMakeYRotation(yRotation);

        // the light should ideally 'oprbit' around the bunny in a 3d plane

        static float theta = 0.0f;  // azimuth angle
        static float phi = 0.0f;    // polar angle
		// NOTE: update to change speed and orbit
        theta += 0.01f;
        phi += 0.008f;
        float r = 30.0f;
        vec3 bunnyCenter = vec3(0.0f, 0.0f, 0.0f); // centered around the bunny
        mLightPos.x = bunnyCenter.x + r * sin(phi) * cos(theta);
        mLightPos.y = bunnyCenter.y + r * cos(phi);
        mLightPos.z = bunnyCenter.z + r * sin(phi) * sin(theta);
    }

    /// Render the scene.
    void Render() {
        if (mRenderWireframe) {
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        } else {
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        }
        mRenderer.Render(mSceneTree, mCamera);
    }

    /// Process one frame.
    void AdvanceFrame() {
        Input();
        Update();
        Render();
        SDL_Delay(16);  // ~60 FPS.
    }

    /// Main application loop.
    void Loop() {
        SetupScene();
        SDL_WarpMouseInWindow(mWindow, 640 / 2, 320 / 2);
        while (mGameIsRunning) {
            AdvanceFrame();
        }
    }
}
