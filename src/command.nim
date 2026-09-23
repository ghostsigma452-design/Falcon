import vk14
import vkLoader
import swapchain
import pipeline
import descriptors
import buffer
import device
import depth
import math
import cglm
import pushConstant

type
  RenderModel* = object
    vertexBuffer*: VkBuffer
    indexBuffer*: VkBuffer
    indexCount*: uint32
    sceneSSBO*: VulkanBuffer
    ssboPack*: SSBOPack
    matrix*: Mat4 # Model transformation matrix

  GPUSceneData* = object
    mvp*: Mat4

proc newRenderModel*[V, I](
  physicalDevice: VkPhysicalDevice,
  dev: VulkanDevice,
  layout: VkDescriptorSetLayout,
  vertices: openArray[V],
  indices: openArray[I],
  memoryFlags: VkMemoryPropertyFlags
): RenderModel =
  # 1. Create and populate Vertex Buffer
  let vertexSize = (sizeof(V) * vertices.len).VkDeviceSize
  let vertexSSBO = newVulkanBuffer(
    physicalDevice,
    dev.logicalDevice,
    vertexSize,
    cast[VkBufferUsageFlags](
      VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.uint32 or 
      VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.uint32
    ),
    memoryFlags
  )
  if vertices.len > 0:
    vertexSSBO.copyData(unsafeAddr vertices[0], vertexSize)

  # 2. Create and populate Index Buffer
  let indexSize = (sizeof(I) * indices.len).VkDeviceSize
  let indexSSBO = newVulkanBuffer(
    physicalDevice,
    dev.logicalDevice,
    indexSize,
    VK_BUFFER_USAGE_INDEX_BUFFER_BIT.VkBufferUsageFlags,
    memoryFlags
  )
  if indices.len > 0:
    indexSSBO.copyData(unsafeAddr indices[0], indexSize)

  # 3. Create Scene SSBO Buffer
  let sceneSSBO = newVulkanBuffer(
    physicalDevice,
    dev.logicalDevice,
    sizeof(GPUSceneData).VkDeviceSize,
    VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.VkBufferUsageFlags,
    memoryFlags
  )

  # 4. Create SSBO Pack / Descriptor Set
  let ssboPack = newSSBOPack(dev.logicalDevice, layout, vertexSSBO, sceneSSBO)

  # 5. Construct RenderModel
  var modelMatrix: Mat4
  glm_mat4_identity(modelMatrix)

  result = RenderModel(
    vertexBuffer: vertexSSBO.buffer,
    indexBuffer: indexSSBO.buffer,
    indexCount: indices.len.uint32,
    sceneSSBO: sceneSSBO,
    ssboPack: ssboPack,
    matrix: modelMatrix
  )

proc cleanup*(model: RenderModel) =
  model.sceneSSBO.cleanup()
  model.ssboPack.cleanup()

type
  VulkanRenderer* = ref object
    device*: VkDevice
    graphicsQueue*: VkQueue
    presentQueue*: VkQueue
    commandPool*: VkCommandPool
    commandBuffer*: VkCommandBuffer
    imageAvailableSemaphore*: VkSemaphore
    renderFinishedSemaphore*: VkSemaphore
    inFlightFence*: VkFence

proc newVulkanRenderer*(instance: VkInstance, device: VkDevice, graphicsFamily, presentFamily: uint32): VulkanRenderer =
  new(result)
  result.device = device

  loadLogicalDeviceProcs(instance, device)

  vkGetDeviceQueue(device, graphicsFamily, 0, addr result.graphicsQueue)
  vkGetDeviceQueue(device, presentFamily, 0, addr result.presentQueue)

  var poolInfo: VkCommandPoolCreateInfo
  poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
  poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT.VkCommandPoolCreateFlags
  poolInfo.queueFamilyIndex = graphicsFamily

  if vkCreateCommandPool(device, addr poolInfo, nil, addr result.commandPool) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Command Pool!")

  var allocInfo: VkCommandBufferAllocateInfo
  allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
  allocInfo.commandPool = result.commandPool
  allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
  allocInfo.commandBufferCount = 1

  if vkAllocateCommandBuffers(device, addr allocInfo, addr result.commandBuffer) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate Command Buffer!")

  var semaphoreInfo: VkSemaphoreCreateInfo
  semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO

  var fenceInfo: VkFenceCreateInfo
  fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
  fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT.VkFenceCreateFlags

  if vkCreateSemaphore(device, addr semaphoreInfo, nil, addr result.imageAvailableSemaphore) != VK_SUCCESS or
     vkCreateSemaphore(device, addr semaphoreInfo, nil, addr result.renderFinishedSemaphore) != VK_SUCCESS or
     vkCreateFence(device, addr fenceInfo, nil, addr result.inFlightFence) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Synchronization Primitives!")

