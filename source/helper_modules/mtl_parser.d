module mtl_parser;

import std.file, std.string, std.conv;
import linear; // assuming vec3 is defined in your linear module

/// Structure to hold material properties from an MTL file.
struct MaterialData {
    string name;
    vec3 Ka; // Ambient reflectivity.
    vec3 Kd; // Diffuse reflectivity.
    vec3 Ks; // Specular reflectivity.
    float Ns; // Shininess exponent.
    float d;  // Opacity (1.0 = fully opaque).
}

/// Parses an MTL file to extract the material properties for the given materialName.
/// If the material is not found, defaults are returned.
MaterialData parseMTL(string mtlFilename, string materialName)
{
    MaterialData mat;
    mat.name = materialName;
    // Set reasonable defaults.
    mat.Ka = vec3(1.0f, 1.0f, 1.0f);
    mat.Kd = vec3(1.0f, 1.0f, 1.0f);
    mat.Ks = vec3(1.0f, 1.0f, 1.0f);
    mat.Ns = 0.0f;
    mat.d = 1.0f;

    string text = readText(mtlFilename);
    bool targetFound = false;
    foreach (line; text.splitLines())
    {
        auto trimmed = line.strip();
        if (trimmed.length == 0 || trimmed.startsWith("#"))
            continue;
        // Look for a new material definition.
        if (trimmed.startsWith("newmtl"))
        {
            auto tokens = trimmed.split();
            if (tokens.length >= 2 && tokens[1] == materialName)
            {
                targetFound = true;
                continue; // Found our target material.
            }
            else if (targetFound)
            {
                // We were reading our target material and now a new one started.
                break;
            }
        }
        else if (targetFound)
        {
            // Parse ambient color.
            if (trimmed.startsWith("Ka"))
            {
                auto tokens = trimmed.split();
                if (tokens.length >= 4)
                {
                    float r = tokens[1].to!float;
                    float g = tokens[2].to!float;
                    float b = tokens[3].to!float;
                    mat.Ka = vec3(r, g, b);
                }
            }
            // Parse diffuse color.
            else if (trimmed.startsWith("Kd"))
            {
                auto tokens = trimmed.split();
                if (tokens.length >= 4)
                {
                    float r = tokens[1].to!float;
                    float g = tokens[2].to!float;
                    float b = tokens[3].to!float;
                    mat.Kd = vec3(r, g, b);
                }
            }
            // Parse specular color.
            else if (trimmed.startsWith("Ks"))
            {
                auto tokens = trimmed.split();
                if (tokens.length >= 4)
                {
                    float r = tokens[1].to!float;
                    float g = tokens[2].to!float;
                    float b = tokens[3].to!float;
                    mat.Ks = vec3(r, g, b);
                }
            }
            // Parse shininess.
            else if (trimmed.startsWith("Ns"))
            {
                auto tokens = trimmed.split();
                if (tokens.length >= 2)
                {
                    mat.Ns = tokens[1].to!float;
                }
            }
            // Optionally, parse transparency/dissolve "d".
            else if (trimmed.startsWith("d"))
            {
                auto tokens = trimmed.split();
                if (tokens.length >= 2)
                {
                    mat.d = tokens[1].to!float;
                }
            }
        }
    }
    return mat;
}
