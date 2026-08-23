// shader.vert
#version 450

struct GPUVertex {
    vec4 position;
    vec4 color;
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

void main() {
    // ...
}