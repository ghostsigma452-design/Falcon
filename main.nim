import falcon, math

# 1. Initialize Engine (manages Window, Vulkan Context, and Event Loop)
var engine = newEngine("Falcon Engine - 2 Render Objects", 1000, 1000)

type
  GPUVertex* = object
    pos*: array[4, float32]
    color*: array[4, float32]
    normal*: array[4, float32]

let cubeVertices*: seq[GPUVertex] = @[
  # --- Front Face (+Z) ---
  GPUVertex(pos: [-0.3f, -0.3f,  0.3f, 1.0f], color: [1.0f, 0.2f, 0.2f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f,  0.3f, 1.0f], color: [0.2f, 1.0f, 0.2f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f], normal: [ 0.0f,  0.0f,  1.0f, 0.0f]),

  # --- Back Face (-Z) ---
  GPUVertex(pos: [ 0.3f, -0.3f, -0.3f, 1.0f], color: [1.0f, 0.2f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),
  GPUVertex(pos: [-0.3f, -0.3f, -0.3f, 1.0f], color: [0.2f, 1.0f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f], normal: [ 0.0f,  0.0f, -1.0f, 0.0f]),

  # --- Right Face (+X) ---
  GPUVertex(pos: [ 0.3f, -0.3f,  0.3f, 1.0f], color: [0.2f, 1.0f, 0.2f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f, -0.3f, -0.3f, 1.0f], color: [1.0f, 0.2f, 1.0f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f], normal: [ 1.0f,  0.0f,  0.0f, 0.0f]),

  # --- Left Face (-X) ---
  GPUVertex(pos: [-0.3f, -0.3f, -0.3f, 1.0f], color: [0.2f, 1.0f, 1.0f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f, -0.3f,  0.3f, 1.0f], color: [1.0f, 0.2f, 0.2f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f], normal: [-1.0f,  0.0f,  0.0f, 0.0f]),

  # --- Top Face (+Y) ---
  GPUVertex(pos: [-0.3f,  0.3f,  0.3f, 1.0f], color: [1.0f, 1.0f, 0.2f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f,  0.3f, 1.0f], color: [0.2f, 0.2f, 1.0f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [ 0.3f,  0.3f, -0.3f, 1.0f], color: [1.0f, 1.0f, 1.0f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),
  GPUVertex(pos: [-0.3f,  0.3f, -0.3f, 1.0f], color: [0.1f, 0.1f, 0.1f, 1.0f], normal: [ 0.0f,  1.0f,  0.0f, 0.0f]),

  # --- Bottom Face (-Y) ---
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

# 2. Camera & Models Setup
var cam = newCamera()

var cube1 = engine.spawnModel(
  cubeVertices, 
  cubeIndices, 
  pos = [-0.6'f32, 0.0'f32, -2.5'f32]
)

var cube2 = engine.spawnModel(
  cubeVertices, 
  cubeIndices, 
  pos = [0.6'f32, 0.0'f32, -2.5'f32]
)

# 3. Pipeline Setup
let mainPipeline = engine.ctx.createPipeline("shaders/vert.spv", "shaders/frag.spv")
engine.addPipeline(mainPipeline) # Registers and sets as activePipeline

# 4. Render Loop
while engine.running:
  # Process Window & SDL Quit Events
  engine.processEvents()

  let viewProj = cam.getViewProjectionMatrix()

  # Rotations & Model Updates
  cube1.transform.rotateX(speed(1))
  cube1.updateMVP(viewProj)

  cube2.transform.rotateX(speed(-1))
  cube2.updateMVP(viewProj)

  # Draw Frame using engine's active pipeline
  engine.ctx.drawFrame(
    engine.activePipeline, 
    viewProj, 
    [cube1.mesh, cube2.mesh], 
    cam.transform.pos
  )

# 5. Complete Teardown (Handles GPU idle wait, pipeline, model, context, and window cleanup)
engine.destroy()