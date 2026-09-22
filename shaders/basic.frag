#version 450

layout(location = 0) in vec3 fragWorldPos;
layout(location = 1) in vec3 fragNormal;

layout(location = 0) out vec4 outColor;

// Fragment shader reads PBR properties starting at byte offset 64
layout(push_constant) uniform PushBlock {
    layout(offset = 64) vec3 albedo;
    float metallic;
    float roughness;
    float ao;
} pbr;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / max(denom, 0.0001);
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void main() {
    vec3 N = normalize(fragNormal);
    vec3 V = normalize(vec3(0.0, 2.0, 5.0) - fragWorldPos);

    vec3 F0 = mix(vec3(0.04), pbr.albedo, pbr.metallic);

    // Light source
    vec3 lightPos = vec3(2.0, 4.0, 2.0);
    vec3 lightColor = vec3(20.0, 20.0, 20.0);

    vec3 L = normalize(lightPos - fragWorldPos);
    vec3 H = normalize(V + L);
    float distance = length(lightPos - fragWorldPos);
    float attenuation = 1.0 / (distance * distance);
    vec3 radiance = lightColor * attenuation;

    // Cook-Torrance BRDF
    float NDF = DistributionGGX(N, H, pbr.roughness);   
    float G   = GeometrySmith(N, V, L, pbr.roughness);      
    vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);
       
    vec3 numerator    = NDF * G * F; 
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;
    
    vec3 kS = F;
    vec3 kD = (vec3(1.0) - kS) * (1.0 - pbr.metallic);	  

    float NdotL = max(dot(N, L), 0.0);

    vec3 Lo = (kD * pbr.albedo / PI + specular) * radiance * NdotL;  
    vec3 ambient = vec3(0.03) * pbr.albedo * pbr.ao;
    vec3 color = ambient + Lo;

    // Tone Mapping & Gamma Correction
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2)); 

    outColor = vec4(color, 1.0);
}