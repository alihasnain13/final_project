/**
 * Module for loading PNG images, specifically intended for heightmaps, using the Gamut library.
 */
module png_loader;

import gamut;
import std.stdio : writeln, stderr;
import std.exception;
import std.conv : to; 

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
    
    // Gamut uses an error state on the Image object instead of exceptions.
    if (image.isError)
    {
        // image.errorMessage() returns const(char)[], use idup to copy it safely for the exception message.
        throw new Exception("Gamut Error loading file '" ~ filePath ~ "': " ~ image.errorMessage.idup);
    }

    writeln("Successfully loaded image. Dimensions: ", image.width, "x", image.height, ". Original type: ", image.type);

    if (image.type != targetType)
    {
        writeln("Converting image from ", image.type, " to ", targetType);
        // convertTo returns bool indicating success/failure AND might set the error state.
        if (!image.convertTo(targetType))
        {
             if(image.isError)
             {
                 throw new Exception("Gamut Error converting image '" ~ filePath ~ "' to " ~ targetType.to!string ~ ": " ~ image.errorMessage.idup);
             }
             else
             {
                 throw new Exception("Gamut failed to convert image '" ~ filePath ~ "' to " ~ targetType.to!string ~ " (Reason unknown, conversion returned false).");
             }
        }
        writeln("Conversion successful. New type: ", image.type);
    }
    else
    {
        writeln("Image already in target format: ", targetType);
    }

    enforce(image.isValid, "Image became invalid after load/conversion.");
    enforce(image.hasData, "Loaded image has no pixel data.");
    enforce(image.type == targetType, "Image type does not match target type after conversion.");

    writeln("Heightmap loading finished for: ", filePath);
    return image; // Return the Image struct. It owns the loaded pixel data.
}
