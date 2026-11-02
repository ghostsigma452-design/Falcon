import falcon

# 1. Initialize Engine & Window
var fg = newEngine("Falcon Engine - Bindless Textures", 1200, 800)
var cubeModel = parseOBJ("cube.obj").format()

# 2. Setup Camera & Pipelines
var cam = newCamera(
  pos = [0.0'f32, 1.0'f32, 4.0'f32],
  fov = 0.785398'f32,
  aspectRatio = 1200.0'f32 / 800.0'f32
)
discard fg.createPipeline("shaders/vert.spv", "shaders/frag.spv")

# 3. Load Texture into Bindless Array Slot 0 (Set 1)
var textureSampler = createTextureSampler(fg.ctx.device.logicalDevice)
var myTexture = loadTexture(
  fg.ctx.device.logicalDevice,
  fg.ctx.physicalDevice,
  fg.ctx.renderer.commandPool,
  fg.ctx.renderer.graphicsQueue,
  fg.bindlessTextures.descriptorSet,
  textureSampler,
  "grass.png",
  0'u32 # Bindless Array Index 0
)

# 4. Spawn Distinct Models
var cube1 = fg.spawnModel(cubeModel, pos = [-1.2'f32, 0.0'f32, -3.0'f32])
var cube2 = fg.spawnModel(cubeModel, pos = [2.1'f32, 2.0'f32, -3.0'f32])

# Assign bindless texture index to each mesh instance
cube1.mesh.textureIndex = 0'u32
cube2.mesh.textureIndex = 0'u32

# 5. Main Render Loop
while fg.running:
  fg.processEvents()

  # Rotate separate model instances independently
  cube1.transform.rotateY(speed(1.0))
  cube2.transform.rotateX(speed(-1.0))

  let viewProj = cam.getViewProjectionMatrix()

  # Sync SSBOs and draw all active models
  fg.update(cam.transform.pos, viewProj)

# 6. Graceful Engine Cleanup
fg.destroy()