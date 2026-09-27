import vulkanContext, window, entity, pipeline, sdl2, cglm, model, camera

type 
    falconEngine* = object 
        ctx*: vulkanContext
        window*: VulkanWindow
        scene*: seq[entity]
        pipelines*: seq[VulkanPipeline]
        activePipeline*: VulkanPipeline
        event*: Event
        running*: bool

proc newEngine*(title: string, width: int, height: int): falconEngine =
    var win = newVulkanWindow(title, width, height)
    var ctx = newVk(win)
    ctx.initVk()
    var cam = newCamera()
    
    result.ctx = ctx
    result.window = win
    result.scene = @[entity(cam)]
    result.pipelines = @[]
    result.running = true

# pipeline Management

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
    scale: Vec3 = [1.0'f32, 1.0'f32, 1.0'f32]
): model =
    var m = fg.ctx.spawnModel(vertices, indices, pos, rot, scale)
    fg.scene.add(entity(m))
    result = m

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
    # Ensure GPU operations finish before destroying resources


    # Destroy pipelines
    for pipe in fg.pipelines:
        pipe.cleanup()
    fg.pipelines.setLen(0)

    # Clean up Vulkan Context & Window
    fg.ctx.destroy()
    fg.window.cleanup()
    
    fg.running = false