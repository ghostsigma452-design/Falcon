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

// Outputs to Fragment Shader
layout(location = 0) out vec3 fragWorldPos;
layout(location = 1) out vec3 fragNormal;

void main() {
    GPUVertex v = vertices[gl_VertexIndex];

    vec4 worldPos = push.model * vec4(v.position.xyz, 1.0);
    fragWorldPos = worldPos.xyz;

    mat3 normalMatrix = transpose(inverse(mat3(push.model)));
    fragNormal = normalize(normalMatrix * v.normal.xyz);

    gl_Position = sceneData.viewProj * worldPos;
}