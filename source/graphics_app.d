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

    // --- Timing ---
    ulong mLastFrameTime = 0;
    float mDeltaTime = 0.0f;

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
    ISurface mTerrainSurfaceHiRes;
    ISurface mTerrainSurfaceLoRes;

    // Materials (Shader + Uniforms + Textures for BOTH modes)
    IMaterial mTerrainMaterialHiRes; 
    IMaterial mTerrainMaterialTess;  

    // Shared Texture Object (Loaded once)
    Texture mHeightMapTexture; // Used by TessellationMaterial

    // Shared Scale/Shift (Calculated once, used by TessellationMaterial via uniforms)
    float mTerrainYScale = 250.0f; 
    float mTerrainYShift = -40.0f;

    // Reference to the single terrain node in the scene graph
    MeshNode mTerrainNode;

    // --- Input State for Camera ---
    float moveForward = 0.0f; 
    float moveRight = 0.0f;   
    float moveUp = 0.0f;      
    float mScrollDelta = 0.0f;
    bool mIsPanning = false;
    int mLastPanX = 0;        
    int mLastPanY = 0;        

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
            2560, 1080, // Window size
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

        // --- Initialize Light/Material Defaults
        mLightPos = vec3(50.0f, 150.0f, 150.0f); mLightColor = vec3(1.0f, 1.0f, 1.0f);
        mMaterialAmbient = vec3(0.2f, 0.2f, 0.2f); mMaterialDiffuse = vec3(0.6f, 0.6f, 0.6f);
        mMaterialSpecular = vec3(0.1f, 0.1f, 0.1f); mShininess = 8.0f;

        writeln("GraphicsApp Construction Complete.");
    }

    /// Destructor.
    ~this() {
        writeln("Destroying GraphicsApp...");

        SDL_GL_DeleteContext(mContext);
        SDL_DestroyWindow(mWindow);
        writeln("GraphicsApp Destroyed.");
    }

    /// Handle input.
    void Input() {

        // Reset frame-specific input state
        moveForward = 0.0f;
        moveRight = 0.0f;
        moveUp = 0.0f;
        mScrollDelta = 0.0f; // Reset scroll accumulator


        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            switch(event.type) {
                case SDL_QUIT:
                    writeln("Exit event triggered");
                    mGameIsRunning = false;
                    break;

                case SDL_KEYDOWN:
                    if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) { mGameIsRunning = false; writeln("Pressed escape key"); }
                    else if (event.key.keysym.sym == SDLK_TAB) { mRenderWireframe = !mRenderWireframe; writeln("Wireframe Toggled: ", mRenderWireframe); }
                    // --- TESSELLATION TOGGLE ---
                    else if (event.key.keysym.sym == SDLK_t) {
                         mUseTessellation = !mUseTessellation;
                         writeln("Switching Render Mode -> Use Tessellation: ", mUseTessellation);
                         if (mTerrainNode !is null) {
                              if (mUseTessellation) {
                                  writeln("  Setting LoRes Patch Surface and Tessellation Material");
                                  mTerrainNode.SetSurface(mTerrainSurfaceLoRes);
                                  mTerrainNode.SetMaterial(mTerrainMaterialTess);
                              } else {
                                  writeln("  Setting HiRes Triangle Surface and Standard Material");
                                  mTerrainNode.SetSurface(mTerrainSurfaceHiRes);
                                  mTerrainNode.SetMaterial(mTerrainMaterialHiRes);
                              }
                         } else { writeln("  Error: Terrain node null!"); }
                    }
                    // --- Set Movement Request Flags ---
                    else if (event.key.keysym.sym == SDLK_UP || event.key.keysym.sym == SDLK_w)    { moveForward = 1.0f; }
                    else if (event.key.keysym.sym == SDLK_DOWN || event.key.keysym.sym == SDLK_s)  { moveForward = -1.0f; }
                    else if (event.key.keysym.sym == SDLK_LEFT || event.key.keysym.sym == SDLK_a)  { moveRight = -1.0f; }
                    else if (event.key.keysym.sym == SDLK_RIGHT || event.key.keysym.sym == SDLK_d) { moveRight = 1.0f; }
                    else if (event.key.keysym.sym == SDLK_q)     { moveUp = 1.0f; }
                    else if (event.key.keysym.sym == SDLK_z)     { moveUp = -1.0f; }
                    break; // End SDL_KEYDOWN

                case SDL_KEYUP:
                     break;

                // --- MOUSE WHEEL for ZOOM ---
                case SDL_MOUSEWHEEL:
                    if (event.wheel.y != 0) {
                         mCamera.Zoom( -event.wheel.y );
                    }
                    break;

                 // --- MOUSE BUTTON for PANNING ---
                case SDL_MOUSEBUTTONDOWN:
                    // Start panning if middle button is pressed AND not already panning
                    if (event.button.button == SDL_BUTTON_MIDDLE && !mIsPanning) {
                        mIsPanning = true;
                        // Store the mouse position where panning *started*
                        SDL_GetMouseState(&mLastPanX, &mLastPanY);
                        SDL_SetRelativeMouseMode(SDL_TRUE);
                        SDL_ShowCursor(SDL_FALSE);          
                        writeln("Panning Started");
                    }
                    break;
                case SDL_MOUSEBUTTONUP:
                     // Stop panning if middle button is released AND we were panning
                     if (event.button.button == SDL_BUTTON_MIDDLE && mIsPanning) {
                        mIsPanning = false;
                        SDL_SetRelativeMouseMode(SDL_FALSE); 
                        SDL_ShowCursor(SDL_TRUE);          
                        writeln("Panning Stopped");
                    }
                    break;

                // --- MOUSE MOTION --- Handles Look OR Pan
                case SDL_MOUSEMOTION:
                    // Get current absolute position (needed for non-relative mode look)
                    int currentMouseX = event.motion.x;
                    int currentMouseY = event.motion.y;

                    if (mIsPanning) {
                         
                         int panDeltaX = event.motion.xrel;
                         int panDeltaY = event.motion.yrel;

                         if (panDeltaX != 0 || panDeltaY != 0) {
                             // pass raw relative deltas; sensitivity handled inside Camera::Pan
                             mCamera.Pan(cast(float)panDeltaX, cast(float)panDeltaY); // <<< CALL CAMERA PAN
                             // writeln("Pan Motion Rel: dx=", panDeltaX, " dy=", panDeltaY); // Debug
                         }
                    } else {
                        // if not panning, perform standard mouse look using absolute position
                        mCamera.MouseLook(currentMouseX, currentMouseY);
                    }
                    break;

                // --- WINDOW RESIZE ---
                case SDL_WINDOWEVENT:
                    if (event.window.event == SDL_WINDOWEVENT_RESIZED) {
                         int newWidth = event.window.data1;
                         int newHeight = event.window.data2;
                         writeln("Window resized to: ", newWidth, "x", newHeight);
                         glViewport(0, 0, newWidth, newHeight); // Update viewport
                         if (newHeight > 0) {
                              float newAspect = cast(float)newWidth / newHeight;
                              // Call camera method to update projection
                              mCamera.UpdateProjectionMatrix(newAspect); // <<< CALL CAMERA UPDATE
                         }
                    }
                    break; // End SDL_WINDOWEVENT

                default: break;
            } // End switch event.type
        } // End while poll events
    } // End Input

    /// Setup the scene - Creates pipelines, surfaces, materials, nodes.
    void SetupScene() {
        writeln("--- Setting up scene ---");
        // --- Shared Paths ---
        string heightmapPath = "./assets/custommap.png"; // CHANGE THIS FOR TESTING
        string texDirt = "./assets/dirt.ppm";
        string texGrass = "./assets/grass.ppm";
        string texRock = "./assets/rock.ppm";
        string texSnow = "./assets/snow.ppm";

        // --- 1. Load Shared Heightmap Texture ONCE ---
        writeln("Loading shared heightmap texture: ", heightmapPath);
        try {
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1); // Safest for textures
            
            mHeightMapTexture = new Texture(heightmapPath);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4); // Reset alignment
            if (mHeightMapTexture is null || mHeightMapTexture.mTextureID == 0) {
                 throw new Exception("Heightmap Texture object is null or has invalid ID.");
            }

            glBindTexture(GL_TEXTURE_2D, mHeightMapTexture.mTextureID);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glGenerateMipmap(GL_TEXTURE_2D);
            
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
            uint patchResolution = 128;
            mTerrainSurfaceLoRes = new SurfaceTerrain(heightmapPath, true, patchResolution); // generatePatches = true

            // Get scale/shift values (use HiRes surface as it calculates them during generation)
            mTerrainYScale = (cast(SurfaceTerrain)mTerrainSurfaceHiRes).getYScale(); 
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
            string litVertPath = "./pipelines/terrain_std/terrain_std.vert"; 
            string litFragPath = "./pipelines/terrain_std/terrain_std.frag"; 
            Pipeline cpuPipeline = new Pipeline("cpu_terrain", litVertPath, litFragPath);

            // Tessellation Pipeline (VS+TCS+TES+FS)
            string tessVertPath = "./pipelines/terrain_tess/terrain_tess.vert";
            string tessFragPath = "./pipelines/terrain_tess/terrain_tess.frag"; 
            string tessCtrlPath = "./pipelines/terrain_tess/terrain_tess.tcs"; 
            string tessEvalPath = "./pipelines/terrain_tess/terrain_tess.tes"; 
            // new overload constructor here
            Pipeline tessPipeline = new Pipeline("tess_terrain", tessVertPath, tessFragPath, tessCtrlPath, tessEvalPath);
        } catch (Exception e) {
             stderr.writeln("CRITICAL: Failed to create pipelines."); stderr.writeln(e.msg);
             mGameIsRunning = false; return;
        }
        writeln("Pipelines created.");

        // --- 4. Create BOTH Materials ---
        writeln("Creating materials...");
        try {
            mTerrainMaterialHiRes = new MultiTextureMaterial("cpu_terrain", texDirt, texGrass, texRock, texSnow);

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
            mat.AddUniform(new Uniform("sampler1", "sampler2D", null));
            mat.AddUniform(new Uniform("sampler2", "sampler2D", null));
            mat.AddUniform(new Uniform("sampler3", "sampler2D", null));
            mat.AddUniform(new Uniform("sampler4", "sampler2D", null));

            mat.AddUniform(new Uniform("uModel", "mat4", null));
            mat.AddUniform(new Uniform("uView", "mat4", mCamera.mViewMatrix.DataPtr()));
            mat.AddUniform(new Uniform("uProjection", "mat4", mCamera.mProjectionMatrix.DataPtr()));

            mat.AddUniform(new Uniform("uLightPos", "vec3", &mLightPos));
            mat.AddUniform(new Uniform("uLightColor", "vec3", &mLightColor));
            mat.AddUniform(new Uniform("uViewPos", "vec3", mCamera.mEyePosition.DataPtr()));
            mat.AddUniform(new Uniform("uMaterialAmbient", "vec3", &mMaterialAmbient));
            mat.AddUniform(new Uniform("uMaterialDiffuse", "vec3", &mMaterialDiffuse));
            mat.AddUniform(new Uniform("uMaterialSpecular", "vec3", &mMaterialSpecular));
            mat.AddUniform(new Uniform("uShininess", mShininess));
        }

        // Uniforms needed ONLY by Tessellation pipeline/material
        writeln("Adding tessellation uniforms to Tess material...");
        mTerrainMaterialTess.AddUniform(new Uniform("uHeightMap", "sampler2D", null)); // For TES
        

        float tessYRange = terraingeometry.SurfaceTerrain.WORLD_MAX_HEIGHT - terraingeometry.SurfaceTerrain.WORLD_MIN_HEIGHT; // Should be 250.0f
        float tessYShift = terraingeometry.SurfaceTerrain.WORLD_MIN_HEIGHT; // Should be -40.0f
        writeln("  Passing to TES: uYScale (Range)=", tessYRange, ", uYShift (Min)=", tessYShift);

        mTerrainMaterialTess.AddUniform(new Uniform("uYScale", tessYRange)); // <<< Pass 250.0f
        mTerrainMaterialTess.AddUniform(new Uniform("uYShift", tessYShift)); // <<< Pass -40.0f

        writeln("Material uniforms added.");


        // Create the node container first
        mTerrainNode = new MeshNode("terrain", null, null); // Start with null surface/material

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

        // --- Calculate TARGET Movement Direction based on Input ---
        vec3 targetMovementDirection = vec3(0.0f);
        if (moveForward > 0.5f)  targetMovementDirection = targetMovementDirection + mCamera.mForwardVector;
        if (moveForward < -0.5f) targetMovementDirection = targetMovementDirection - mCamera.mForwardVector;
        if (moveRight > 0.5f)    targetMovementDirection = targetMovementDirection + mCamera.mRightVector;
        if (moveRight < -0.5f)   targetMovementDirection = targetMovementDirection - mCamera.mRightVector;
        if (moveUp > 0.5f)       targetMovementDirection = targetMovementDirection + WORLD_UP;
        if (moveUp < -0.5f)      targetMovementDirection = targetMovementDirection - WORLD_UP;

        // --- Calculate TARGET Velocity (Direction * Speed) ---
        vec3 targetVelocity = vec3(0.0f);
        if (Dot(targetMovementDirection, targetMovementDirection) > (0.001f * 0.001f)) {
            // Just direction scaled by speed, NO delta time here
            targetVelocity = targetMovementDirection.Normalize() * mCamera.mMovementSpeed;
        }

        mCamera.UpdateMovement(targetVelocity, mDeltaTime);

        mCamera.ApplySmoothZoom(mDeltaTime);

        mCamera.UpdateViewMatrix();
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

        mRenderer.Render(mSceneTree, mCamera);
    }

    /// Process one frame.
    void AdvanceFrame() {

        ulong currentTime = SDL_GetTicks();
        if (mLastFrameTime == 0) {
             mLastFrameTime = currentTime;
        }
        mDeltaTime = (currentTime - mLastFrameTime) / 1000.0f;
        mLastFrameTime = currentTime;

        // clamp delta time to prevent huge jumps if debugging/stalling
        const float MAX_DELTA_TIME = 0.1f; 
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
        try {
             SetupScene();
        } catch (Exception e) {
             stderr.writeln("FATAL ERROR during SetupScene: ", e.msg);
             mGameIsRunning = false;
        }

        // Initial mouse warp
        if (mGameIsRunning && mWindow !is null) {
             int w, h;
             SDL_GetWindowSize(mWindow, &w, &h);
             SDL_WarpMouseInWindow(mWindow, w / 2, h / 2);
        }

        // Main loop
        while (mGameIsRunning) {
            AdvanceFrame();
        }

        writeln("Exiting main loop.");
        // Cleanup happens in destructors
    }
} // End struct GraphicsApp