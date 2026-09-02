import falcon
import math
import vk14


type
  GPUVertex = object
    pos: Vec4
    color: Vec4

  GPUSceneData = object
    mvp: Mat4



# Initialize Window & Context
var win = newVulkanWindow("Falcon Engine - 2 Render Objects", 1000, 1000)

var ctx = newVk(win)
ctx.initVk()
let dev = ctx.device
let physicalDevice = ctx.physicalDevice

# 1. Shared Cube Geometry
let uniqueCubeVertices: seq[GPUVertex] = @[
  GPUVertex(pos: [-0.3f, -0.3f,  0.3f, 1.0f], color: [1.0f, 0.2f, 0.2f, 1.0f]), # 0: Red
  GPUVertex(pos: [ 0.3f, -0.3f,  0.3f, 1.0f], color: [0.2f, 1.0f, 0.2f, 1.0f]), # 1: Green
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f]), # 2: Blue
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f]), # 3: Yellow
  GPUVertex(pos: [-0.3f, -0.3f, -0.3f, 1.0f], color: [0.2f, 1.0f, 1.0f, 1.0f]), # 4: Cyan
  GPUVertex(pos: [ 0.3f, -0.3f, -0.3f, 1.0f], color: [1.0f, 0.2f, 1.0f, 1.0f]), # 5: Magenta
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f]), # 6: White
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f])  # 7: Dark Grey
]

let cubeIndices: seq[uint32] = @[
  0'u32, 1'u32, 2'u32,  2'u32, 3'u32, 0'u32, # Front face
  5'u32, 4'u32, 7'u32,  7'u32, 6'u32, 5'u32, # Back face
  4'u32, 0'u32, 3'u32,  3'u32, 7'u32, 4'u32, # Left face
  1'u32, 5'u32, 6'u32,  6'u32, 2'u32, 1'u32, # Right face
  3'u32, 2'u32, 6'u32,  6'u32, 7'u32, 3'u32, # Top face
  4'u32, 5'u32, 1'u32,  1'u32, 0'u32, 4'u32  # Bottom face
]

let memoryFlags = getMemFlags()

# 2. Instantiating Object 1 and Object 2
var cube1 = newRenderModel(physicalDevice, dev, ctx.globalLayout, uniqueCubeVertices, cubeIndices, memoryFlags)
var cube2 = newRenderModel(physicalDevice, dev, ctx.globalLayout, uniqueCubeVertices, cubeIndices, memoryFlags)

# 3. Create Shader Pipeline using VulkanContext Wrapper
let pipeline = ctx.createPipeline("shaders/vert.spv", "shaders/frag.spv")
let renderer = ctx.renderer

echo "Falcon Engine initialized! Rendering 2 objects..."

var event: Event
var running = true
var angle: float32 = 0.0f

# 4. Main Loop
while running:
  while pollEvent(event):
    if event.kind == QuitEvent:
      running = false

  var sceneData1 = GPUSceneData(mvp: translate(-0.6f, 0.0f, 0.5f) * rotateY(angle))
  cube1.sceneSSBO.copyData(addr sceneData1, sizeof(GPUSceneData).VkDeviceSize)

  var sceneData2 = GPUSceneData(mvp: translate(0.6f, 0.0f, 0.5f) * rotateY(-angle))
  cube2.sceneSSBO.copyData(addr sceneData2, sizeof(GPUSceneData).VkDeviceSize)

  angle += 0.002f

  # Transform Object 1 (Positioned Left, Rotating Counter-Clockwise)
  sceneData1 = GPUSceneData(mvp: translate(-0.6f, 0.0f, 0.0f) * rotateY(angle))
  cube1.sceneSSBO.copyData(addr sceneData1, sizeof(GPUSceneData).VkDeviceSize)

  # Transform Object 2 (Positioned Right, Rotating Clockwise)
  sceneData2 = GPUSceneData(mvp: translate(0.6f, 0.0f, 0.0f) * rotateY(-angle))
  cube2.sceneSSBO.copyData(addr sceneData2, sizeof(GPUSceneData).VkDeviceSize)

  # Render both models in a single draw pass
  renderer.drawFrame(ctx.swapchain, ctx.renderPass.renderPass, pipeline, [cube1, cube2])

# Cleanup
pipeline.cleanup()
cube1.cleanup()
cube2.cleanup()
ctx.destroy()
win.cleanup()