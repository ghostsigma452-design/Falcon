import command, cglm, entity, transform, buffer, vk14

type

  model* = ref object of entity
    mesh*: RenderModel




proc updateMVP*(m: var model, viewProj: Mat4) =
  var mvp: Mat4
  var modelMat = m.transform.getModelMatrix()
  glm_mat4_mul(viewProj, modelMat, mvp)
  
  var sceneData = GPUSceneData(mvp: mvp)
  m.mesh.sceneSSBO.copyData(addr sceneData, sizeof(GPUSceneData).VkDeviceSize)


proc cleanup*(m: model) =
    m.mesh.cleanup()