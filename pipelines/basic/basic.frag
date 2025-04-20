#version 410 core

in VS_OUT {
    vec3 FragPos;
    vec3 Normal;
} fs_in;

out vec4 fragColor;

// Light uniforms.
uniform vec3 uLightPos;
uniform vec3 uLightColor;

// Camera uniform.
uniform vec3 uViewPos;

// Material properties.
uniform vec3 uMaterialAmbient;
uniform vec3 uMaterialDiffuse;
uniform vec3 uMaterialSpecular;
uniform float uShininess;

// Object inherent color.
uniform vec3 uObjectColor;

void main()
{
    // Normalize the input normal.
    vec3 norm = normalize(fs_in.Normal);

	// Calculate the normalized normal and map from [-1, 1] to [0, 1].
    vec3 normalColor = norm * 0.5 + 0.5;
    
    // Compute the vector from the fragment to the light.
    vec3 lightDir = normalize(uLightPos - fs_in.FragPos);
    
    // Ambient component.
    vec3 ambient = uMaterialAmbient * uLightColor;
    
    // Diffuse component.
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = uMaterialDiffuse * diff * uLightColor;
    
    // Specular component.
    vec3 viewDir = normalize(uViewPos - fs_in.FragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = 0.0;
    if(diff > 0.0)
        spec = pow(max(dot(viewDir, reflectDir), 0.0), uShininess);
    vec3 specular = uMaterialSpecular * spec * uLightColor;
    
    // Combine the three components.
    vec3 lighting = ambient + diffuse + specular;
    
    // Final color: multiply the computed lighting by the object's inherent color.
    vec3 finalColor = lighting * normalColor + (uObjectColor * 0.01);
    
    fragColor = vec4(finalColor, 1.0);
}
