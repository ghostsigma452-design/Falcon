#version 450

struct GPUVertex {
    vec4 position;
    vec4 color;
};

struct GPUSceneData {
    mat4 viewProj;
};

// Set 0, Binding 0: Vertex SSBO
layout(std430, set = 0, binding = 0) readonly buffer VertexBuffer {
    GPUVertex vertices[];
};

// Set 0, Binding 1: Scene SSBO (View & Projection)
layout(std430, set = 0, binding = 1) readonly buffer SceneBuffer {
    GPUSceneData sceneData;
};

// Push Constant: Per-Object Model Matrix (64 bytes)
layout(push_constant) uniform PushBlock {
    mat4 model;
} push;

layout(location = 0) out vec4 fragColor;

void main() {
    GPUVertex v = vertices[gl_VertexIndex];

    // MVP multiplication performed in GLSL using push.model
    gl_Position = sceneData.viewProj * push.model * v.position;
    fragColor = v.color;
}