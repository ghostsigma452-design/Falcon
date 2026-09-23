#version 450

// Inputs from Vertex Shader
layout(location = 0) in vec3 fragWorldPos;
layout(location = 1) in vec3 fragNormal;
layout(location = 2) in vec4 fragColor;

layout(location = 0) out vec4 outColor;

// Push Constants (Must match vertex shader layout exactly)
layout(push_constant) uniform PBRPushBlock {
    mat4 model;       // Offset 0
    vec4 cameraPos;   // Offset 64
    vec4 albedo;      // Offset 80
    float metallic;   // Offset 96
    float roughness;  // Offset 100
    float ao;         // Offset 104
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
    vec3 V = normalize(push.cameraPos.xyz - fragWorldPos);

    // Use vertex color if present, otherwise default to 1.0
    vec3 vColor = (length(fragColor.rgb) > 0.001) ? fragColor.rgb : vec3(1.0);
    vec3 albedo = vColor * push.albedo.rgb;

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
        
    vec3 specular = (NDF * G * F) / (4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001);
    vec3 kD = (vec3(1.0) - F) * (1.0 - metallic);     

    float NdotL = max(dot(N, L), 0.0);
    vec3 Lo = (kD * albedo / PI + specular) * radiance * NdotL;

    vec3 ambient = vec3(0.1) * albedo * ao;
    vec3 color = ambient + Lo;

    // Tone Mapping & Gamma Correction
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2)); 

    outColor = vec4(color, 1.0);
}