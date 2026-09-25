#version 450

// Inputs from Vertex Shader
layout(location = 0) in vec3 fragWorldPos;
layout(location = 1) in vec3 fragNormal;

layout(location = 0) out vec4 outColor;

// Push Constants (Packed 100 bytes matching Nim's exact stream)
layout(push_constant) uniform PBRPushBlock {
    layout(offset = 0)  mat4 model;       // Offset 0   (64 bytes)
    layout(offset = 64) vec3 cameraPos;   // Offset 64  (12 bytes)
    layout(offset = 76) float albedoR;    // Offset 76  (4 bytes)
    layout(offset = 80) float albedoG;    // Offset 80  (4 bytes)
    layout(offset = 84) float albedoB;    // Offset 84  (4 bytes)
    layout(offset = 88) float metallic;   // Offset 88  (4 bytes)
    layout(offset = 92) float roughness;  // Offset 92  (4 bytes)
    layout(offset = 96) float ao;         // Offset 96  (4 bytes)
} push;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    return num / max(PI * denom * denom, 0.0001);
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    return GeometrySchlickGGX(max(dot(N, V), 0.0), roughness) * 
           GeometrySchlickGGX(max(dot(N, L), 0.0), roughness);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void main() {
    vec3 N = normalize(fragNormal);
    vec3 V = normalize(push.cameraPos - fragWorldPos);

    // Reconstruct albedo vector from explicit float offsets
    vec3 albedo = vec3(push.albedoR, push.albedoG, push.albedoB);

    float metallic  = clamp(push.metallic, 0.0, 1.0);
    float roughness = clamp(push.roughness, 0.05, 1.0);
    float ao        = push.ao;

    vec3 F0 = mix(vec3(0.04), albedo, metallic);

    // Point Light
    vec3 lightPos = vec3(2.0, 4.0, 3.0);
    vec3 L = normalize(lightPos - fragWorldPos);
    vec3 H = normalize(V + L);

    float dist = length(lightPos - fragWorldPos);
    float attenuation = 1.0 / (dist * dist);
    vec3 radiance = vec3(25.0) * attenuation;

    // BRDF Calculations
    float NDF = DistributionGGX(N, H, roughness);   
    float G   = GeometrySmith(N, V, L, roughness);      
    vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);
        
    float NdotV = max(dot(N, V), 0.0001);
    float NdotL = max(dot(N, L), 0.0001);
    vec3 specular = (NDF * G * F) / (4.0 * NdotV * NdotL);

    vec3 kD = (vec3(1.0) - F) * (1.0 - metallic);     

    vec3 Lo = (kD * albedo / PI + specular) * radiance * NdotL;

    vec3 ambient = vec3(0.03) * albedo * ao;
    vec3 color = ambient + Lo;

    // Tone Mapping & Gamma Correction
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2)); 

    outColor = vec4(color, 1.0);
}