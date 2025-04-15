// In source/core/image.d
module image;

import std.stdio;
import std.file;
import std.string;
import std.conv : to, ConvException;
import std.exception; // Use enforce for errors
import std.ascii : isWhite;
import core.exception : OutOfMemoryError;

/// Simple struct for loading image/pixel data in P3 PPM format.
struct PPM {
    uint mWidth;
    uint mHeight;
    uint mMaxValue;     // Should be 255 for 8-bit
    uint mNumChannels;  // Will always be 3 for P3
    ubyte[] mPixels;    // Interleaved RGB pixel data

    /// Loads a P3 (ASCII RGB) PPM Image (8-bit depth assumed)
    /// Returns true on success, false on failure. Populates members.
    public bool load(string filename) {
        // Reset members
        mWidth = mHeight = mMaxValue = mNumChannels = 0;
        mPixels = null;

        if (!filename.exists) {
            stderr.writeln("File does not exist: ", filename);
            return false;
        }

        string fileContent;
        try {
            // Read the entire file as text (P3 is ASCII)
            fileContent = std.file.readText(filename);
        } catch (Exception e) {
             stderr.writeln("Error reading file '", filename, "' as text: ", e.msg);
             return false;
        }

        // Split content into lines
        string[] lines = fileContent.splitLines(); // Split by newline characters

        bool foundMagicNumber = false;
        bool foundDimensions  = false;
        bool foundRange       = false;
        size_t pixelIdx = 0; // Index for writing to pre-allocated mPixels
        bool headerDone = false; // Flag to know when we are reading pixel data


         try {
            // Iterate over the array of lines
            foreach(lineNum, originalLine; lines) {
                string strippedLine = originalLine.strip(); // Work with stripped line

                if (strippedLine.length == 0 || strippedLine.startsWith("#")) {
                    continue; // Skip blank lines and comments
                }

                // --- Parse Header ---
                if (!headerDone) {
                    if (!foundMagicNumber) {
                        foundMagicNumber = true;
                        if (!strippedLine.startsWith("P3")) {
                            stderr.writeln("ERROR! Not a P3 PPM image. Magic number: ", strippedLine);
                            return false;
                        }
                        mNumChannels = 3; // P3 is RGB
                        continue; // Next line
                    }

                    if (!foundDimensions) {
                        foundDimensions = true;
                        string[] dims = strippedLine.split();
                        if (dims.length < 2) { /* ... error handling ... */ return false; }
                        mWidth = dims[0].to!uint;
                        mHeight = dims[1].to!uint;
                        if (mWidth == 0 || mHeight == 0) { /* ... error handling ... */ return false; }
                        continue; // Next line
                    }

                    if (!foundRange) {
                        foundRange = true;
                        string[] rangeTok = strippedLine.split();
                        if (rangeTok.length < 1) { /* ... error handling ... */ return false; }
                        mMaxValue = rangeTok[0].to!uint;
                        if (mMaxValue == 0) { /* ... error handling ... */ return false; }
                        if (mMaxValue != 255) {
                            writeln("Warning: PPM MaxValue is ", mMaxValue, ". Loader expects 255.");
                        }

                        // Pre-allocate pixel buffer
                        size_t expectedBytes = mWidth * mHeight * mNumChannels;
                        if (expectedBytes == 0) { /* ... error handling ... */ return false; }
                        try{ mPixels.length = expectedBytes; }
                        catch (OutOfMemoryError e) { /* ... error handling ... */ return false; }

                        writeln("PPM Header: P3, W=", mWidth, ", H=", mHeight, ", Max=", mMaxValue, ", Expecting ", expectedBytes, " values.");
                        headerDone = true; // Header parsing is finished
                        continue; // Next line (first line of pixel data)
                    }
                } // End if (!headerDone)

                // --- Parse Pixel Data ---
                enforce(headerDone, "Should not be reading pixels if headerDone is false.");

                string[] tokens = strippedLine.split();
                foreach(token; tokens) {
                    if (token.length == 0) continue;

					writeln("Token: ", token); // Debugging output
					writeln("Pixel Index: ", pixelIdx); // Debugging output
					writeln("Pixel Length: ", mPixels.length); // Debugging output

                    if (pixelIdx >= mPixels.length) {
                        stderr.writeln("ERROR: Found more pixel values than expected (W*H*3). Index=", pixelIdx);
                        // Tolerate extra values at the end? Or return error? Let's error.
                        return false;
                    }
                    uint val = token.to!uint;
                    if (val > mMaxValue) val = mMaxValue;
                    if (val > 255) val = 255; // Clamp to ubyte

                    mPixels[pixelIdx++] = cast(ubyte)val;
                }
            } // end foreach line

            // --- Final Checks ---
            if (!headerDone) { // Check if header was ever completed
                 stderr.writeln("ERROR: Reached end of file processing without completing PPM header.");
                 return false;
            }
            if (pixelIdx != mPixels.length) {
                stderr.writeln("ERROR: Read only ", pixelIdx, " pixel values, expected ", mPixels.length);
                return false;
            }

            writeln("Successfully loaded P3 PPM: ", filename);
            return true; // Success!

        } catch (ConvException e) {
             stderr.writeln("Error converting number in PPM file '", filename, "': ", e.msg);
             return false;
        } catch (Exception e) {
             stderr.writeln("Error processing PPM file '", filename, "': ", e.msg);
             return false;
        }
    } // end load
} // end struct PPM