import falcon, math



# Initialize Window & Context
var win = newVulkanWindow("Falcon Engine - 2 Render Objects", 1000, 1000)


var ctx = newVk(win)
ctx.initVk()

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
let cubeIndices: seq[uint32] = @[
  0, 1, 2,  2, 3, 0,
  5, 4, 7,  7, 6, 5,
  4, 0, 3,  3, 7, 4,
  1, 5, 6,  6, 2, 1,
  3, 2, 6,  6, 7, 3,
  4, 5, 1,  1, 0, 4
]

# 2. Camera & Models Setup
var cam = newCamera()

var cube1 = spawnModel(ctx, cubeVertices, cubeIndices)


var cube2 = spawnModel(ctx, cubeVertices, cubeIndices)


cube1.transform.pos = [-0.6f, 0.0f, -2.5f]
cube2.transform.pos = [ 0.6f, 0.0f, -2.5f]

# 3. Pipeline Setup
let pipeline = ctx.createPipeline("shaders/vert.spv", "shaders/frag.spv")


var event: Event
var running = true

# 4. Render Loop
while running:
  while pollEvent(event):
    if event.kind == QuitEvent:
      running = false

  let viewProj = cam.getViewProjectionMatrix()

  # Rotations & SSBO updates
  cube1.transform.rotateX(speed(1))
  cube1.updateMVP(viewProj)

  cube2.transform.rotateX(speed(-1))
  cube2.updateMVP(viewProj)

  # Draw Frame
  ctx.drawFrame(pipeline, viewProj,[cube1.mesh, cube2.mesh])

# Cleanup
pipeline.cleanup()
cube1.cleanup()
cube2.cleanup()
ctx.destroy()
win.cleanup()