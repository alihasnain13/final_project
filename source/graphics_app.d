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

    // --- Input State for Camera ---
    float moveForward = 0.0f; // +1 / -1 based on key press
    float moveRight = 0.0f;   // +1 / -1 based on key press
    float moveUp = 0.0f;      // +1 / -1 based on key press
    float mScrollDelta = 0.0f;// Accumulated scroll wheel value this frame
    bool mIsPanning = false;  // Is middle mouse button held down?
    int mLastPanX = 0;        // Last mouse X during pan
    int mLastPanY = 0;        // Last mouse Y during pan

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
                     // Optional: Stop movement when key is released
                     // if (event.key.keysym.sym == SDLK_UP && moveForward > 0) { moveForward = 0.0f; }
                     // else if (event.key.keysym.sym == SDLK_DOWN && moveForward < 0) { moveForward = 0.0f; }
                     // ... etc for other keys ...
                     break;

                // --- MOUSE WHEEL for ZOOM ---
                case SDL_MOUSEWHEEL:
                    if (event.wheel.y != 0) {
                         // Call Camera::Zoom directly with the scroll value.
                         // Positive y scrolls away (zoom out), Negative y scrolls toward (zoom in).
                         // Pass negative value to make scroll "up/away" zoom out.
                         // Sensitivity is handled inside Camera::Zoom.
                         mCamera.Zoom( -event.wheel.y ); // <<< CALL CAMERA ZOOM
                         // writeln("Zoom Event: y=", event.wheel.y); // Debug log
                    }
                    break;

                 // --- MOUSE BUTTON for PANNING ---
                case SDL_MOUSEBUTTONDOWN:
                    // Start panning if middle button is pressed AND not already panning
                    if (event.button.button == SDL_BUTTON_MIDDLE && !mIsPanning) {
                        mIsPanning = true;
                        // Store the mouse position where panning *started*
                        SDL_GetMouseState(&mLastPanX, &mLastPanY);
                        // Optional: Hide cursor and use relative mode for better panning feel
                        SDL_SetRelativeMouseMode(SDL_TRUE); // Grab mouse
                        SDL_ShowCursor(SDL_FALSE);          // Hide cursor
                        writeln("Panning Started");
                    }
                    break;
                case SDL_MOUSEBUTTONUP:
                     // Stop panning if middle button is released AND we were panning
                     if (event.button.button == SDL_BUTTON_MIDDLE && mIsPanning) {
                        mIsPanning = false;
                        // Optional: Restore cursor and input mode
                        SDL_SetRelativeMouseMode(SDL_FALSE); // Release mouse
                        SDL_ShowCursor(SDL_TRUE);           // Show cursor
                        writeln("Panning Stopped");
                    }
                    break;

                // --- MOUSE MOTION --- Handles Look OR Pan
                case SDL_MOUSEMOTION:
                    // Get current absolute position (needed for non-relative mode look)
                    int currentMouseX = event.motion.x;
                    int currentMouseY = event.motion.y;

                    if (mIsPanning) {
                         // If panning, use the RELATIVE motion provided by the event
                         // This works correctly even if the cursor is hidden/grabbed
                         int panDeltaX = event.motion.xrel;
                         int panDeltaY = event.motion.yrel; // Relative Y might have different sign convention? Test needed. Usually positive=down.

                         // Call Camera::Pan if there was movement
                         if (panDeltaX != 0 || panDeltaY != 0) {
                             // Pass raw relative deltas; sensitivity handled inside Camera::Pan
                             // Ensure Camera::Pan uses dy correctly (e.g., adds to Up vector if dy>0)
                             mCamera.Pan(cast(float)panDeltaX, cast(float)panDeltaY); // <<< CALL CAMERA PAN
                             // writeln("Pan Motion Rel: dx=", panDeltaX, " dy=", panDeltaY); // Debug
                         }
                         // No need to update mLastPanX/Y when using relative motion
                    } else {
                        // If not panning, perform standard mouse look using absolute position
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
            uint patchResolution = 128; // Adjust as needed (e.g., 32, 64, 128)
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

        // Uniforms needed ONLY by standard (HiRes) LIT pipeline/material
        writeln("Adding lighting uniforms to HiRes material...");
        // mTerrainMaterialHiRes.AddUniform(new Uniform("sampler1", "sampler2D", null));
        // mTerrainMaterialHiRes.AddUniform(new Uniform("sampler2", "sampler2D", null));
        // mTerrainMaterialHiRes.AddUniform(new Uniform("sampler3", "sampler2D", null));
        // mTerrainMaterialHiRes.AddUniform(new Uniform("sampler4", "sampler2D", null));
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
        // If no keys are pressed, targetVelocity remains zero, causing deceleration.

        // --- Update Camera Movement (Smoothing happens inside) ---
        mCamera.UpdateMovement(targetVelocity, mDeltaTime); // <<< CALL NEW METHOD

        // --- Apply Smooth Zoom ---
        mCamera.ApplySmoothZoom(mDeltaTime); // <<< Keep this call

        // --- Update Camera View Matrix ---
        mCamera.UpdateViewMatrix(); // AFTER all position/orientation updates
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