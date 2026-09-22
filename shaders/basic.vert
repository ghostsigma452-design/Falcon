#version 450

struct GPUVertex {
    vec4 position;
    vec4 color;
    vec4 normal;
};

struct GPUSceneData {
    mat4 viewProj;
};

layout(std430, set = 0, binding = 0) readonly buffer VertexBuffer {
    GPUVertex vertices[];
};

layout(std430, set = 0, binding = 1) readonly buffer SceneBuffer {
    GPUSceneData sceneData;
};

// Reads model matrix starting at offset 0
layout(push_constant) uniform PushBlock {
    mat4 model;
} push;

layout(location = 0) out vec3 fragWorldPos;
layout(location = 1) out vec3 fragNormal;

void main() {
    GPUVertex v = vertices[gl_VertexIndex];
    vec4 worldPos = push.model * vec4(v.position.xyz, 1.0);
    
    fragWorldPos = worldPos.xyz;
    fragNormal = normalize(mat3(push.model) * v.normal.xyz);
    
    gl_Position = sceneData.viewProj * worldPos;
}