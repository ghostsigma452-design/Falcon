import falcon


var fg = newEngine("Falcon Engine - Bindless Textures", 1000, 1000)

var cubeModel = parseOBJ("cube.obj").format()

var cam = newCamera(aspectRatio = 1000.0'f32 / 1000.0'f32)

discard fg.createPipeline("shaders/vert.spv", "shaders/frag.spv")

discard fg.loadTexture("grass.png", 0)


var cube1 = spawnModel(fg, cubeModel, pos = [-1.2'f32, 0.0'f32, -3.0'f32], textureID = 0'u32)   
var cube2 = fg.spawnModel(cubeModel, pos = [2.1'f32, 2.0'f32, -3.0'f32], textureID = 0'u32)


# 5. Main Render Loop
while fg.running:
  fg.processEvents()


  cube1.transform.rotateY(speed(1.0))
  cube2.transform.rotateX(speed(-1.0))

  fg.update(cam.transform.pos, cam.getViewProjectionMatrix())

fg.destroy()