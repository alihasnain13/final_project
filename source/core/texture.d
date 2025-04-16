/// Module to handle texture loading (Using Fixed PPM Loader)
module texture;

// *** ADD THESE IMPORTS ***
import std.stdio;
import std.conv; // Needed for to!string
import std.exception;
// *** END IMPORTS ***

import image; // Use the local image.d with the fixed PPM loader
import bindbc.opengl;


/// Abstraction for generating an OpenGL texture on GPU memory from a PPM image filename.
class Texture {
    GLuint mTextureID;
    // *** DECLARE MEMBER VARIABLES ***
    int mWidth;
    int mHeight;
    // *** END DECLARATIONS ***

    /// Create a new texture from a PPM file
    /// Throws: Exception on loading or OpenGL errors
    this(string filename) { // Constructor without width/height parameters
        mTextureID = 0; // Initialize
        mWidth = 0;     // Initialize
        mHeight = 0;    // Initialize
        writeln("--- Loading Texture ---"); // Start marker
        writeln("  Filename: ", filename);

        PPM ppm;
        ubyte[] imageData;

        try {
            imageData = ppm.LoadPPMImage(filename); // Uses fixed PPM loader
            mWidth = ppm.mWidth; // Get ACTUAL width from PPM
            mHeight = ppm.mHeight; // Get ACTUAL height from PPM
            writeln("  PPM Load SUCCESS. Dimensions: ", mWidth, "x", mHeight);
        } catch (Exception e) {
            writeln("  PPM Load FAILED!");
            throw new Exception("Failed to load PPM texture '" ~ filename ~ "': " ~ e.msg);
        }

        // --- Generate OpenGL Texture ---
        glGenTextures(1, &mTextureID);
        if (mTextureID == 0) {
            writeln("  glGenTextures FAILED!");
            throw new Exception("glGenTextures failed for texture: " ~ filename);
        }
        writeln("  glGenTextures SUCCESS. ID: ", mTextureID);

        glBindTexture(GL_TEXTURE_2D, mTextureID);

        GLenum internalFormat = GL_RGB8;
        GLenum dataFormat = GL_RGB;

        glTexImage2D(
            GL_TEXTURE_2D, 0, cast(GLint)internalFormat,
            mWidth, mHeight, 0, // Use member mWidth, mHeight
            dataFormat, GL_UNSIGNED_BYTE,
            imageData.ptr
        );
        GLenum error = glGetError();
        if (error != GL_NO_ERROR) {
            writeln("  glTexImage2D FAILED! OpenGL Error: ", error);
            glDeleteTextures(1, &mTextureID); mTextureID = 0;
            // *** Use to!string from std.conv ***
            throw new Exception("glTexImage2D failed for PPM texture '" ~ filename ~ "'. OpenGL Error: " ~ error.to!string);
        }
        writeln("  glTexImage2D SUCCESS.");

        // --- Set Texture Parameters ---
        glGenerateMipmap(GL_TEXTURE_2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

        glBindTexture(GL_TEXTURE_2D, 0);
        writeln("--- Texture Loaded Successfully ---");
    }

    // Add destructor if not already present from previous steps
    ~this() {
        if (mTextureID != 0) {
            writeln("Deleting Texture ID: ", mTextureID);
            glDeleteTextures(1, &mTextureID);
        }
     }
}