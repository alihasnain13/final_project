/**
 * Module for loading PNG images, specifically intended for heightmaps, using the Gamut library.
 */
module png_loader;

import gamut;
import std.stdio : writeln, stderr;
import std.exception;
import std.conv : to; // For converting PixelType enum to string

/**
 * Loads an image file using Gamut and attempts to convert it to a suitable grayscale format.
 *
 * Params:
 * filePath = Path to the image file (e.g., PNG).
 * targetType = The desired Gamut PixelType for the output image. Must be a grayscale format (l8, l16, lf32).
 *
 * Returns:
 * A Gamut Image object containing the pixel data in the target format.
 * The Image object owns the pixel data memory.
 *
 * Throws:
 * Exception if the file cannot be loaded, is invalid, or cannot be converted to the target type.
 */
Image loadHeightmap(string filePath, PixelType targetType = PixelType.l8)
{
    // --- Precondition Check ---
    enforce(targetType == PixelType.l8 ||
            targetType == PixelType.l16 ||
            targetType == PixelType.lf32,
            "Target PixelType for heightmap must be a grayscale format (l8, l16, or lf32). Got: " ~ targetType.to!string);

    Image image; // Create a Gamut Image instance

    writeln("Attempting to load heightmap from: ", filePath);

    // --- Load Image from File ---
    image.loadFromFile(filePath);
    
    // --- Error Checking after Load ---
    // Gamut uses an error state on the Image object instead of exceptions.
    if (image.isError)
    {
        // image.errorMessage() returns const(char)[], use idup to copy it safely for the exception message.
        throw new Exception("Gamut Error loading file '" ~ filePath ~ "': " ~ image.errorMessage.idup);
    }

    writeln("Successfully loaded image. Dimensions: ", image.width, "x", image.height, ". Original type: ", image.type);

    // --- Convert to Target Grayscale Format (if necessary) ---
    if (image.type != targetType)
    {
        writeln("Converting image from ", image.type, " to ", targetType);
        // convertTo returns bool indicating success/failure AND might set the error state.
        if (!image.convertTo(targetType))
        {
             // Check error status again after conversion attempt
             if(image.isError)
             {
                 throw new Exception("Gamut Error converting image '" ~ filePath ~ "' to " ~ targetType.to!string ~ ": " ~ image.errorMessage.idup);
             }
             else
             {
                 // This case might occur if conversion isn't supported but didn't set error flag.
                 throw new Exception("Gamut failed to convert image '" ~ filePath ~ "' to " ~ targetType.to!string ~ " (Reason unknown, conversion returned false).");
             }
        }
        writeln("Conversion successful. New type: ", image.type);
    }
    else
    {
        writeln("Image already in target format: ", targetType);
    }

    // --- Postcondition Checks ---
    enforce(image.isValid, "Image became invalid after load/conversion.");
    enforce(image.hasData, "Loaded image has no pixel data.");
    enforce(image.type == targetType, "Image type does not match target type after conversion.");

    writeln("Heightmap loading finished for: ", filePath);
    return image; // Return the Image struct. It owns the loaded pixel data.
}


// ============================================
// --- Example Usage / Unit Test (Optional) ---
// ============================================
// To run this test: dub test --compiler=ldc2 (or your preferred compiler)
// You'll need a test PNG file (e.g., "test_heightmap.png") accessible when running tests.
// Create a simple 8x8 grayscale PNG for testing.
version (unittest)
{
    unittest
    {
        // --- Configuration ---
        // Adjust this path if your test file is located elsewhere relative to where tests run.
        string testFilePath = "./assets/custommap.png";
        bool requiresTestFile = true; // Set to false if you want the test to pass even without the file (e.g., in CI)

        // --- Test Execution ---
        writeln("\n--- Running png_loader unittest ---");
        try
        {
            import std.file : exists;
            if (!exists(testFilePath)) {
                 string message = "Test file '" ~ testFilePath ~ "' not found.";
                 if (requiresTestFile) {
                     stderr.writeln("ERROR: ", message);
                     assert(0, message); // Fail the test if file is required
                 } else {
                     writeln("WARNING: ", message, " Skipping actual load test.");
                     writeln("--- png_loader unittest finished (skipped load) ---");
                     return; // Exit unittest successfully without loading
                 }
            }

            // Test loading as 8-bit grayscale
            writeln("\nTesting load as L8...");
            Image heightmap8 = loadHeightmap(testFilePath, PixelType.l8);
            writeln("Test load (L8) successful.");
            writeln("  Dimensions: ", heightmap8.width, "x", heightmap8.height);
            writeln("  Pixel Type: ", heightmap8.type);
            writeln("  Pitch (bytes): ", heightmap8.pitchInBytes);
            enforce(heightmap8.type == PixelType.l8, "Loaded image type mismatch L8");

            // Example: Access the first pixel's value if image is not empty
            if (heightmap8.width > 0 && heightmap8.height > 0)
            {
                // scanptr(y) gives a void* to the start of the row
                ubyte* rowPtr = cast(ubyte*)heightmap8.scanptr(0);
                // Since it's L8, the first byte is the value of the first pixel
                writeln("  First pixel value (L8): ", *rowPtr);
            }

             // Test loading as 16-bit grayscale
            writeln("\nTesting load as L16...");
            Image heightmap16 = loadHeightmap(testFilePath, PixelType.l16);
            writeln("Test load (L16) successful.");
            writeln("  Dimensions: ", heightmap16.width, "x", heightmap16.height);
            writeln("  Pixel Type: ", heightmap16.type);
            writeln("  Pitch (bytes): ", heightmap16.pitchInBytes);
            enforce(heightmap16.type == PixelType.l16, "Loaded image type mismatch L16");

            if (heightmap16.width > 0 && heightmap16.height > 0)
            {
                ushort* rowPtr = cast(ushort*)heightmap16.scanptr(0);
                writeln("  First pixel value (L16): ", *rowPtr);
            }

            writeln("\n--- png_loader unittest finished ---");

        }
        catch (Exception e)
        {
            stderr.writeln("png_loader unittest FAILED: ", e.msg);
            assert(0, "png_loader test failed: " ~ e.msg); // Make sure the test runner sees the failure
        }
    }
}

