import command, device, renderpass, swapchain, vkLoader, vk14, window, pipeline

type
    vulkanContext* = ref object 
        instance*: VkInstance
        surface*: VkSurfaceKHR
        physicalDevice*: VkPhysicalDevice
        queueIndices*: QueueFamilyIndices
        device*: VulkanDevice
        swapchain*: VulkanSwapchain
        renderPass*: VulkanRenderPass
        renderer*: VulkanRenderer
        globalLayout*: VkDescriptorSetLayout

proc createGlobalDescriptorLayout(device: VkDevice): VkDescriptorSetLayout =
  var bindings: array[2, VkDescriptorSetLayoutBinding]

  # Binding 0: Vertex Buffer SSBO
  bindings[0].binding = 0
  bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
  bindings[0].descriptorCount = 1
  bindings[0].stageFlags = VK_SHADER_STAGE_VERTEX_BIT.VkShaderStageFlags

  # Binding 1: Scene Matrix SSBO
  bindings[1].binding = 1
  bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
  bindings[1].descriptorCount = 1
  bindings[1].stageFlags = VK_SHADER_STAGE_VERTEX_BIT.VkShaderStageFlags

  var layoutInfo: VkDescriptorSetLayoutCreateInfo
  layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
  layoutInfo.bindingCount = bindings.len.uint32
  layoutInfo.pBindings = addr bindings[0]

  if vkCreateDescriptorSetLayout(device, addr layoutInfo, nil, addr result) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Global Descriptor Set Layout!")

proc newVk*(win: VulkanWindow): vulkanContext =
    new(result)

    let instance = win.vkInstance
    let surface = win.vkSurface
    loadPhysicalDeviceProcs(instance)
    let (physicalDevice, queueIndices) = pickPhysicalDevice(instance, surface)
    let dev = newVulkanDevice(instance, physicalDevice, queueIndices)
    loadLogicalDeviceProcs(win.vkInstance, dev.logicalDevice)
    result.instance = instance
    result.surface = surface
    result.physicalDevice = physicalDevice
    result.queueIndices = queueIndices
    result.device = dev
    

proc newSwapchain*(ctx: vulkanContext, width: int, height: int): VulkanSwapchain =
  return newVulkanSwapchain(ctx.physicalDevice, ctx.device.logicalDevice, ctx.surface, ctx.queueIndices, width, height)

proc createPipeline*(
    ctx: vulkanContext,
    vertPath, fragPath: string,
    extraLayouts: openArray[VkDescriptorSetLayout] = []
): VulkanPipeline =
  # Combine globalLayout (Set 0) with any custom material/shader layouts (Set 1, Set 2...)
  var allLayouts = @[ctx.globalLayout]
  for l in extraLayouts:
    allLayouts.add(l)

  var pipelineLayoutInfo: VkPipelineLayoutCreateInfo
  pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
  pipelineLayoutInfo.setLayoutCount = allLayouts.len.uint32
  pipelineLayoutInfo.pSetLayouts = addr allLayouts[0]

  return newVulkanPipeline(
    ctx.device.logicalDevice,
    ctx.renderPass.renderPass,
    ctx.swapchain.extent,
    ctx.globalLayout, # or ctx.ssboPack.layout depending on your field name
    vertPath,
    fragPath
  )

proc initVk*(ctx: var vulkanContext) =
    var swapchain = newSwapchain(ctx, 1000, 1000)
    let renderPass = newVulkanRenderPass(ctx.device.logicalDevice, swapchain.format)
    let renderer = newVulkanRenderer(ctx.instance, ctx.device.logicalDevice, ctx.queueIndices.graphicsFamily.uint32, ctx.queueIndices.presentFamily.uint32)
    swapchain.createFramebuffers(renderPass.renderPass)

    ctx.swapchain = swapchain
    ctx.renderPass = renderPass
    ctx.renderer = renderer

    ctx.globalLayout = createGlobalDescriptorLayout(ctx.device.logicalDevice)



proc destroy*(ctx: vulkanContext) =
  ctx.renderer.cleanup()
  ctx.renderPass.cleanup()
  ctx.swapchain.cleanup()
  ctx.device.cleanup()


