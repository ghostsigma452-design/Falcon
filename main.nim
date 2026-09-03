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


# 2. Instantiating Object 1 and Object 2
var cube1 = spawnModel(ctx, uniqueCubeVertices, cubeIndices)
var cube2 = spawnModel(ctx, uniqueCubeVertices, cubeIndices)

# 3. Create Shader Pipeline using VulkanContext Wrapper
let pipeline = ctx.createPipeline("shaders/vert.spv", "shaders/frag.spv")
let renderer = ctx.renderer

echo "Falcon Engine initialized! Rendering 2 objects..."

var event: Event
var running = true
var angle = 0f
cube1.components[0].transform.pos = [-0.6f, 0.0f, -2.5f]
cube2.components[0].transform.pos = [ 0.6f, 0.0f, -2.5f]

# 4. Main Loop
while running:
  while pollEvent(event):
    if event.kind == QuitEvent:
      running = false


  angle += 0.005f

  # 1. Create Projection Matrix (45 degree FOV)
  var proj, view, viewProj: Mat4
  glm_perspective(0.785398f, 1.0f, 0.1f, 100.0f, proj) 
  proj[1][1] = proj[1][1] * -1.0f # Flip Y-axis to match Vulkan's coordinate system

  # 2. Create View Matrix (Camera at origin)
  glm_mat4_identity(view)
  glm_mat4_mul(proj, view, viewProj) # viewProj = proj * view

  # 3. Update & Upload Cube 1 Matrix
  cube1.components[0].transform.rot[1] = angle
  var model1 = cube1.components[0].transform.getModelMatrix()
  
  var mvp1: Mat4
  glm_mat4_mul(viewProj, model1, mvp1) # mvp = proj * view * model
  
  var sceneData1 = GPUSceneData(mvp: mvp1)
  cube1.mesh.sceneSSBO.copyData(addr sceneData1, sizeof(GPUSceneData).VkDeviceSize)

  # 4. Update & Upload Cube 2 Matrix
  cube2.components[0].transform.rot[1] = -angle
  var model2 = cube2.components[0].transform.getModelMatrix()
  
  var mvp2: Mat4
  glm_mat4_mul(viewProj, model2, mvp2) # mvp = proj * view * model
  
  var sceneData2 = GPUSceneData(mvp: mvp2)
  cube2.mesh.sceneSSBO.copyData(addr sceneData2, sizeof(GPUSceneData).VkDeviceSize)

  # 5. Render both models
  renderer.drawFrame(ctx.swapchain, ctx.renderPass.renderPass, pipeline, [cube1.mesh, cube2.mesh])


  # Render both models in a single draw pass
  renderer.drawFrame(ctx.swapchain, ctx.renderPass.renderPass, pipeline, [cube1.mesh, cube2.mesh])

# Cleanup
pipeline.cleanup()
cube1.cleanup()
cube2.cleanup()
ctx.destroy()
win.cleanup()