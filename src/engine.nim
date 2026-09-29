import vulkanContext, window, pipeline, sdl2, cglm, model, builtins, command

type 
  falconEngine* = object 
    ctx*: vulkanContext
    window*: VulkanWindow
    models*: seq[model]           # Stores model instances
    pipelines*: seq[VulkanPipeline]
    activePipeline*: VulkanPipeline
    event*: Event
    running*: bool

proc newEngine*(title: string, width: int, height: int): falconEngine =
  var win = newVulkanWindow(title, width, height)
  var ctx = newVk(win)
  ctx.initVk()

  result.ctx = ctx
  result.window = win
  result.models = @[]
  result.pipelines = @[]
  result.running = true

# Pipeline Management

proc addPipeline*(fg: var falconEngine, pipe: VulkanPipeline) =
  fg.pipelines.add(pipe)
  if fg.pipelines.len == 1:
    fg.activePipeline = pipe

proc setActivePipeline*(fg: var falconEngine, index: int) =
  if index >= 0 and index < fg.pipelines.len:
    fg.activePipeline = fg.pipelines[index]

proc setActivePipeline*(fg: var falconEngine, pipe: VulkanPipeline) =
  fg.activePipeline = pipe

# Model Spawning

proc spawnModel*[V, I](
  fg: var falconEngine,
  vertices: openArray[V],
  indices: openArray[I],
  pos: Vec3 = [0.0'f32, 0.0'f32, 0.0'f32],
  rot: Vec3 = [0.0'f32, 0.0'f32, 0.0'f32],
  scale: Vec3 = [0.25'f32, 0.25'f32, 0.25'f32]
): model =
  var m = fg.ctx.spawnModel(vertices, indices, pos, rot, scale)
  fg.models.add(m)
  result = m

proc spawnModel*(
  fg: var falconEngine,
  model: tuple[vertices: seq[GPUVertex], indices: seq[uint32]],
  pos: Vec3 = [0.0'f32, 0.0'f32, 0.0'f32],
  rot: Vec3 = [0.0'f32, 0.0'f32, 0.0'f32],
  scale: Vec3 = [0.25'f32, 0.25'f32, 0.25'f32]
): model =
  var m = fg.ctx.spawnModel(model[0], model[1], pos, rot, scale)
  fg.models.add(m)
  result = m


# Engine Update Loop

proc update*(engine: falconEngine, camPos: Vec3, viewProj: Mat4) =
  var renderBatch = newSeq[RenderModel](engine.models.len)

  for idx in 0 ..< engine.models.len:
    var m = engine.models[idx]  # Binds to a mutable 'var model' local reference
    m.updateMVP(viewProj)
    renderBatch[idx] = m.mesh

  engine.ctx.drawFrame(
    engine.activePipeline, 
    viewProj, 
    renderBatch, 
    camPos
  )
# Event Handling & Main Loop Control

proc processEvents*(fg: var falconEngine) =
  while pollEvent(fg.event):
    case fg.event.kind
    of QuitEvent:
      fg.running = false
    of WindowEvent:
      if fg.event.window.event == WindowEvent_Close:
        fg.running = false
    else:
      discard

# Cleanup & Teardown

proc destroy*(fg: var falconEngine) =
  for pipe in fg.pipelines:
    pipe.cleanup()
  fg.pipelines.setLen(0)

  fg.ctx.destroy()
  fg.window.cleanup()
  
  fg.running = false