proc recordCommandBuffer*(
    cb: VkCommandBuffer,
    swapchainImageView: VkImageView,
    depthResources: DepthResources,
    extent: VkExtent2D,
    pipeline: VulkanPipeline,
    models: openArray[RenderModel],
    viewProj: Mat4,
    cameraPos: Vec3,
    pushConstants: openArray[PushConstantValue]
) =
  var beginInfo = VkCommandBufferBeginInfo(sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO)
  discard vkBeginCommandBuffer(cb, addr beginInfo)

  # Color Attachment
  var colorAttachment = VkRenderingAttachmentInfo(
    sType: VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
    imageView: swapchainImageView,
    imageLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
    storeOp: VK_ATTACHMENT_STORE_OP_STORE,
    clearValue: VkClearValue(color: VkClearColorValue(float32: [0.05f, 0.05f, 0.05f, 1.0f]))
  )

  # Depth Attachment
  var depthAttachment = VkRenderingAttachmentInfo(
    sType: VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
    imageView: depthResources.view,
    imageLayout: VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL,
    loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
    storeOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
    clearValue: VkClearValue(depthStencil: VkClearDepthStencilValue(depth: 1.0f, stencil: 0))
  )

  # Dynamic Rendering Info
  var renderingInfo = VkRenderingInfo(
    sType: VK_STRUCTURE_TYPE_RENDERING_INFO,
    renderArea: VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: extent),
    layerCount: 1,
    colorAttachmentCount: 1,
    pColorAttachments: addr colorAttachment,
    pDepthAttachment: addr depthAttachment
  )

  vkCmdBeginRendering(cb, addr renderingInfo)

  var viewport = VkViewport(x: 0, y: 0, width: extent.width.float32, height: extent.height.float32, minDepth: 0, maxDepth: 1)
  var scissor = VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: extent)
  vkCmdSetViewport(cb, 0, 1, addr viewport)
  vkCmdSetScissor(cb, 0, 1, addr scissor)

  vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.pipeline)

  var pcBlock = initPushConstantBlock()

  for model in models:
    if model.indexCount == 0: continue

    # Upload ViewProjection to Model's Scene SSBO
    var sceneData = GPUSceneData(mvp: viewProj)
    model.sceneSSBO.copyData(addr sceneData, sizeof(GPUSceneData).VkDeviceSize)

    # Bind SSBO Descriptor Set (Set 0)
    var descriptorSet = model.ssboPack.descriptorSet
    vkCmdBindDescriptorSets(
      cb,
      VK_PIPELINE_BIND_POINT_GRAPHICS,
      pipeline.layout,
      0'u32,
      1'u32,
      addr descriptorSet,
      0,
      nil
    )

    # Bind Index Buffer
    vkCmdBindIndexBuffer(cb, model.indexBuffer, 0, VK_INDEX_TYPE_UINT32)

    # Dynamic Push Constant Buffer Writing
    pcBlock.clear()
    pcBlock.pushWrite(model.matrix) # 64 bytes (Offset 0)
    pcBlock.pushWrite(cameraPos)    # 12 bytes (Offset 64)

    # Stream dynamic PBR push constants sequentially into pcBlock
    for pc in pushConstants:
      case pc.kind
      of pckFloat:
        pcBlock.pushWrite(pc.floatVal)
      of pckVec3:
        pcBlock.pushWrite(pc.vec3Val)
      of pckMat4:
        pcBlock.pushWrite(pc.mat4Val)

    # Flush packed byte array to GPU
    pcBlock.flush(
      cb,
      pipeline.layout,
      cast[VkShaderStageFlags](VK_SHADER_STAGE_VERTEX_BIT.uint32 or VK_SHADER_STAGE_FRAGMENT_BIT.uint32)
    )

    # Draw Call
    vkCmdDrawIndexed(cb, model.indexCount, 1, 0, 0, 0)

  vkCmdEndRendering(cb)
  discard vkEndCommandBuffer(cb)

