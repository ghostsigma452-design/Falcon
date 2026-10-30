import falcon

# 1. Initialize Engine
var fg = newEngine("Falcon Engine - 2 Render Objects", 1000, 1000)
var cubeModel = parseObj("cube.obj").format()

# 2. Setup Camera & Pipelines
var cam = newCamera()
discard fg.createPipeline("shaders/vert.spv", "shaders/frag.spv")

# Load texture into bindless array slot 0 (Set 1)
var myTexture = loadTexture(
  fg.ctx.device.logicalDevice,
  fg.ctx.physicalDevice,
  fg.ctx.renderer.commandPool,
  fg.ctx.renderer.graphicsQueue,
  fg.bindlessTextures.descriptorSet,
  fg.textureSampler,
  "grass.png",
  0'u32 # Bindless Array Index 0
)

# 3. Spawn Distinct Models
var cube1 = fg.spawnModel(cubeModel, pos = [-1.0'f32, 0.0'f32, -3.0'f32])
var cube2 = fg.spawnModel(cubeModel, pos = [1.0'f32, 0.0'f32, -3.0'f32])

# Assign bindless texture index to the mesh
cube1.mesh.textureIndex = 0'u32
cube2.mesh.textureIndex = 0'u32

# 4. Render Loop
while fg.running:
  fg.processEvents()

  let viewProj = cam.getViewProjectionMatrix()

  # Rotate separate model reference instances
  cube1.transform.rotateX(speed(1))
  cube2.transform.rotateX(speed(-1))

  # Syncs and draws both objects with bindless texturing active
  fg.update(cam.transform.pos, viewProj)

# 5. Clean up
fg.destroy()