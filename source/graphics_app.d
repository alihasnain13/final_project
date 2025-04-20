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
    // --- Core State ---
    bool mGameIsRunning = true;
    bool mRenderWireframe = false;
    SDL_GLContext mContext;
    SDL_Window* mWindow;

    // --- Scene Management ---
    SceneTree mSceneTree;
    Camera mCamera;
    Renderer mRenderer;

    ulong mLastFrameTime = 0; // Time stamp of the previous frame start (milliseconds)
    float mDeltaTime = 0.0f;  // Time elapsed since last frame (seconds)

    // --- Lighting & Default Material Properties ---
    // (Used primarily by the standard HiRes material)
    vec3 mLightPos;
    vec3 mLightColor;
    vec3 mMaterialAmbient;
    vec3 mMaterialDiffuse;
    vec3 mMaterialSpecular;
    float mShininess;

    // --- Tessellation / Switching State ---
    bool mUseTessellation = false; // Start with standard rendering (CPU Hi-Res)

    // Surfaces (Geometry Data for BOTH modes)
    ISurface mTerrainSurfaceHiRes; // For standard rendering (Hi-res Triangles)
    ISurface mTerrainSurfaceLoRes; // For tessellation input (Low-res Patches)

    // Materials (Shader + Uniforms + Textures for BOTH modes)
    IMaterial mTerrainMaterialHiRes; // For standard rendering (Lit, MultiTexture)
    IMaterial mTerrainMaterialTess;  // For tessellation rendering (Unlit, TessellationMaterial)

    // Shared Texture Object (Loaded once)
    Texture mHeightMapTexture; // Used by TessellationMaterial

    // Shared Scale/Shift (Calculated once, used by TessellationMaterial via uniforms)
    float mTerrainYScale = 250.0f; // Height scale factor (for tessellation)

    float mTerrainYShift = -40.0f; // Height shift factor (for tessellation)

    // Reference to the single terrain node in the scene graph
    MeshNode mTerrainNode;

    /// Constructor: Setup OpenGL and other libraries.
    this(int major_ogl_version, int minor_ogl_version) {
        writeln("Initializing GraphicsApp...");
        // --- SDL/OpenGL Context Setup ---
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, major_ogl_version);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, minor_ogl_version);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

        mWindow = SDL_CreateWindow("D Terrain - Tessellation Toggle ('T')", // Updated title
            SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
            1280, 720, // Window size
            SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);

        if (mWindow is null) {
            throw new Exception("Failed to create SDL window: " ~ fromStringz(SDL_GetError()).idup);
        }
        mContext = SDL_GL_CreateContext(mWindow);
         if (mContext is null) {
            throw new Exception("Failed to create OpenGL context: " ~ fromStringz(SDL_GetError()).idup);
        }

        // Load OpenGL function pointers
        auto retVal = LoadOpenGLLib();
        if (!retVal) {
             throw new Exception("Failed to load OpenGL functions.");
        }
        GetOpenGLVersionInfo();

        // --- Core App Components ---
        int w, h;
        SDL_GetWindowSize(mWindow, &w, &h);
        mRenderer = new Renderer(mWindow, w, h);
        mCamera = new Camera();
        mSceneTree = new SceneTree("root");

        // --- Initialize Light/Material Defaults ---
        mLightPos = vec3(50.0f, 150.0f, 150.0f); // Position light higher/further
        mLightColor = vec3(1.0f, 1.0f, 1.0f);
        mMaterialAmbient = vec3(0.2f, 0.2f, 0.2f);
        mMaterialDiffuse = vec3(0.6f, 0.6f, 0.6f);
        mMaterialSpecular = vec3(0.1f, 0.1f, 0.1f);
        mShininess = 8.0f;

        writeln("GraphicsApp Construction Complete.");
    }

    /// Destructor.
    ~this() {
        writeln("Destroying GraphicsApp...");
        // Consider order if dependencies exist (e.g., node uses material/surface)
        // D's GC might handle this, but explicit destruction can be safer for resources.
        // destroy(mTerrainNode);
        // destroy(mTerrainMaterialTess); destroy(mTerrainMaterialHiRes);
        // destroy(mTerrainSurfaceLoRes); destroy(mTerrainSurfaceHiRes);
        // destroy(mHeightMapTexture);

        SDL_GL_DeleteContext(mContext);
        SDL_DestroyWindow(mWindow);
        writeln("GraphicsApp Destroyed.");
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
                    writeln("Wireframe Toggled: ", mRenderWireframe);
                }
                // --- TESSELLATION TOGGLE ---
                else if (event.key.keysym.sym == SDLK_t) {
                     mUseTessellation = !mUseTessellation; // Flip the flag
                     writeln("Switching Render Mode -> Use Tessellation: ", mUseTessellation);
                     if (mTerrainNode !is null) { // Check node reference is valid
                          // Swap the Surface and Material used by the terrain node
                          // Requires SetSurface/SetMaterial on MeshNode class!
                          if (mUseTessellation) {
                              writeln("  Setting LoRes Patch Surface and Tessellation Material");
                              mTerrainNode.SetSurface(mTerrainSurfaceLoRes);
                              mTerrainNode.SetMaterial(mTerrainMaterialTess);
                          } else {
                              writeln("  Setting HiRes Triangle Surface and Standard Material");
                              mTerrainNode.SetSurface(mTerrainSurfaceHiRes);
                              mTerrainNode.SetMaterial(mTerrainMaterialHiRes);
                          }
                     } else {
                          writeln("  Error: Terrain node reference is null during toggle!");
                     }
                }
                // --- Camera Movement ---
                else if (event.key.keysym.sym == SDLK_DOWN) { mCamera.MoveBackward(); }
                else if (event.key.keysym.sym == SDLK_UP)    { mCamera.MoveForward(); }
                else if (event.key.keysym.sym == SDLK_LEFT)  { mCamera.MoveLeft(); }
                else if (event.key.keysym.sym == SDLK_RIGHT) { mCamera.MoveRight(); }
                else if (event.key.keysym.sym == SDLK_a)     { mCamera.MoveUp(); }
                else if (event.key.keysym.sym == SDLK_z)     { mCamera.MoveDown(); }

                // Optional: Log camera position sometimes
                // writeln("Camera Position: ", mCamera.mEyePosition);
            }
        }
        int mouseX, mouseY;
        SDL_GetMouseState(&mouseX, &mouseY); // Get mouse state for looking
        mCamera.MouseLook(mouseX, mouseY); // Update camera orientation
    }

    /// Setup the scene - Creates pipelines, surfaces, materials, nodes.
    void SetupScene() {
        writeln("--- Setting up scene ---");
        // --- Shared Paths ---
        string heightmapPath = "./assets/custommap.png"; // ENSURE THIS IS CORRECT
        string texDirt = "./assets/dirt.ppm";
        string texGrass = "./assets/grass.ppm";
        string texRock = "./assets/rock.ppm";
        string texSnow = "./assets/snow.ppm";

        // --- 1. Load Shared Heightmap Texture ONCE ---
        writeln("Loading shared heightmap texture: ", heightmapPath);
        try {
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1); // Safest for textures
            // Ensure Texture class loads the format correctly (PNG via Gamut recommended)
            // Using Texture constructor assuming it works for heightmap format now.
            mHeightMapTexture = new Texture(heightmapPath);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4); // Reset alignment
            if (mHeightMapTexture is null || mHeightMapTexture.mTextureID == 0) {
                 throw new Exception("Heightmap Texture object is null or has invalid ID.");
            }
        } catch (Exception e) {
            stderr.writeln("CRITICAL: Failed to load shared heightmap texture."); stderr.writeln(e.msg);
            mGameIsRunning = false; return;
        }
        writeln("Shared heightmap texture loaded. ID: ", mHeightMapTexture.mTextureID);


        // --- 2. Create BOTH Terrain Surfaces ---
        writeln("Creating terrain surfaces...");
        try {
            // High-Res Triangles for standard pipeline
            mTerrainSurfaceHiRes = new SurfaceTerrain(heightmapPath, false); // generatePatches = false

            // Low-Res Quad Patches for tessellation pipeline
            uint patchResolution = 64; // Adjust as needed (e.g., 32, 64, 128)
            mTerrainSurfaceLoRes = new SurfaceTerrain(heightmapPath, true, patchResolution); // generatePatches = true

            // Get scale/shift values (use HiRes surface as it calculates them during generation)
            mTerrainYScale = (cast(SurfaceTerrain)mTerrainSurfaceHiRes).getYScale(); // Cast needed if using interface type
            mTerrainYShift = (cast(SurfaceTerrain)mTerrainSurfaceHiRes).getYShift();

        } catch (Exception e) {
            stderr.writeln("CRITICAL: Failed to initialize terrain surfaces."); stderr.writeln(e.msg);
            mGameIsRunning = false; return;
        }
        writeln("Terrain surfaces created.");


        // --- 3. Create BOTH Pipelines ---
        writeln("Creating pipelines...");
        try {
            // Standard Lit Pipeline (VS+FS)
            // Ensure these paths point to your working LIT vertex and fragment shaders
            string litVertPath = "./pipelines/terrain_std/terrain_std.vert"; // Or terrain_std path
            string litFragPath = "./pipelines/terrain_std/terrain_std.frag"; // Or terrain_std path
            Pipeline cpuPipeline = new Pipeline("cpu_terrain", litVertPath, litFragPath);

            // Tessellation Pipeline (VS+TCS+TES+FS)
            // Ensure paths point to the new tessellation shaders created earlier
            string tessVertPath = "./pipelines/terrain_tess/terrain_tess.vert";
            string tessFragPath = "./pipelines/terrain_tess/terrain_tess.frag"; // Unlit blended FS
            string tessCtrlPath = "./pipelines/terrain_tess/terrain_tess.tcs"; // TCS with fixed levels
            string tessEvalPath = "./pipelines/terrain_tess/terrain_tess.tes"; // TES with height displace
            // Use the constructor that takes 5 paths
            Pipeline tessPipeline = new Pipeline("tess_terrain", tessVertPath, tessFragPath, tessCtrlPath, tessEvalPath);
        } catch (Exception e) {
             stderr.writeln("CRITICAL: Failed to create pipelines."); stderr.writeln(e.msg);
             mGameIsRunning = false; return;
        }
        writeln("Pipelines created.");

        // --- 4. Create BOTH Materials ---
        writeln("Creating materials...");
        try {
            // Standard Material (uses MultiTextureMaterial for lit pipeline)
            mTerrainMaterialHiRes = new MultiTextureMaterial("cpu_terrain", texDirt, texGrass, texRock, texSnow);

            // Tessellation Material (uses TessellationMaterial for tess pipeline)
            mTerrainMaterialTess = new TessellationMaterial("tess_terrain", texDirt, texGrass, texRock, texSnow, mHeightMapTexture);

        } catch (Exception e) {
            stderr.writeln("CRITICAL: Failed to create materials."); stderr.writeln(e.msg);
            mGameIsRunning = false; return;
        }
        writeln("Materials created.");


        // --- 5. Add Uniforms to Specific Materials ---

        // Uniforms needed by BOTH pipelines/materials (MVP, surface samplers)
        IMaterial[2] mats = [mTerrainMaterialHiRes, mTerrainMaterialTess];
        foreach(mat; mats) {
            // mat.AddUniform(new Uniform("sampler1", "sampler2D", null));
            // mat.AddUniform(new Uniform("sampler2", "sampler2D", null));
            // mat.AddUniform(new Uniform("sampler3", "sampler2D", null));
            // mat.AddUniform(new Uniform("sampler4", "sampler2D", null));
            mat.AddUniform(new Uniform("uModel", "mat4", null));
            mat.AddUniform(new Uniform("uView", "mat4", mCamera.mViewMatrix.DataPtr()));
            mat.AddUniform(new Uniform("uProjection", "mat4", mCamera.mProjectionMatrix.DataPtr()));
        }

        // Uniforms needed ONLY by standard (HiRes) LIT pipeline/material
        writeln("Adding lighting uniforms to HiRes material...");
        mTerrainMaterialHiRes.AddUniform(new Uniform("sampler1", "sampler2D", null));
        mTerrainMaterialHiRes.AddUniform(new Uniform("sampler2", "sampler2D", null));
        mTerrainMaterialHiRes.AddUniform(new Uniform("sampler3", "sampler2D", null));
        mTerrainMaterialHiRes.AddUniform(new Uniform("sampler4", "sampler2D", null));
        mTerrainMaterialHiRes.AddUniform(new Uniform("uLightPos", "vec3", &mLightPos));
        mTerrainMaterialHiRes.AddUniform(new Uniform("uLightColor", "vec3", &mLightColor));
        mTerrainMaterialHiRes.AddUniform(new Uniform("uViewPos", "vec3", mCamera.mEyePosition.DataPtr()));
        mTerrainMaterialHiRes.AddUniform(new Uniform("uMaterialAmbient", "vec3", &mMaterialAmbient));
        mTerrainMaterialHiRes.AddUniform(new Uniform("uMaterialDiffuse", "vec3", &mMaterialDiffuse));
        mTerrainMaterialHiRes.AddUniform(new Uniform("uMaterialSpecular", "vec3", &mMaterialSpecular));
        mTerrainMaterialHiRes.AddUniform(new Uniform("uShininess", mShininess));

        // Uniforms needed ONLY by Tessellation pipeline/material
        writeln("Adding tessellation uniforms to Tess material...");
        mTerrainMaterialTess.AddUniform(new Uniform("uHeightMap", "sampler2D", null)); // For TES
        // mTerrainMaterialTess.AddUniform(new Uniform("uYScale", mTerrainYScale));      // For TES
        // mTerrainMaterialTess.AddUniform(new Uniform("uYShift", mTerrainYShift));      // For TES

        float tessYRange = terraingeometry.SurfaceTerrain.WORLD_MAX_HEIGHT - terraingeometry.SurfaceTerrain.WORLD_MIN_HEIGHT; // Should be 250.0f
        float tessYShift = terraingeometry.SurfaceTerrain.WORLD_MIN_HEIGHT; // Should be -40.0f
        writeln("  Passing to TES: uYScale (Range)=", tessYRange, ", uYShift (Min)=", tessYShift);

        mTerrainMaterialTess.AddUniform(new Uniform("uYScale", tessYRange)); // <<< Pass 250.0f
        mTerrainMaterialTess.AddUniform(new Uniform("uYShift", tessYShift)); // <<< Pass -40.0f

        writeln("Material uniforms added.");


        // --- 6. Create ONE Terrain Mesh Node and add to Scene ---
        // Create the node container first
        mTerrainNode = new MeshNode("terrain", null, null); // Start with null surface/material

        // *** IMPORTANT: Ensure MeshNode class has these methods: ***
        // void SetSurface(ISurface surface) { this.mSurface = surface; }
        // void SetMaterial(IMaterial material) { this.mMaterial = material; }

        // Set the initial state to standard rendering (HiRes)
        mTerrainNode.SetSurface(mTerrainSurfaceHiRes);
        mTerrainNode.SetMaterial(mTerrainMaterialHiRes);

        // Initialize model matrix (place terrain at origin)
        mTerrainNode.mModelMatrix = MatrixMakeIdentity();

        // Add the single, configurable terrain node to the scene
        mSceneTree.GetRootNode().AddChildSceneNode(mTerrainNode);
        writeln("Terrain node added to scene tree (Default: HiRes).");

        writeln("--- Scene setup finished ---");
        writeln("*** Press 'T' to toggle Tessellation ***");
    }

    /// Update game state.
    void Update() {
        // Update camera view matrix (needed for uView uniform, potentially uViewPos)
        mCamera.UpdateViewMatrix(); // Make sure this updates the matrix pointed to by the uniform

        // Optional: Animate light source?
        // static float lightAngle = 0.0f; lightAngle += 0.005f;
        // mLightPos.x = 150.0f * cos(lightAngle);
        // mLightPos.z = 150.0f * sin(lightAngle);
    }

    /// Render the scene.
    void Render() {
        // Set wireframe polygon mode if enabled
        if (mRenderWireframe) {
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        } else {
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        }

        // *** Set OpenGL Patch Parameter IF using Tessellation ***
        if (mUseTessellation) {
             // This value MUST match `layout (vertices = N) out;` in the TCS.
             // We used N=4 for quad patches.
             glPatchParameteri(GL_PATCH_VERTICES, 4);
        }

        // Renderer traverses the scene tree.
        // It will find mTerrainNode and use its *current* Surface & Material
        // to select the pipeline, set uniforms (via Material.Update),
        // bind VAO, and issue the correct DrawElements call (Surface.Render).
        mRenderer.Render(mSceneTree, mCamera);

        // Optional: Reset polygon mode after rendering if needed elsewhere
        // if (mRenderWireframe) { glPolygonMode(GL_FRONT_AND_BACK, GL_FILL); }
    }

    /// Process one frame.
    void AdvanceFrame() {

        ulong currentTime = SDL_GetTicks(); // Get current time in milliseconds
        if (mLastFrameTime == 0) {
             mLastFrameTime = currentTime; // Initialize on first frame
        }
        // Calculate delta time in milliseconds, convert to seconds
        mDeltaTime = (currentTime - mLastFrameTime) / 1000.0f;
        mLastFrameTime = currentTime; // Update last time for next frame

        // Clamp delta time to prevent huge jumps if debugging/stalling
        const float MAX_DELTA_TIME = 0.1f; // Cap at 100ms / 10 FPS
        if (mDeltaTime > MAX_DELTA_TIME) {
            // writeln("Clamping DeltaTime from ", mDeltaTime); // Optional debug log
             mDeltaTime = MAX_DELTA_TIME;
        }

        Input();
        Update();
        Render();
    }

    /// Main application loop.
    void Loop() {
        // Setup Scene - wrapped in try/catch for robustness
        try {
             SetupScene();
        } catch (Exception e) {
             stderr.writeln("FATAL ERROR during SetupScene: ", e.msg);
             mGameIsRunning = false; // Ensure loop terminates
        }

        // Initial mouse warp
        if (mGameIsRunning && mWindow !is null) {
             int w, h;
             SDL_GetWindowSize(mWindow, &w, &h);
             SDL_WarpMouseInWindow(mWindow, w / 2, h / 2);
             // Optional: Capture mouse for FPS camera
             // SDL_SetRelativeMouseMode(SDL_TRUE);
        }

        // Main loop
        while (mGameIsRunning) {
            AdvanceFrame();
        }

        writeln("Exiting main loop.");
        // Cleanup happens in destructors
    }
} // End struct GraphicsApp