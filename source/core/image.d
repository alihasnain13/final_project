/// Module to handle texture loading
module image;

import std.file, std.conv, std.algorithm, std.range, std.stdio, std.file;

/// Simple struct for loading image/pixel data in PPM format.
struct PPM{

		int mWidth 	= 256;
		int mHeight = 256;
		int mRange  = 255;
		ubyte[] mPixels;

		// Simple PPM image loader
		ubyte[] LoadPPMImage(string filename) {
			import std.string;
			import std.conv : to;
			import std.file : exists;
			import std.stdio;

			if (!filename.exists) {
				assert(0, "file does not exist: " ~ filename);
			}

			auto f = File(filename);

			bool foundMagicNumber = false;
			bool foundDimensions  = false;
			bool foundRange       = false;

			foreach (line; f.byLine()) {
				auto trimmed = std.string.strip(cast(string)line);
				if (trimmed.startsWith("#")) {
					continue;
				}
				if (!foundMagicNumber) {
					foundMagicNumber = true;
					if (!trimmed.startsWith("P3")) {
						writeln("ERROR! Ill formed PPM image");
					}
					continue;
				}
				if (!foundDimensions) {
					foundDimensions = true;
					auto dims = std.string.strip(cast(string)line).split;
					mWidth  = dims[0].to!int;
					mHeight = dims[1].to!int;
					continue;
				}
				if (!foundRange) {
					foundRange = true;
					mRange = std.string.strip(cast(string)line).to!int;
					continue;
				}
				
				// Process remaining lines as pixel data.
				auto tokens = std.string.strip(cast(string)line).split;
				foreach (token; tokens) {
					mPixels ~= token.to!ubyte;
				}
			}
			return mPixels;
		}


}
