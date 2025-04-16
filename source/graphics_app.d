/// The main graphics application with the main graphics loop.
module graphics_app;
import std.stdio;
import core;
import mesh, linear, scene, materials, geometry;
import platform;
import helper_modules;

import bindbc.sdl;
import bindbc.opengl;
import std.math;
import std.string : fromStringz;


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
            1280, 720,
            SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);


        // if (mWindow is null) {
        //      throw new Exception("Failed to create SDL window: " ~ fromStringz(SDL_GetError()));
        // }
        mContext = SDL_GL_CreateContext(mWindow);
        //  if (mContext is null) {
        //      throw new Exception("Failed to create OpenGL context: " ~ fromStringz(SDL_GetError()));
        // }
        auto retVal = LoadOpenGLLib(); // From opengl_abstraction
        // if (!retVal) {
        //      throw new Exception("Failed to load OpenGL functions.");
        // }
        GetOpenGLVersionInfo(); // From opengl_abstraction

        // Assuming Renderer constructor takes window and dimensions
        int w, h;
        SDL_GetWindowSize(mWindow, &w, &h);
        mRenderer = new Renderer(mWindow, w, h); // Pass actual size
        mCamera = new Camera();
        mSceneTree = new SceneTree("root");

        // --- Initialize Light/Material Defaults (Keep as is or adjust) ---
        mLightPos = vec3(50.0f, 50.0f, 50.0f); // Move light further out for terrain
        mLightColor = vec3(1.0f, 1.0f, 1.0f);
        // Material properties for the terrain (if using BasicMaterial)
        mMaterialAmbient = vec3(0.2f, 0.2f, 0.2f);
        mMaterialDiffuse = vec3(0.7f, 0.7f, 0.7f);
        mMaterialSpecular = vec3(0.1f, 0.1f, 0.1f); // Terrain usually not very shiny
        mShininess = 4.0f;
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
        writeln("--- Setting up scene ---");

        // --- 1. Create Pipelines ---
        // *** Create pipeline for the unlit terrain shaders ***
        // Ensure these paths point to the terrain.vert and terrain.frag we defined earlier
        string terrainVertPath = "./pipelines/terrain_std/terrain_std.vert";
        string terrainFragPath = "./pipelines/terrain_std/terrain_std.frag";
        Pipeline terrainPipeline = new Pipeline("terrain", terrainVertPath, terrainFragPath);
        writeln("Terrain pipeline created.");

        // Keep basic pipeline ONLY if needed elsewhere, otherwise remove.
        Pipeline basicPipeline = new Pipeline("basic", "./pipelines/terrain_std/terrain_std.vert", "./pipelines/terrain_std/terrain_std.frag");


        // --- 2. Create Terrain Surface ---
        // (This part remains the same)
        writeln("Creating terrain surface...");
        string heightmapPath = "./assets/custommap.png"; // *** ENSURE CORRECT PATH ***
        ISurface terrainSurface;
        try {
            terrainSurface = new SurfaceTerrain(heightmapPath);
        } catch (Exception e) {
            stderr.writeln("CRITICAL: Failed to initialize terrain in SetupScene.");
            stderr.writeln(e.msg);
            mGameIsRunning = false;
            return;
        }
        writeln("Terrain surface created.");

        // --- 3. Create Terrain Material (MultiTexture) ---
        // *** Use MultiTextureMaterial with the "terrain" pipeline ***
        // *** Specify paths to your 4 terrain textures ***
        string texLayer1 = "./assets/dirt.ppm";    // <<< CHECK THIS LINE!!!
        string texLayer2 = "./assets/grass.ppm";   // This one seems correct based on logs
        string texLayer3 = "./assets/rock.ppm";    // This one seems correct based on logs
        string texLayer4 = "./assets/snow.ppm";    // This one seems correct based on logs


        IMaterial terrainMaterial; // Use the interface type
        try {
             // Ensure MultiTextureMaterial handles potential texture load errors gracefully
             terrainMaterial = new MultiTextureMaterial("terrain", texLayer1, texLayer2, texLayer3, texLayer4);
        } catch (Exception e) { // Assuming MultiTextureMaterial might throw if textures fail
             stderr.writeln("CRITICAL: Failed to create terrain material (check texture paths/loading).");
             stderr.writeln(e.msg);
             mGameIsRunning = false;
             // Clean up surface? Depends if destructor handles partial failure
             // destroy(terrainSurface); // Maybe?
             return;
        }
        writeln("Terrain material created.");


        // --- 4. Add REQUIRED Uniforms to Terrain Material ---
        // Add ONLY the uniforms needed by terrain.vert and terrain.frag
        // Samplers are needed for the material to function, even if set internally
        terrainMaterial.AddUniform(new Uniform("sampler1", "sampler2D", null));
        terrainMaterial.AddUniform(new Uniform("sampler2", "sampler2D", null));
        terrainMaterial.AddUniform(new Uniform("sampler3", "sampler2D", null));
        terrainMaterial.AddUniform(new Uniform("sampler4", "sampler2D", null));

        // Add transformation uniforms used by terrain.vert
        terrainMaterial.AddUniform(new Uniform("uModel", "mat4", null)); // Set per-node during render
        terrainMaterial.AddUniform(new Uniform("uView", "mat4", mCamera.mViewMatrix.DataPtr()));
        terrainMaterial.AddUniform(new Uniform("uProjection", "mat4", mCamera.mProjectionMatrix.DataPtr()));

        // *** IMPORTANT: DO NOT ADD LIGHTING/OTHER UNUSED UNIFORMS HERE ***
         terrainMaterial.AddUniform(new Uniform("uLightPos", "vec3", &mLightPos)); // REMOVED
         terrainMaterial.AddUniform(new Uniform("uLightColor", "vec3", &mLightColor)); // REMOVED
         terrainMaterial.AddUniform(new Uniform("uViewPos", "vec3", mCamera.mEyePosition.DataPtr())); // REMOVED
         terrainMaterial.AddUniform(new Uniform("uMaterialAmbient", "vec3", &mMaterialAmbient)); // REMOVED
         terrainMaterial.AddUniform(new Uniform("uMaterialDiffuse", "vec3", &mMaterialDiffuse)); // REMOVED
         terrainMaterial.AddUniform(new Uniform("uMaterialSpecular", "vec3", &mMaterialSpecular)); // REMOVED
        // terrainMaterial.AddUniform(new Uniform("uShininess", "float", &mShininess)); // REMOVED

        writeln("Terrain material uniforms added.");


        // --- 5. Create Terrain Mesh Node ---
        // *** Use the new terrainMaterial ***
        MeshNode terrainNode = new MeshNode("terrain", terrainSurface, terrainMaterial);
        mSceneTree.GetRootNode().AddChildSceneNode(terrainNode);
        writeln("Terrain node added to scene tree.");


        writeln("--- Scene setup finished ---");
    }

    /// Update game state.
    void Update() {
        // update camera
        mCamera.UpdateViewMatrix();
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
