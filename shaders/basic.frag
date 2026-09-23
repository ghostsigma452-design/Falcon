#version 450

layout(location = 0) in vec3 fragWorldPos;
layout(location = 1) in vec3 fragNormal;

layout(location = 0) out vec4 outColor;

layout(push_constant) uniform PushBlock {
    layout(offset = 64) vec3 albedo;
    float metallic;
    float roughness;
    float ao;
} pbr;

void main() {
    vec3 N = normalize(fragNormal);
    
    // Directional light pointing down and towards the scene
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.8));
    
    // Basic Diffuse (Lambert) + Ambient check
    float diff = max(dot(N, lightDir), 0.0);
    vec3 ambient = vec3(0.1) * pbr.albedo;
    vec3 diffuse = diff * pbr.albedo;

    vec3 finalColor = ambient + diffuse;
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));

    outColor = vec4(finalColor, 1.0);
}