/// Module to handle texture loading
module texture;

import image;
import std.stdio;

import bindbc.opengl;

/// Abstraction for generating an OpenGL texture on GPU memory from an image filename.
class Texture{
		GLuint mTextureID;
		uint mWidth;  // Store actual texture dimensions
    	uint mHeight;
		/// Create a new texture
		this(string filename, int width, int height){

				glGenTextures(1,&mTextureID);
				glBindTexture(GL_TEXTURE_2D, mTextureID);

				PPM ppm;
				// Call the new load function, check return value
				if (!ppm.load(filename)) {
					// Handle error - e.g., create a fallback texture or throw
					writeln("Error loading texture '", filename, "'. Cannot create OpenGL texture.");
					// Optional: create a small dummy texture (e.g., 1x1 white)
					// Optional: Throw exception
					glDeleteTextures(1, &mTextureID); // Clean up generated texture ID
					mTextureID = 0; // Mark as invalid
					throw new Exception("Failed to load texture file: " ~ filename);
					// return; // Or just return if constructor failure is handled differently
				}

				// Ensure it was loaded as RGB (P3 loader guarantees this)
				if (ppm.mNumChannels != 3) {
					writeln("Loaded PPM '", filename, "' has ", ppm.mNumChannels, " channels, expected 3 for RGB texture.");
					glDeleteTextures(1, &mTextureID);
					mTextureID = 0;
					throw new Exception("Loaded PPM is not RGB: " ~ filename);
				}

				// Store loaded dimensions
				mWidth = ppm.mWidth;
				mHeight = ppm.mHeight;

				glTexImage2D(
								GL_TEXTURE_2D, 	 // 2D Texture
								0,							 // mimap level 0
								GL_RGB, 				 // Internal format for OpenGL
								width,					 // width of incoming data
								height,					 // height of incoming data
								0,							 // border (must be 0)
								GL_RGB,					 // image format
								GL_UNSIGNED_BYTE,// image data 
								ppm.mPixels.ptr); // pixel array on CPU data

				glGenerateMipmap(GL_TEXTURE_2D);

				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);	
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,GL_LINEAR);	
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,GL_REPEAT);	
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,GL_REPEAT);	

//				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,GL_LINEAR);	
//				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,GL_LINEAR);	
//				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,GL_CLAMP_TO_BORDER);	
//				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,GL_CLAMP_TO_BORDER);	
		}

}
