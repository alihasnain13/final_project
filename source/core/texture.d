/// Module to handle texture loading (Supports PPM and PNG/Gamut)
module texture;

// D Standard Libs
import std.stdio;
import std.exception;
import std.conv : to;
import std.path : extension; // To check file extension
import std.string; // To compare extension case-insensitively

// Project Libs
import image;         // Your PPM struct and LoadPPMImage function
import png_loader;    // Provides loadHeightmap (or similar Gamut loader)
import gamut;         // Gamut's Image type
import bindbc.opengl; // OpenGL functions

/// Abstraction for generating an OpenGL texture on GPU memory from an image file.
/// Supports PPM (via internal loader) and other formats like PNG (via Gamut).
class Texture {
    GLuint mTextureID = 0;
    int mWidth = 0;
    int mHeight = 0;
    // Store GL formats determined during loading
    GLenum mInternalFormat = GL_RGB8; // Default guess
    GLenum mDataFormat = GL_RGB;      // Default guess
    GLenum mDataType = GL_UNSIGNED_BYTE; // Default guess

    /// Create a new texture by loading from file. Determines loader based on extension.
    /// Throws: Exception on loading or OpenGL errors.
    this(string filename) {
        writeln("--- Loading Texture ---");
        writeln("  Filename: ", filename);

        // Keep image data in scope until glTexImage2D is called
        ubyte[] ppmPixelData; // Only used if PPM
        Image gamutImage;    // Only used if Gamut
        void* dataPtr = null; // Pointer to the raw pixel data

        string ext = "";
        try { ext = extension(filename).toLower(); } catch (Exception e) { /* Handle path errors if needed */ }

        try {
            if (ext == ".ppm") {
                // --- Load PPM ---
                writeln("  Detected .ppm, using PPM loader.");
                PPM ppm;
                ppmPixelData = ppm.LoadPPMImage(filename); // Throws on error
                mWidth = ppm.mWidth;
                mHeight = ppm.mHeight;
                // PPM P3 is always RGB, 8-bit per channel
                mInternalFormat = GL_RGB8; // Store 8 bits per component
                mDataFormat = GL_RGB;      // Incoming data format is RGB
                mDataType = GL_UNSIGNED_BYTE; // Data type is bytes
                dataPtr = ppmPixelData.ptr; // Point to PPM data
                writeln("  PPM Load SUCCESS. Dimensions: ", mWidth, "x", mHeight);

            } else if (ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".tga" || ext == ".bmp") { // Add other Gamut types if needed
                // --- Load with Gamut (e.g., PNG, JPG, etc.) ---
                writeln("  Detected ", ext, ", using Gamut loader.");
                // Use a generic Gamut loading function. loadImageRGBA forces RGBA8.
                // If your heightmap needs to be single channel (L8/L16), you might need
                // a different loading function or check the type after loading.
                // Let's assume RGBA8 is acceptable for now for all non-PPM.
                gamutImage = loadImageRGBA(filename); // Use helper (defined below or import)
                mWidth = gamutImage.width;
                mHeight = gamutImage.height;

                // Determine GL formats from Gamut type loaded (should be RGBA8 here)
                 switch(gamutImage.type) {
                     case PixelType.rgba8:
                         mInternalFormat = GL_RGBA8; mDataFormat = GL_RGBA; mDataType = GL_UNSIGNED_BYTE;
                         break;
                     case PixelType.rgb8: // If loadImageRGBA failed to force RGBA
                         mInternalFormat = GL_RGB8; mDataFormat = GL_RGB; mDataType = GL_UNSIGNED_BYTE;
                         break;
                    // Add L8 case if loading heightmaps as single channel
                    // case PixelType.l8:
                    //     mInternalFormat = GL_R8; mDataFormat = GL_RED; mDataType = GL_UNSIGNED_BYTE; break;
                     default:
                         throw new Exception("Unsupported pixel type loaded via Gamut: " ~ gamutImage.type.to!string);
                 }
                 // Get data pointer (Gamut image manages its memory)
                 // Assuming data is contiguous after load. Check image.layoutConstraints if issues.
                 dataPtr = gamutImage.scanptr(0);
                 writeln("  Gamut Load SUCCESS. Type: ", gamutImage.type, " Dimensions: ", mWidth, "x", mHeight);

            } else {
                 throw new Exception("Unsupported texture file extension: " ~ ext ~ ". Only .ppm and Gamut-supported types (e.g., .png) allowed.");
            }

        } catch (Exception e) {
            writeln("  Texture Load FAILED!");
            // Re-throw exception with context
            throw new Exception("Failed to load texture '" ~ filename ~ "': " ~ e.msg);
        }

        // Ensure we have valid dimensions and data pointer
        if (mWidth <= 0 || mHeight <= 0) {
             throw new Exception("Texture has invalid dimensions ("~mWidth.to!string~"x"~mHeight.to!string~") for: " ~ filename);
        }
        if (dataPtr is null) {
              throw new Exception("Failed to get valid pixel data pointer for texture: " ~ filename);
        }


        // --- Generate OpenGL Texture ---
        try {
             // Set byte alignment to 1 before uploading - safest for various row sizes
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

            glGenTextures(1, &mTextureID);
            if (mTextureID == 0) { throw new Exception("glGenTextures failed"); }
            writeln("  glGenTextures SUCCESS. ID: ", mTextureID);

            glBindTexture(GL_TEXTURE_2D, mTextureID);

            // Upload texture data using determined formats and data type
            glTexImage2D(
                GL_TEXTURE_2D, 0, cast(GLint)mInternalFormat,
                mWidth, mHeight, 0,
                mDataFormat, mDataType,
                dataPtr // Use the pointer obtained from either PPM or Gamut
            );
            // Check for errors *after* the call
            GLenum error = glGetError();
            if (error != GL_NO_ERROR) { throw new Exception("glTexImage2D failed! OpenGL Error: " ~ error.to!string); }
            writeln("  glTexImage2D SUCCESS.");

            // --- Set Texture Parameters ---
            glGenerateMipmap(GL_TEXTURE_2D); // Generate mipmaps
            // Set filtering: Trilinear is good quality
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            // Set wrapping: Repeat is common for terrain tiles
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

            glBindTexture(GL_TEXTURE_2D, 0); // Unbind
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4); // Reset alignment to default
            writeln("--- Texture Loaded Successfully ---");

        } catch (Exception e) {
             glPixelStorei(GL_UNPACK_ALIGNMENT, 4); // Reset alignment on error too
             // Clean up texture ID if generated before error
             if (mTextureID != 0) { glDeleteTextures(1, &mTextureID); mTextureID = 0; }
             throw new Exception("OpenGL texture creation failed for '" ~ filename ~ "': " ~ e.msg);
        }
    } // End constructor

    /// Destructor
    ~this() {
        if (mTextureID != 0) {
            writeln("Deleting Texture ID: ", mTextureID);
            // Make sure an OpenGL context is current when deleting! Usually true at shutdown.
            glDeleteTextures(1, &mTextureID);
        }
    }
} // End class Texture


/// Helper function to load image via Gamut, forcing RGBA8 format.
/// Define this here or import from png_loader / another helper module.
Image loadImageRGBA(string filePath) {
     Image image;
     // Force RGBA8, Non-premultiplied Alpha
     image.loadFromFile(filePath, LOAD_RGB | LOAD_ALPHA | LOAD_8BIT | LOAD_NO_PREMUL);
     if (image.isError) {
         throw new Exception("loadImageRGBA failed for '" ~ filePath ~ "': " ~ image.errorMessage.idup);
     }
     // Optional: Enforce the type if needed
     // enforce(image.type == PixelType.rgba8, "loadImageRGBA failed to force RGBA8 type.");
     return image;
}
// TODO: Consider adding loadImageL8 for single-channel heightmaps if needed.
// Image loadImageL8(string filePath) { ... image.loadFromFile(filePath, LOAD_GREYSCALE | LOAD_8BIT); ... }