proc drawFrame*(
    r: VulkanRenderer,
    sc: VulkanSwapchain,
    depthResources: DepthResources,
    pipeline: VulkanPipeline,
    models: openArray[RenderModel],
    viewProj: Mat4,
    cameraPos: Vec3,
    pushConstants: openArray[PushConstantValue]
) =
  discard vkWaitForFences(r.device, 1, addr r.inFlightFence, true.VkBool32, uint64.high)
  discard vkResetFences(r.device, 1, addr r.inFlightFence)

  var imageIndex: uint32 = 0
  let res = vkAcquireNextImageKHR(r.device, sc.swapchain, uint64.high, r.imageAvailableSemaphore, cast[VkFence](0), addr imageIndex)
  if res != VK_SUCCESS and res != VK_SUBOPTIMAL_KHR:
    raise newException(Exception, "Failed to acquire next swapchain image! Code: " & $res)

  discard vkResetCommandBuffer(r.commandBuffer, cast[VkCommandBufferResetFlags](0))

  recordCommandBuffer(
    r.commandBuffer,
    sc.imageViews[imageIndex],
    depthResources,
    sc.extent,
    pipeline,
    models,
    viewProj,
    cameraPos,
    pushConstants
  )

  var waitSemaphores = [r.imageAvailableSemaphore]
  var waitStages = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.VkPipelineStageFlags]
  var signalSemaphores = [r.renderFinishedSemaphore]

  var submitInfo: VkSubmitInfo
  submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
  submitInfo.waitSemaphoreCount = 1
  submitInfo.pWaitSemaphores = addr waitSemaphores[0]
  submitInfo.pWaitDstStageMask = addr waitStages[0]
  submitInfo.commandBufferCount = 1
  submitInfo.pCommandBuffers = addr r.commandBuffer
  submitInfo.signalSemaphoreCount = 1
  submitInfo.pSignalSemaphores = addr signalSemaphores[0]

  if vkQueueSubmit(r.graphicsQueue, 1, addr submitInfo, r.inFlightFence) != VK_SUCCESS:
    raise newException(Exception, "Failed to submit queue!")

  var swapchains = [sc.swapchain]
  var presentInfo: VkPresentInfoKHR
  presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
  presentInfo.waitSemaphoreCount = 1
  presentInfo.pWaitSemaphores = addr signalSemaphores[0]
  presentInfo.swapchainCount = 1
  presentInfo.pSwapchains = addr swapchains[0]
  presentInfo.pImageIndices = addr imageIndex

  discard vkQueuePresentKHR(r.presentQueue, addr presentInfo)

proc cleanup*(r: VulkanRenderer) =
  if r == nil or cast[pointer](r.device) == nil: return
  discard vkDeviceWaitIdle(r.device)
  if cast[uint64](r.imageAvailableSemaphore) != 0: vkDestroySemaphore(r.device, r.imageAvailableSemaphore, nil)
  if cast[uint64](r.renderFinishedSemaphore) != 0: vkDestroySemaphore(r.device, r.renderFinishedSemaphore, nil)
  if cast[uint64](r.inFlightFence) != 0: vkDestroyFence(r.device, r.inFlightFence, nil)
  if cast[uint64](r.commandPool) != 0: vkDestroyCommandPool(r.device, r.commandPool, nil)