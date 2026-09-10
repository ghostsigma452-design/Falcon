import falcon
import math
import vk14


type
  GPUVertex = object
    pos: Vec4
    color: Vec4

# Initialize Window & Context
var win = newVulkanWindow("Falcon Engine - 2 Render Objects", 1000, 1000)

var ctx = newVk(win)
ctx.initVk()

# 1. Geometry Data
let uniqueCubeVertices: seq[GPUVertex] = @[
  GPUVertex(pos: [-0.3f, -0.3f,  0.3f, 1.0f], color: [1.0f, 0.2f, 0.2f, 1.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f,  0.3f, 1.0f], color: [0.2f, 1.0f, 0.2f, 1.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f]),
  GPUVertex(pos: [-0.3f, -0.3f, -0.3f, 1.0f], color: [0.2f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f, -0.3f, 1.0f], color: [1.0f, 0.2f, 1.0f, 1.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f]),
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f])
]

let cubeIndices: seq[uint32] = @[
  0'u32, 1'u32, 2'u32,  2'u32, 3'u32, 0'u32,
  5'u32, 4'u32, 7'u32,  7'u32, 6'u32, 5'u32,
  4'u32, 0'u32, 3'u32,  3'u32, 7'u32, 4'u32,
  1'u32, 5'u32, 6'u32,  6'u32, 2'u32, 1'u32,
  3'u32, 2'u32, 6'u32,  6'u32, 7'u32, 3'u32,
  4'u32, 5'u32, 1'u32,  1'u32, 0'u32, 4'u32
]

# 2. Instantiate Camera and Models
var cam = newCamera(
  pos = [0.0f, 0.0f, 0.0f],       # Camera at origin
  aspectRatio = 1000.0f / 1000.0f # Window aspect ratio
)

var cube1 = spawnModel(ctx, uniqueCubeVertices, cubeIndices)
var cube2 = spawnModel(ctx, uniqueCubeVertices, cubeIndices)

# Position cubes in front of the camera
cube1.components[0].transform.pos = [-0.6f, 0.0f, -2.5f]
cube2.components[0].transform.pos = [ 0.6f, 0.0f, -2.5f]

# 3. Create Shader Pipeline
let pipeline = ctx.createPipeline("shaders/vert.spv", "shaders/frag.spv")
let renderer = ctx.renderer

var event: Event
var running = true
var angle: float32 = 0.0f

# 4. Render Loop
while running:
  while pollEvent(event):
    if event.kind == QuitEvent:
      running = false

  angle += 0.005f

  # Get camera View-Projection matrix
  let viewProj = cam.getViewProjectionMatrix()

  # Update Cube 1 Matrix
  cube1.components[0].transform.rot[1] = angle
  var model1 = cube1.components[0].transform.getModelMatrix()
  var mvp1: Mat4
  glm_mat4_mul(viewProj, model1, mvp1)
  
  var sceneData1 = GPUSceneData(mvp: mvp1)
  cube1.mesh.sceneSSBO.copyData(addr sceneData1, sizeof(GPUSceneData).VkDeviceSize)

  # Update Cube 2 Matrix
  cube2.components[0].transform.rot[1] = -angle
  var model2 = cube2.components[0].transform.getModelMatrix()
  var mvp2: Mat4
  glm_mat4_mul(viewProj, model2, mvp2)
  
  var sceneData2 = GPUSceneData(mvp: mvp2)
  cube2.mesh.sceneSSBO.copyData(addr sceneData2, sizeof(GPUSceneData).VkDeviceSize)

  # Draw Frame
  renderer.drawFrame(ctx.swapchain, ctx.renderPass.renderPass, pipeline, [cube1.mesh, cube2.mesh])

# Cleanup
pipeline.cleanup()
cube1.cleanup()
cube2.cleanup()
ctx.destroy()
win.cleanup()