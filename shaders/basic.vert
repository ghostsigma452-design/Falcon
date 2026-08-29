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

// Output to fragment shader
layout(location = 0) out vec3 fragColor;

void main() {
    // 1. Pull the vertex using Vulkan's built-in index variable
    GPUVertex v = vertices[gl_VertexIndex]; 
    
    // 2. Apply MVP matrix
    gl_Position = sceneData.viewProj * v.position; 
    
    // 3. Send color to fragment shader
    fragColor = v.color.xyz;
}