import command, cglm, vulkanContext, helper, entity, transform

type

  model* = ref object of entity
    mesh*: RenderModel


proc spawnModel*[V, I](
    ctx: vulkanContext,
    vertices: openArray[V],
    indices: openArray[I],
    pos: Vec3 = [0.0'f32, 0.0'f32, 0.0'f32],
    rot: Vec3 = [0.0'f32, 0.0'f32, 0.0'f32],
    scale: Vec3 = [1.0'f32, 1.0'f32, 1.0'f32]
): model =
  new(result)

  result.mesh = newRenderModel(
    ctx.physicalDevice,
    ctx.device,
    ctx.globalLayout,
    vertices,
    indices,
    getMemFlags()
  )

  result.components = @[
    component(transform: Transform(pos: pos, rot: rot, scale: scale))
  ]


proc cleanup*(m: model) =
    m.mesh.cleanup()