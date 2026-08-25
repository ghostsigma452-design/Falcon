import command, descriptors, device, pipeline, renderpass, swapchain, vkLoader, vk14, window

type
    vulkanContext* = ref object 
        instance*: VkInstance
        surface*: VkSurfaceKHR
        physicalDevice*: VkPhysicalDevice
        queueIndices*: QueueFamilyIndices
        device*: VulkanDevice

proc initVk*(win: VulkanWindow): vulkanContext =
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



proc destroy(ctx: vulkanContext) =

    ctx.device.cleanup()

