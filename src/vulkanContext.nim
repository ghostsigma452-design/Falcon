import command, device, renderpass, swapchain, vkLoader, vk14, window

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

proc initVk*(ctx: var vulkanContext) =
    var swapchain = newSwapchain(ctx, 1000, 1000)
    let renderPass = newVulkanRenderPass(ctx.device.logicalDevice, swapchain.format)
    let renderer = newVulkanRenderer(ctx.instance, ctx.device.logicalDevice, ctx.queueIndices.graphicsFamily.uint32, ctx.queueIndices.presentFamily.uint32)
    swapchain.createFramebuffers(renderPass.renderPass)

    ctx.swapchain = swapchain
    ctx.renderPass = renderPass
    ctx.renderer = renderer



proc destroy*(ctx: vulkanContext) =
  ctx.renderer.cleanup()
  ctx.renderPass.cleanup()
  ctx.swapchain.cleanup()
  ctx.device.cleanup()


