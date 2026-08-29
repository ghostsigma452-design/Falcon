import falcon
import math
import vk14

type
  Vec4 = array[4, float32]
  Mat4 = array[16, float32]

  GPUVertex = object
    pos: Vec4
    color: Vec4

  GPUSceneData = object
    mvp: Mat4

# Simple Rotation Matrix around Y axis
proc rotateY(angle: float32): Mat4 =
  let c = cos(angle)
  let s = sin(angle)
  result = [
     c,    0.0f,  s,    0.0f,
     0.0f, 1.0f,  0.0f, 0.0f,
    -s,    0.0f,  c,    0.0f,
     0.0f, 0.0f,  0.0f, 1.0f
  ]

var win = newVulkanWindow("Falcon Engine - Indexed Cube", 1000, 1000)

var ctx = newVk(win)
ctx.initVk()
let dev = ctx.device
let physicalDevice = ctx.physicalDevice
var renderpass = ctx.renderPass
var swapchain = ctx.swapchain

# 1. Deduplicated 8 unique corners of a 3D Cube
let uniqueCubeVertices: array[8, GPUVertex] = [
  GPUVertex(pos: [-0.5f, -0.5f,  0.5f, 1.0f], color: [1.0f, 0.0f, 0.0f, 1.0f]), # 0: Front-Bottom-Left
  GPUVertex(pos: [ 0.5f, -0.5f,  0.5f, 1.0f], color: [0.0f, 1.0f, 0.0f, 1.0f]), # 1: Front-Bottom-Right
  GPUVertex(pos: [ 0.5f,  0.5f,  0.5f, 1.0f], color: [0.0f, 0.0f, 1.0f, 1.0f]), # 2: Front-Top-Right
  GPUVertex(pos: [-0.5f,  0.5f,  0.5f, 1.0f], color: [1.0f, 1.0f, 0.0f, 1.0f]), # 3: Front-Top-Left
  GPUVertex(pos: [-0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 1.0f, 1.0f, 1.0f]), # 4: Back-Bottom-Left
  GPUVertex(pos: [ 0.5f, -0.5f, -0.5f, 1.0f], color: [1.0f, 0.0f, 1.0f, 1.0f]), # 5: Back-Bottom-Right
  GPUVertex(pos: [ 0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f]), # 6: Back-Top-Right
  GPUVertex(pos: [-0.5f,  0.5f, -0.5f, 1.0f], color: [0.0f, 0.0f, 0.0f, 1.0f])  # 7: Back-Top-Left
]

# 2. 36 Indices (12 Triangles) referencing the 8 unique vertices
let cubeIndices: array[36, uint32] = [
  # Front face
  0u32, 1u32, 2u32,  2u32, 3u32, 0u32,
  # Back face
  5u32, 4u32, 7u32,  7u32, 6u32, 5u32,
  # Left face
  4u32, 0u32, 3u32,  3u32, 7u32, 4u32,
  # Right face
  1u32, 5u32, 6u32,  6u32, 2u32, 1u32,
  # Top face
  3u32, 2u32, 6u32,  6u32, 7u32, 3u32,
  # Bottom face
  4u32, 5u32, 1u32,  1u32, 0u32, 4u32
]

let memoryFlags = getMemFlags()

# 3. Create Vertex Buffer
let vertexSSBO = newVulkanBuffer(
  physicalDevice,
  dev.logicalDevice,
  getBufferSize(GPUVertex, uniqueCubeVertices.len),
  VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.VkBufferUsageFlags,
  memoryFlags
)
vertexSSBO.copyData(unsafeAddr uniqueCubeVertices[0], getBufferSize(GPUVertex, uniqueCubeVertices.len))

# 4. Create Index Buffer
let indexSSBO = newVulkanBuffer(
  physicalDevice,
  dev.logicalDevice,
  getBufferSize(uint32, cubeIndices.len),
  VK_BUFFER_USAGE_INDEX_BUFFER_BIT.VkBufferUsageFlags,
  memoryFlags
)
indexSSBO.copyData(unsafeAddr cubeIndices[0], getBufferSize(uint32, cubeIndices.len))

# 5. Create Scene Uniform/SSBO Buffer
let sceneSSBO = newVulkanBuffer(
  physicalDevice,
  dev.logicalDevice,
  getBufferSize(GPUSceneData),
  VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.VkBufferUsageFlags,
  memoryFlags
)

# 6. Setup Descriptors, Pipeline & Model Struct
let ssboPack = newSSBOPack(dev.logicalDevice, vertexSSBO, sceneSSBO)
let pipeline = newVulkanPipeline(dev.logicalDevice, renderPass.renderPass, swapchain.extent, ssboPack.layout, "shaders/vert.spv", "shaders/frag.spv")
let renderer = ctx.renderer

let cubeModel = RenderModel(
  vertexBuffer: vertexSSBO.buffer,
  indexBuffer: indexSSBO.buffer,
  indexCount: cubeIndices.len.uint32,
  ssboPack: ssboPack
)

echo "Falcon Engine initialised successfully! Rendering Indexed 3D Cube..."

var event: Event
var running = true
var angle: float32 = 0.0f

while running:
  while pollEvent(event):
    if event.kind == QuitEvent:
      running = false

  # Update Rotation Angle and Upload to Scene SSBO
  angle += 0.001f
  var sceneData = GPUSceneData(mvp: rotateY(angle))
  sceneSSBO.copyData(addr sceneData, sizeof(GPUSceneData).VkDeviceSize)

  # Render model array
  renderer.drawFrame(swapchain, renderPass.renderPass, pipeline, [cubeModel])

# Cleanup
pipeline.cleanup()
ssboPack.cleanup()
vertexSSBO.cleanup()
indexSSBO.cleanup()
sceneSSBO.cleanup()
ctx.destroy()
win.cleanup()