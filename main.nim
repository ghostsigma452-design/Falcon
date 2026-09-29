import falcon

# 1. Initialize Engine
var fg = newEngine("Falcon Engine - 2 Render Objects", 1000, 1000)
var cubeModel = parseObj("cube.obj").format()
var vertices = cubeModel[0]
var indices = cubeModel[1]


let cubeVertices*: seq[GPUVertex] = @[
  # Front Face (+Z)
  GPUVertex(pos: [-0.3f, -0.3f,  0.3f, 1.0f], color: [1.0f, 0.2f, 0.2f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f,  0.3f, 1.0f], color: [0.2f, 1.0f, 0.2f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),

  # Back Face (-Z)
  GPUVertex(pos: [ 0.3f, -0.3f, -0.3f, 1.0f], color: [1.0f, 0.2f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),
  GPUVertex(pos: [-0.3f, -0.3f, -0.3f, 1.0f], color: [0.2f, 1.0f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),

  # Right Face (+X)
  GPUVertex(pos: [ 0.3f, -0.3f,  0.3f, 1.0f], color: [0.2f, 1.0f, 0.2f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f, -0.3f, 1.0f], color: [1.0f, 0.2f, 1.0f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),

  # Left Face (-X)
  GPUVertex(pos: [-0.3f, -0.3f, -0.3f, 1.0f], color: [0.2f, 1.0f, 1.0f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f, -0.3f,  0.3f, 1.0f], color: [1.0f, 0.2f, 0.2f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),

  # Top Face (+Y)
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),

  # Bottom Face (-Y)
  GPUVertex(pos: [-0.3f, -0.3f, -0.3f, 1.0f], color: [0.2f, 1.0f, 1.0f, 1.0f], normal: [ 0.0f, -1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f, -0.3f, 1.0f], color: [1.0f, 0.2f, 1.0f, 1.0f], normal: [ 0.0f, -1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f,  0.3f, 1.0f], color: [0.2f, 1.0f, 0.2f, 1.0f], normal: [ 0.0f, -1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f, -0.3f,  0.3f, 1.0f], color: [1.0f, 0.2f, 0.2f, 1.0f], normal: [ 0.0f, -1.0f,  0.0f, 0.0f])
]

let cubeIndices*: seq[uint32] = @[
  0'u32, 1'u32, 2'u32,    2'u32, 3'u32, 0'u32,
  4'u32, 5'u32, 6'u32,    6'u32, 7'u32, 4'u32,
  8'u32, 9'u32, 10'u32,   10'u32, 11'u32, 8'u32,
  12'u32, 13'u32, 14'u32, 14'u32, 15'u32, 12'u32,
  16'u32, 17'u32, 18'u32, 18'u32, 19'u32, 16'u32,
  20'u32, 21'u32, 22'u32, 22'u32, 23'u32, 20'u32
]

# 2. Setup Camera & Pipelines
var cam = newCamera()
let mainPipeline = fg.ctx.createPipeline("shaders/vert.spv", "shaders/frag.spv")
fg.addPipeline(mainPipeline)

# 3. Spawn Distinct Models
var cube1 = fg.spawnModel(
  vertices, 
  indices, 
  pos = [-1.0'f32, 0.0'f32, -3.0'f32]
)

var cube2 = fg.spawnModel(
  cubeVertices, 
  cubeIndices, 
  pos = [1.0'f32, 0.0'f32, -3.0'f32]
)


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