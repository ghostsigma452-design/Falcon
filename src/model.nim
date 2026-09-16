import command, cglm, entity, transform, buffer, vk14

type

  model* = ref object of entity
    mesh*: RenderModel

type
  GPUSceneData* = object
    viewProj*: Mat4

proc updateMVP*(m: var model, viewProj: Mat4) =
  # Update and store model matrix on mesh
  m.mesh.matrix = m.transform.getModelMatrix()

  # Copy viewProj to SSBO
  var sceneData = GPUSceneData(viewProj: viewProj)
  m.mesh.sceneSSBO.copyData(addr sceneData, sizeof(GPUSceneData).VkDeviceSize)

proc cleanup*(m: model) =
  m.cleanup()