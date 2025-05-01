/// Module to handle texture loading
module image;

import std.file, std.conv, std.algorithm, std.range, std.stdio, std.file, std.string;

/// Simple struct for loading image/pixel data in PPM format.
struct PPM {

    int mWidth = 0;   // Default to 0
    int mHeight = 0;  // Default to 0
    int mRange = 255; // Default range
    ubyte[] mPixels;


    ubyte[] LoadPPMImage(string filename) {
        writeln("Attempting to load PPM: ", filename);
        if (!filename.exists) {
            throw new Exception("PPM file does not exist: " ~ filename);
        }

        mPixels.length = 0; // Clear previous pixels
        mWidth = 0;
        mHeight = 0;

        auto f = File(filename);

        int lineNum = 0;
        int headerStage = 0; // 0=Magic, 1=Dimensions, 2=Range, 3=Pixels

        foreach (lineRaw; f.byLineCopy()) { // Use byLineCopy to get mutable strings
            lineNum++;
            string line = lineRaw.strip(); // Remove leading/trailing whitespace

            if (line.startsWith("#") || line.length == 0) { // Skip comments and empty lines
                continue;
            }

            try {
                if (headerStage == 0) { // Expect Magic Number (P3)
                    if (line == "P3") {
                        headerStage = 1;
                    } else {
                        throw new Exception("Invalid PPM magic number (expected P3): " ~ line);
                    }
                } else if (headerStage == 1) { // Expect Dimensions (Width Height)
                    string[] dims = line.split(); // Split by whitespace
                    if (dims.length < 2) {
                        throw new Exception("Invalid dimensions line: " ~ line);
                    }

                    mWidth = dims[0].to!int;
                    mHeight = dims[1].to!int;
                    if (mWidth <= 0 || mHeight <= 0) {
                         throw new Exception("Invalid dimensions found: " ~ mWidth.to!string ~ "x" ~ mHeight.to!string);
                    }
                    writeln("  PPM Dimensions: ", mWidth, "x", mHeight);
                    headerStage = 2;
                } else if (headerStage == 2) { // Expect Max Color Range
                    mRange = line.to!int;
                     if (mRange <= 0 || mRange > 255) { // Support only 8-bit range for simplicity
                         throw new Exception("Invalid or unsupported PPM color range (expected 1-255): " ~ mRange.to!string);
                     }
                    writeln("  PPM Max Range: ", mRange);

                    mPixels.reserve(mWidth * mHeight * 3);
                    headerStage = 3;
                } else if (headerStage == 3) { // Expect Pixel Data

                    string[] tokens = line.split; // Split by whitespace
                    foreach (token; tokens) {
                        if (token.length > 0) { // Ensure token is not empty
                            mPixels ~= token.to!ubyte; // Convert number string to ubyte
                        }
                    }
                }
            } catch (ConvException e) {
                 throw new Exception("PPM parsing error on line " ~ lineNum.to!string ~ " (converting '" ~ line ~ "'): " ~ e.msg);
            } catch (Exception e) { // Catch other potential errors like index out of bounds
                 throw new Exception("PPM parsing error on line " ~ lineNum.to!string ~ ": " ~ e.msg);
            }
        } 

        // Final checks
        if (headerStage < 3) {
             throw new Exception("PPM file ended prematurely (missing header fields).");
        }
        if (mPixels.length != mWidth * mHeight * 3) {
             throw new Exception("Incorrect number of pixels loaded. Expected " ~ (mWidth*mHeight*3).to!string ~ ", got " ~ mPixels.length.to!string);
        }

        writeln("PPM loaded successfully: ", filename);

        return mPixels;
    }
}