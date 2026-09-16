#version 450

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec4 inColor;

layout(location = 0) out vec4 fragColor;

// Global Frame Data (Set 0, Binding 0)
layout(set = 0, binding = 0) uniform GlobalUBO {
    mat4 viewProj;
} ubo;

// Per-Object Instance Data (64 Bytes)
layout(push_constant) uniform PushBlock {
    mat4 model;
} push;

void main() {
    gl_Position = ubo.viewProj * push.model * vec4(inPosition, 1.0);
    fragColor = inColor;
}