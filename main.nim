import falcon

# 1. Initialize Engine
var fg = newEngine("Falcon Engine - 2 Render Objects", 1000, 1000)
var cubeModel = parseObj("cube.obj").format()
# 2. Setup Camera & Pipelines
var cam = newCamera()
discard fg.createPipeline("shaders/vert.spv", "shaders/frag.spv")


# 3. Spawn Distinct Models
var cube1 = fg.spawnModel(cubeModel,pos = [-1.0'f32, 0.0'f32, -3.0'f32])

var cube2 = fg.spawnModel(cubeModel,pos = [1.0'f32, 0.0'f32, -3.0'f32])


# 4. Render Loop
while fg.running:
  fg.processEvents()

  let viewProj = cam.getViewProjectionMatrix()

  # Rotate separate model reference instances
  cube1.transform.rotateX(speed(1))
  cube2.transform.rotateX(speed(-1))


  # engine.update syncs and draws both objects
  fg.update(cam.transform.pos, viewProj)

# 5. Clean up
fg.destroy()