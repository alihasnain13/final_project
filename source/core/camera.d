/// This represents a camera abstraction with FPS-style controls.
module camera;

// D Standard Libs
import std.math;
import std.stdio : writeln; // For optional debugging

// Project Libs
import linear; // Assumes vec3, mat4, MatrixMakeIdentity, MatrixMakeLookAt, MatrixMakePerspective, MatrixMakeTranslation, Normalize, Cross, Dot etc.
// import bindbc.opengl;

// Helper for degrees to radians
private float ToRadians(float degrees) { immutable float PI = 3.14159265358979323846; return degrees * (PI / 180.0f); }
// Helper for clamping
private float clamp(float val, float minVal, float maxVal) {
     return fmax(minVal, fmin(val, maxVal));
}
private vec3 lerp(vec3 start, vec3 end, float factor) {
    return start + factor * (end - start);
}

private mat4 MatrixMakeLookAt(vec3 eye, vec3 target, vec3 worldUp) {
    // 1. Calculate camera's local coordinate axes in world space
    vec3 zaxis = (eye - target).Normalize();         // The backward vector (+Z camera space)
    vec3 xaxis = Cross(worldUp, zaxis).Normalize();  // The right vector (+X camera space)
    vec3 yaxis = Cross(zaxis, xaxis);                // The up vector (+Y camera space, already normalized)

    // 2. Create the Rotation matrix part of the view matrix
    // This matrix transforms world coordinates to align with camera axes.
    // Rows = Camera axes in world space
    // (Assuming mat4 constructor takes elements row-by-row, OR use transpose if it takes columns)
    // Check your linear.d mat4 constructor/conventions! This assumes row-major construction.
    mat4 rotation = mat4(
        xaxis.x, xaxis.y, xaxis.z, 0.0f, // Row 1: Camera Right vector
        yaxis.x, yaxis.y, yaxis.z, 0.0f, // Row 2: Camera Up vector
        zaxis.x, zaxis.y, zaxis.z, 0.0f, // Row 3: Camera Backward vector
        0.0f,    0.0f,    0.0f,    1.0f
    );

    // 3. Create the Translation matrix part
    // This moves the world so the camera position (eye) is at the origin.
    mat4 translation = MatrixMakeTranslation(-eye); // Assumes this function exists

    // 4. View Matrix = Rotation * Translation
    // Apply translation first, then rotation to bring world coords into view space.
    return rotation * translation;
}

// --- World Up Vector (Module Constant) ---
const vec3 WORLD_UP = vec3(0.0f, 1.0f, 0.0f);

/// Camera abstraction using Euler angles (Yaw/Pitch) for orientation.
class Camera {
    // --- Matrices ---
    mat4 mViewMatrix;
    mat4 mProjectionMatrix;

    // --- Position & Orientation ---
    vec3 mEyePosition;

    // Camera local axes (calculated from Yaw/Pitch)
    vec3 mUpVector;         // Camera's current local up direction
    vec3 mForwardVector;    // Direction camera is looking
    vec3 mRightVector;      // Camera's current local right direction

    // Orientation angles (in degrees)
    float mYaw = -105.0f;    // Yaw left/right. -90 points down -Z initially.
    float mPitch = 0.0f;    // Pitch up/down. 0 is horizontal.

    // --- Camera Parameters ---
    float mMovementSpeed = 200.0f;   // World units per second (Used in graphics_app.d) - TUNE THIS!
    float mMouseSensitivity = 0.1f; // Adjust mouse look sensitivity - TUNE THIS!
    float mPanSensitivity = 0.1f;  // Adjust panning speed (Units per pixel moved * dt?) - TUNE THIS!

    // Camera Parameters (Zoom Specifics)
    float mZoomSensitivity = 50.0f; // Adjust scroll zoom speed (Units per scroll tick * dt?) - TUNE THIS!
    float mTargetZoomDisplacement = 0.0f; // How much we *want* to move forward/backward
    float mZoomSmoothingFactor = 15.0f; // How fast we approach the target (higher=faster) - TUNE THIS!

    // --- Smooth Movement Members ---
    private vec3 mCurrentVelocity = vec3(0.0f); // Camera's actual velocity this frame
    private float mMovementSmoothingFactor = 10.0f; // Higher = faster accel/decel, less smooth. TUNE THIS!

    // Mouse look state
    private bool mFirstMouse = true; // Prevent jump on first mouse input
    private int mLastMouseX = 0;
    private int mLastMouseY = 0;

    /// Constructor for a camera
    this() {
        writeln("Initializing Camera...");
        mViewMatrix = MatrixMakeIdentity();
        // Set projection using helper (assuming initial 1280x720 aspect)
        UpdateProjectionMatrix(1280.0f / 720.0f);
        // Initial Camera position
        mEyePosition = vec3(0.0f, 20.0f, 50.0f);
        // Calculate initial direction vectors based on default Yaw/Pitch
        UpdateCameraVectors();
        // Calculate initial view matrix
        UpdateViewMatrix();
        writeln("Camera Initialized: Pos=", mEyePosition, " Yaw=", mYaw, " Pitch=", mPitch);
    }

    /// Position the eye of the camera in the world
    void SetCameraPosition(vec3 v) {
        mEyePosition = v;
        // View Matrix updated once per frame in GraphicsApp::Update
    }
    /// Position the eye of the camera in the world
    void SetCameraPosition(float x, float y, float z) {
        mEyePosition = vec3(x, y, z);
        // View Matrix updated once per frame in GraphicsApp::Update
    }

