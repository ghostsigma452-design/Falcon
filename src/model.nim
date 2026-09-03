import command, cglm, vulkanContext, helper

type
  transform* = object 
    pos*: Vec3
    rot*: Vec3    
    scale*: Vec3

  component* = object 
    transform*: transform

  entity* = ref object of RootObj
    components*: seq[component]

  model* = ref object of entity
    mesh*: RenderModel





proc getModelMatrix*(t: transform): Mat4 =
  glm_mat4_identity(result)
  glm_translate(result, t.pos)
  glm_rotate(result, t.rot[0], [1.0'f32, 0.0'f32, 0.0'f32])
  glm_rotate(result, t.rot[1], [0.0'f32, 1.0'f32, 0.0'f32])
  glm_rotate(result, t.rot[2], [0.0'f32, 0.0'f32, 1.0'f32])
  glm_scale(result, t.scale)
  return result

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
    component(transform: transform(pos: pos, rot: rot, scale: scale))
  ]

proc cleanup*(m: model) =
    m.mesh.cleanup()