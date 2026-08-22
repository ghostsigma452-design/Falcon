import vk14

type
  VulkanRenderPass* = ref object
    device*: VkDevice
    renderPass*: VkRenderPass

proc newVulkanRenderPass*(device: VkDevice, swapchainFormat: VkFormat): VulkanRenderPass =
  new(result)
  result.device = device

  # 1. Color Attachment Description
  var colorAttachment: VkAttachmentDescription
  colorAttachment.format = swapchainFormat
  colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT
  colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
  colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE
  colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
  colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
  colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
  colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR

  # 2. Subpass Color Attachment Reference
  var colorAttachmentRef: VkAttachmentReference
  colorAttachmentRef.attachment = 0
  colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

  # 3. Subpass Description
  var subpass: VkSubpassDescription
  subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
  subpass.colorAttachmentCount = 1
  subpass.pColorAttachments = addr colorAttachmentRef

  # 4. Subpass Dependency
  var dependency: VkSubpassDependency
  dependency.srcSubpass = VK_SUBPASS_EXTERNAL
  dependency.dstSubpass = 0
  dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.VkPipelineStageFlags
  dependency.srcAccessMask = VkAccessFlags(0)
  dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.VkPipelineStageFlags
  dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT.VkAccessFlags

  # 5. Create Render Pass
  var renderPassInfo: VkRenderPassCreateInfo
  renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
  renderPassInfo.attachmentCount = 1
  renderPassInfo.pAttachments = addr colorAttachment
  renderPassInfo.subpassCount = 1
  renderPassInfo.pSubpasses = addr subpass
  renderPassInfo.dependencyCount = 1
  renderPassInfo.pDependencies = addr dependency

  if vkCreateRenderPass(device, addr renderPassInfo, nil, addr result.renderPass) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Vulkan Render Pass!")

proc cleanup*(rp: VulkanRenderPass) =
  if rp != nil and cast[pointer](rp.device) != nil and cast[uint64](rp.renderPass) != 0:
    if vkDestroyRenderPass != nil:
      vkDestroyRenderPass(rp.device, rp.renderPass, nil)