    /// Builds the look-at view matrix using camera's current state.
    /// Assumes linear.d provides MatrixMakeLookAt(eye, target, up).
    mat4 BuildLookAtMatrix() {
         vec3 target = mEyePosition + mForwardVector;
         // Use camera's local mUpVector calculated from yaw/pitch
         // If MatrixMakeLookAt doesn't exist or uses WORLD_UP instead,
         // you'll need to manually construct the matrix using mRightVector, mUpVector, -mForwardVector
         // and the translation -mEyePosition.
         return MatrixMakeLookAt(mEyePosition, target, mUpVector);
    }

    /// Updates the camera's View matrix based on its current state.
    /// Call this ONCE per frame AFTER position/orientation updates.
    mat4 UpdateViewMatrix() {
        mViewMatrix = BuildLookAtMatrix();
        return mViewMatrix;
    }

    /// Updates Projection Matrix (e.g., on window resize or FOV change)
    void UpdateProjectionMatrix(float aspectRatio, float fovDegrees = 60.0f, float nearPlane = 0.1f, float farPlane = 2000.0f) {
         if (aspectRatio <= 0.0f) aspectRatio = 1.0f;
         mProjectionMatrix = MatrixMakePerspective(fovDegrees.ToRadians(), aspectRatio, nearPlane, farPlane);
         // writeln("Projection Matrix Updated: Aspect=", aspectRatio, " FOV=", fovDegrees);
    }

    /// Processes raw mouse X/Y screen coordinates to update camera angles.
    void MouseLook(int mouseX, int mouseY) {
        if (mFirstMouse) {
            mLastMouseX = mouseX; mLastMouseY = mouseY; mFirstMouse = false; return;
        }
        float deltaX = cast(float)(mouseX - mLastMouseX) * mMouseSensitivity;
        float deltaY = cast(float)(mLastMouseY - mouseY) * mMouseSensitivity; // Inverted Y
        mLastMouseX = mouseX; mLastMouseY = mouseY;

        mYaw += deltaX;
        mPitch += deltaY;
        mPitch = clamp(mPitch, -89.0f, 89.0f); // Use clamp helper

        // Update direction vectors based on new angles
        UpdateCameraVectors();
        // View matrix is updated once per frame in GraphicsApp::Update
    }
    

    /// Helper to recalculate Forward, Right, and Up vectors from Yaw and Pitch.
    private void UpdateCameraVectors() {
        vec3 direction;
        direction.x = cos(mYaw.ToRadians()) * cos(mPitch.ToRadians());
        direction.y = sin(mPitch.ToRadians());
        direction.z = sin(mYaw.ToRadians()) * cos(mPitch.ToRadians());
        mForwardVector = direction.Normalize();
        mRightVector = Cross(mForwardVector, WORLD_UP).Normalize(); // Cross with WORLD_UP to find Right
        mUpVector = Cross(mRightVector, mForwardVector).Normalize(); // Cross Right and Forward to find Camera's Up
    }

    // --- Movement Method ---
    /// Applies a pre-calculated velocity vector (units per frame).
    void Move(vec3 velocity) {
        mEyePosition = mEyePosition + velocity; // Use explicit assignment
    }

    void UpdateMovement(vec3 targetVelocity, float dt) {
        // Interpolate current velocity towards the target velocity
        // The factor determines how much closer we get each frame (adjust mMovementSmoothingFactor)
        float blendFactor = clamp(mMovementSmoothingFactor * dt, 0.0f, 1.0f); // Clamp factor between 0 and 1
        mCurrentVelocity = lerp(mCurrentVelocity, targetVelocity, blendFactor);

        // Snap to zero if velocity is very small to prevent drifting
        if (Dot(mCurrentVelocity, mCurrentVelocity) < (0.01f * 0.01f)) {
            mCurrentVelocity = vec3(0.0f);
        }

        // Apply the *current smoothed velocity* (scaled by time) to the position
        if (Dot(mCurrentVelocity, mCurrentVelocity) > 0.0f) { // Check lengthSquared again
             mEyePosition = mEyePosition + (mCurrentVelocity * dt);
        }
    }

    // --- Zoom Function ---
    /// Applies scroll-based movement along the forward vector.
    void Zoom(float scrollAmount) { // scrollAmount is raw SDL wheel delta (+1/-1)
        mTargetZoomDisplacement += scrollAmount * mZoomSensitivity;
    }

    void ApplySmoothZoom(float dt) {
         if (abs(mTargetZoomDisplacement) > 0.001f) {
              float zoomStep = mTargetZoomDisplacement * mZoomSmoothingFactor * dt;
              // ... (clamp step, apply movement, reduce target - same as before) ...
              if (abs(zoomStep) > abs(mTargetZoomDisplacement)) { zoomStep = mTargetZoomDisplacement; }
              mEyePosition = mEyePosition + (mForwardVector * zoomStep); // Apply step
              mTargetZoomDisplacement -= zoomStep;
              if (abs(mTargetZoomDisplacement) < 0.001f) { mTargetZoomDisplacement = 0.0f; }
         }
    }

    // --- Pan Function ---
    /// Applies panning movement based on raw mouse deltas.
    void Pan(float dx, float dy) {
         // Apply sensitivity
         vec3 rightMove = mRightVector * dx * mPanSensitivity;
         vec3 upMove = mUpVector * dy * mPanSensitivity;
         mEyePosition = mEyePosition - rightMove; // Use explicit assignment
         mEyePosition = mEyePosition + upMove;    // Use explicit assignment
    }

} // End class Camera