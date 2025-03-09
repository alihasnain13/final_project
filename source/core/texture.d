/// Module to handle texture loading
module texture;

import image;

import bindbc.opengl;

/// Abstraction for generating an OpenGL texture on GPU memory from an image filename.
class Texture{
		GLuint mTextureID;
		/// Create a new texture
		this(string filename, int width, int height){

				glGenTextures(1,&mTextureID);
				glBindTexture(GL_TEXTURE_2D, mTextureID);

				PPM ppm;
				ubyte[] image_data = ppm.LoadPPMImage(filename);

				glTexImage2D(
								GL_TEXTURE_2D, 	 // 2D Texture
								0,							 // mimap level 0
								GL_RGB, 				 // Internal format for OpenGL
								width,					 // width of incoming data
								height,					 // height of incoming data
								0,							 // border (must be 0)
								GL_RGB,					 // image format
								GL_UNSIGNED_BYTE,// image data 
								image_data.ptr); // pixel array on CPU data

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
