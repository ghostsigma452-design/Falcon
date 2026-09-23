#version 450

struct GPUVertex {
    vec4 position;
    vec4 color;
    vec4 normal;
};

struct GPUSceneData {
    mat4 viewProj;
};

// SSBOs (Set 0)
layout(std430, set = 0, binding = 0) readonly buffer VertexBuffer {
    GPUVertex vertices[];
};

layout(std430, set = 0, binding = 1) readonly buffer SceneBuffer {
    GPUSceneData sceneData;
};

// Push Constants (112 bytes total)
layout(push_constant) uniform PBRPushBlock {
    mat4 model;       // Offset 0   (64 bytes)
    vec4 cameraPos;   // Offset 64  (16 bytes - use cameraPos.xyz)
    vec4 albedo;      // Offset 80  (16 bytes - use albedo.rgb)
    float metallic;   // Offset 96  (4 bytes)
    float roughness;  // Offset 100 (4 bytes)
    float ao;         // Offset 104 (4 bytes)
} push;

// Outputs to Fragment Shader
layout(location = 0) out vec3 fragWorldPos;
layout(location = 1) out vec3 fragNormal;
layout(location = 2) out vec4 fragColor;

void main() {
    GPUVertex v = vertices[gl_VertexIndex];

    vec4 worldPos = push.model * vec4(v.position.xyz, 1.0);
    fragWorldPos = worldPos.xyz;

    // Transform normal to world space
    mat3 normalMatrix = transpose(inverse(mat3(push.model)));
    fragNormal = normalize(normalMatrix * v.normal.xyz);

    fragColor = v.color;

    gl_Position = sceneData.viewProj * worldPos;
}