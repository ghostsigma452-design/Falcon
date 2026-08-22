# src/commands.nim
import vk14
import swapchain
import pipeline

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

proc newVulkanRenderer*(device: VkDevice, graphicsFamily, presentFamily: uint32): VulkanRenderer =
  new(result)
  result.device = device

  # Fetch Queue Handles
  vkGetDeviceQueue(device, graphicsFamily, 0, addr result.graphicsQueue)
  vkGetDeviceQueue(device, presentFamily, 0, addr result.presentQueue)

  # 1. Create Command Pool
  var poolInfo: VkCommandPoolCreateInfo
  poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
  poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT.VkCommandPoolCreateFlags
  poolInfo.queueFamilyIndex = graphicsFamily

  if vkCreateCommandPool(device, addr poolInfo, nil, addr result.commandPool) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Command Pool!")

  # 2. Allocate Command Buffer
  var allocInfo: VkCommandBufferAllocateInfo
  allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
  allocInfo.commandPool = result.commandPool
  allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
  allocInfo.commandBufferCount = 1

  if vkAllocateCommandBuffers(device, addr allocInfo, addr result.commandBuffer) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate Command Buffer!")

  # 3. Create Sync Objects
  var semaphoreInfo: VkSemaphoreCreateInfo
  semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO

  var fenceInfo: VkFenceCreateInfo
  fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
  fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT.VkFenceCreateFlags

  if vkCreateSemaphore(device, addr semaphoreInfo, nil, addr result.imageAvailableSemaphore) != VK_SUCCESS or
     vkCreateSemaphore(device, addr semaphoreInfo, nil, addr result.renderFinishedSemaphore) != VK_SUCCESS or
     vkCreateFence(device, addr fenceInfo, nil, addr result.inFlightFence) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Synchronization Primitives!")

proc recordCommandBuffer(
    cb: VkCommandBuffer,
    renderPass: VkRenderPass,
    framebuffer: VkFramebuffer,
    extent: VkExtent2D,
    pipeline: VkPipeline
) =
  var beginInfo: VkCommandBufferBeginInfo
  beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO

  if vkBeginCommandBuffer(cb, addr beginInfo) != VK_SUCCESS:
    raise newException(Exception, "Failed to begin recording Command Buffer!")

  var clearColor = VkClearValue(
    color: VkClearColorValue(float32: [0.0f, 0.0f, 0.0f, 1.0f])
  )

  var renderPassInfo: VkRenderPassBeginInfo
  renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
  renderPassInfo.renderPass = renderPass
  renderPassInfo.framebuffer = framebuffer
  renderPassInfo.renderArea.offset = VkOffset2D(x: 0, y: 0)
  renderPassInfo.renderArea.extent = extent
  renderPassInfo.clearValueCount = 1
  renderPassInfo.pClearValues = addr clearColor

  vkCmdBeginRenderPass(cb, addr renderPassInfo, VK_SUBPASS_CONTENTS_INLINE)

  # Bind Dynamic State Viewport & Scissor
  var viewport: VkViewport
  viewport.x = 0.0f
  viewport.y = 0.0f
  viewport.width = extent.width.float32
  viewport.height = extent.height.float32
  viewport.minDepth = 0.0f
  viewport.maxDepth = 1.0f
  vkCmdSetViewport(cb, 0, 1, addr viewport)

  var scissor: VkRect2D
  scissor.offset = VkOffset2D(x: 0, y: 0)
  scissor.extent = extent
  vkCmdSetScissor(cb, 0, 1, addr scissor)

  # Bind Pipeline and Issue Draw Command
  vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline)
  vkCmdDraw(cb, 3, 1, 0, 0) # 3 vertices, 1 instance

  vkCmdEndRenderPass(cb)

  if vkEndCommandBuffer(cb) != VK_SUCCESS:
    raise newException(Exception, "Failed to record Command Buffer!")

proc drawFrame*(
    r: VulkanRenderer,
    sc: VulkanSwapchain,
    renderPass: VkRenderPass,
    pipeline: VulkanPipeline
) =
  # Wait for prior frame execution
  discard vkWaitForFences(r.device, 1, addr r.inFlightFence, true.VkBool32, uint64.high)
  discard vkResetFences(r.device, 1, addr r.inFlightFence)

  # 1. Acquire Image from Swapchain
  var imageIndex: uint32 = 0
  discard vkAcquireNextImageKHR(
    r.device,
    sc.swapchain,
    uint64.high,
    r.imageAvailableSemaphore,
    cast[VkFence](0),
    addr imageIndex
  )

  # 2. Record Draw Commands
  discard vkResetCommandBuffer(r.commandBuffer, cast[VkCommandBufferResetFlags](0))
  recordCommandBuffer(
    r.commandBuffer,
    renderPass,
    sc.framebuffers[imageIndex],
    sc.extent,
    pipeline.pipeline
  )

  # 3. Submit Commands to Graphics Queue
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
    raise newException(Exception, "Failed to submit draw Command Buffer!")

  # 4. Present Frame to Screen
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
  if r == nil or cast[pointer](r.device) == nil:
    return

  discard vkDeviceWaitIdle(r.device)

  if cast[uint64](r.imageAvailableSemaphore) != 0 and cast[pointer](vkDestroySemaphore) != nil:
    vkDestroySemaphore(r.device, r.imageAvailableSemaphore, nil)

  if cast[uint64](r.renderFinishedSemaphore) != 0 and cast[pointer](vkDestroySemaphore) != nil:
    vkDestroySemaphore(r.device, r.renderFinishedSemaphore, nil)

  if cast[uint64](r.inFlightFence) != 0 and cast[pointer](vkDestroyFence) != nil:
    vkDestroyFence(r.device, r.inFlightFence, nil)

  if cast[uint64](r.commandPool) != 0 and cast[pointer](vkDestroyCommandPool) != nil:
    vkDestroyCommandPool(r.device, r.commandPool, nil)