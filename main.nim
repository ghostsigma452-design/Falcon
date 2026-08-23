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

# Simple Rotation Matrix around Y & X axes
proc rotateY(angle: float32): Mat4 =
  let c = cos(angle)
  let s = sin(angle)
  result = [
     c,    0.0f,  s,    0.0f,
     0.0f, 1.0f,  0.0f, 0.0f,
    -s,    0.0f,  c,    0.0f,
     0.0f, 0.0f,  0.0f, 1.0f
  ]

var win = newVulkanWindow("Falcon Engine - SSBO Cube", 1000, 1000)

loadPhysicalDeviceProcs(win.vkInstance)
let (physicalDevice, queueIndices) = pickPhysicalDevice(win.vkInstance, win.vkSurface)
let dev = newVulkanDevice(win.vkInstance, physicalDevice, queueIndices)
loadLogicalDeviceProcs(win.vkInstance, dev.logicalDevice)

let swapchain = newVulkanSwapchain(physicalDevice, dev.logicalDevice, win.vkSurface, queueIndices, 1000, 1000)
let renderPass = newVulkanRenderPass(dev.logicalDevice, swapchain.format)
swapchain.createFramebuffers(renderPass.renderPass)

# 3D Cube Vertices (36 indices forming 12 triangles)
let cubeVertices: array[36, GPUVertex] = [
  # Front
  GPUVertex(pos: [-0.5f, -0.5f,  0.5f, 1.0f], color: [1.0f, 0.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f,  0.5f, 1.0f], color: [0.0f, 1.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f,  0.5f, 1.0f], color: [0.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f,  0.5f, 1.0f], color: [0.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.5f,  0.5f,  0.5f, 1.0f], color: [1.0f, 1.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [-0.5f, -0.5f,  0.5f, 1.0f], color: [1.0f, 0.0f, 0.0f, 1.0f]),

  # Back
  GPUVertex(pos: [-0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 0.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [-0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 1.0f, 1.0f, 1.0f]),

  # Left
  GPUVertex(pos: [-0.5f,  0.5f,  0.5f, 1.0f], color: [1.0f, 1.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [-0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.5f, -0.5f,  0.5f, 1.0f], color: [1.0f, 0.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [-0.5f,  0.5f,  0.5f, 1.0f], color: [1.0f, 1.0f, 0.0f, 1.0f]),

  # Right
  GPUVertex(pos: [ 0.5f,  0.5f,  0.5f, 1.0f], color: [0.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f,  0.5f, 1.0f], color: [0.0f, 1.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 0.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 0.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f,  0.5f, 1.0f], color: [0.0f, 0.0f, 1.0f, 1.0f]),

  # Top
  GPUVertex(pos: [-0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 0.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f,  0.5f, 1.0f], color: [0.0f, 1.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f, -0.5f,  0.5f, 1.0f], color: [0.0f, 1.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [-0.5f, -0.5f,  0.5f, 1.0f], color: [1.0f, 0.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [-0.5f, -0.5f, -0.5f, 1.0f], color: [0.0f, 1.0f, 1.0f, 1.0f]),

  # Bottom
  GPUVertex(pos: [-0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.5f,  0.5f,  0.5f, 1.0f], color: [1.0f, 1.0f, 0.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f,  0.5f, 1.0f], color: [0.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f,  0.5f, 1.0f], color: [0.0f, 0.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.5f,  0.5f, -0.5f, 1.0f], color: [1.0f, 0.0f, 1.0f, 1.0f])
]

# 1. Allocate SSBOs (Vertices + Scene Matrix)
let vertexFlags = cast[VkMemoryPropertyFlags](
  VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.uint32 or 
  VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.uint32
)

let vertexSSBO = newVulkanBuffer(
  physicalDevice,
  dev.logicalDevice,
  (sizeof(GPUVertex) * cubeVertices.len).VkDeviceSize,
  VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.VkBufferUsageFlags,
  vertexFlags
)
vertexSSBO.copyData(unsafeAddr cubeVertices[0], (sizeof(GPUVertex) * cubeVertices.len).VkDeviceSize)

let sceneSSBO = newVulkanBuffer(
  physicalDevice,
  dev.logicalDevice,
  sizeof(GPUSceneData).VkDeviceSize,
  VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.VkBufferUsageFlags,
  vertexFlags
)

# 2. Setup Descriptors and Pipeline
let ssboPack = newSSBOPack(dev.logicalDevice, vertexSSBO, sceneSSBO)
let pipeline = newVulkanPipeline(dev.logicalDevice, renderPass.renderPass, swapchain.extent, ssboPack.layout, "shaders/vert.spv", "shaders/frag.spv")
let renderer = newVulkanRenderer(win.vkInstance,dev.logicalDevice, queueIndices.graphicsFamily.uint32, queueIndices.presentFamily.uint32)

echo "Falcon Engine initialised successfully! Rendering SSBO 3D Cube..."

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

  if vkCmdBeginRenderPass == nil:
    raise newException(Exception, "vkCmdBeginRenderPass pointer is NIL! Check Vkloader proc loading.")
  if cast[uint64](renderPass) == 0:
    raise newException(Exception, "renderPass handle is null!")

  # Checks the Nim ref pointer
  echo "Nim Ref Object exists: ", renderPass != nil 

# Checks the actual Vulkan handle (likely 0!)
  echo "Raw VkRenderPass handle: ", cast[uint64](renderPass.renderPass)



  renderer.drawFrame(swapchain, renderPass.renderPass, pipeline, ssboPack, cubeVertices.len.uint32)

# Cleanup
renderer.cleanup()
pipeline.cleanup()
ssboPack.cleanup()
vertexSSBO.cleanup()
sceneSSBO.cleanup()
swapchain.cleanup()
renderPass.cleanup()
dev.cleanup()
win.cleanup()