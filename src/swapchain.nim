# src/swapchain.nim
import vk14
import device

type
  SwapchainSupportDetails* = object
    capabilities*: VkSurfaceCapabilitiesKHR
    formats*: seq[VkSurfaceFormatKHR]
    presentModes*: seq[VkPresentModeKHR]

  VulkanSwapchain* = ref object
    device*: VkDevice
    swapchain*: VkSwapchainKHR
    format*: VkFormat
    extent*: VkExtent2D
    images*: seq[VkImage]
    imageViews*: seq[VkImageView]
    framebuffers*: seq[VkFramebuffer]

proc querySwapchainSupport*(physicalDevice: VkPhysicalDevice, surface: VkSurfaceKHR): SwapchainSupportDetails =
  discard vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, addr result.capabilities)

  var formatCount: uint32 = 0
  discard vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, addr formatCount, nil)
  if formatCount > 0:
    result.formats = newSeq[VkSurfaceFormatKHR](formatCount)
    discard vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, addr formatCount, addr result.formats[0])

  var presentModeCount: uint32 = 0
  discard vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, addr presentModeCount, nil)
  if presentModeCount > 0:
    result.presentModes = newSeq[VkPresentModeKHR](presentModeCount)
    discard vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, addr presentModeCount, addr result.presentModes[0])

proc chooseSurfaceFormat(availableFormats: openArray[VkSurfaceFormatKHR]): VkSurfaceFormatKHR =
  for available in availableFormats:
    if available.format == VK_FORMAT_B8G8R8A8_SRGB and available.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR:
      return available
  return availableFormats[0]

proc choosePresentMode(availablePresentModes: openArray[VkPresentModeKHR]): VkPresentModeKHR =
  for mode in availablePresentModes:
    if mode == VK_PRESENT_MODE_MAILBOX_KHR:
      return mode
  return VK_PRESENT_MODE_FIFO_KHR

proc chooseExtent(capabilities: VkSurfaceCapabilitiesKHR, width, height: int): VkExtent2D =
  if capabilities.currentExtent.width != uint32.high:
    return capabilities.currentExtent

  result.width = clamp(width.uint32, capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
  result.height = clamp(height.uint32, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)

proc newVulkanSwapchain*(
    physicalDevice: VkPhysicalDevice,
    device: VkDevice,
    surface: VkSurfaceKHR,
    queueIndices: QueueFamilyIndices,
    width, height: int
): VulkanSwapchain =
  new(result)
  result.device = device

  let details = querySwapchainSupport(physicalDevice, surface)
  let surfaceFormat = chooseSurfaceFormat(details.formats)
  let presentMode = choosePresentMode(details.presentModes)
  let extent = chooseExtent(details.capabilities, width, height)

  var imageCount = details.capabilities.minImageCount + 1
  if details.capabilities.maxImageCount > 0 and imageCount > details.capabilities.maxImageCount:
    imageCount = details.capabilities.maxImageCount

  result.format = surfaceFormat.format
  result.extent = extent

  var createInfo: VkSwapchainCreateInfoKHR
  createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
  createInfo.surface = surface
  createInfo.minImageCount = imageCount
  createInfo.imageFormat = surfaceFormat.format
  createInfo.imageColorSpace = surfaceFormat.colorSpace
  createInfo.imageExtent = extent
  createInfo.imageArrayLayers = 1
  createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.VkImageUsageFlags

  var families = [queueIndices.graphicsFamily.uint32, queueIndices.presentFamily.uint32]
  if queueIndices.graphicsFamily != queueIndices.presentFamily:
    createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT
    createInfo.queueFamilyIndexCount = 2
    createInfo.pQueueFamilyIndices = addr families[0]
  else:
    createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE

  createInfo.preTransform = details.capabilities.currentTransform
  createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
  createInfo.presentMode = presentMode
  createInfo.clipped = true.VkBool32

  if vkCreateSwapchainKHR(device, addr createInfo, nil, addr result.swapchain) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Vulkan Swapchain!")

  var actualImageCount: uint32 = 0
  discard vkGetSwapchainImagesKHR(device, result.swapchain, addr actualImageCount, nil)
  result.images = newSeq[VkImage](actualImageCount)
  discard vkGetSwapchainImagesKHR(device, result.swapchain, addr actualImageCount, addr result.images[0])

  result.imageViews = newSeq[VkImageView](actualImageCount)
  for i in 0..<actualImageCount.int:
    var viewInfo: VkImageViewCreateInfo
    viewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
    viewInfo.image = result.images[i]
    viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
    viewInfo.format = result.format
    viewInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY
    viewInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY
    viewInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY
    viewInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY
    viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.VkImageAspectFlags
    viewInfo.subresourceRange.baseMipLevel = 0
    viewInfo.subresourceRange.levelCount = 1
    viewInfo.subresourceRange.baseArrayLayer = 0
    viewInfo.subresourceRange.layerCount = 1

    if vkCreateImageView(device, addr viewInfo, nil, addr result.imageViews[i]) != VK_SUCCESS:
      raise newException(Exception, "Failed to create Swapchain Image View!")

proc createFramebuffers*(sc: VulkanSwapchain, renderPass: VkRenderPass) =
  sc.framebuffers = newSeq[VkFramebuffer](sc.imageViews.len)

  for i in 0..<sc.imageViews.len:
    var attachments = [sc.imageViews[i]]

    var fbInfo: VkFramebufferCreateInfo
    fbInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
    fbInfo.renderPass = renderPass
    fbInfo.attachmentCount = 1
    fbInfo.pAttachments = addr attachments[0]
    fbInfo.width = sc.extent.width
    fbInfo.height = sc.extent.height
    fbInfo.layers = 1

    if vkCreateFramebuffer(sc.device, addr fbInfo, nil, addr sc.framebuffers[i]) != VK_SUCCESS:
      raise newException(Exception, "Failed to create Vulkan Framebuffer!")

# Safe Cleanup
proc cleanup*(sc: VulkanSwapchain) =
  if sc == nil or cast[pointer](sc.device) == nil:
    return

  if sc.framebuffers.len > 0 and cast[pointer](vkDestroyFramebuffer) != nil:
    for fb in sc.framebuffers:
      if cast[uint64](fb) != 0:
        vkDestroyFramebuffer(sc.device, fb, nil)

  if sc.imageViews.len > 0 and cast[pointer](vkDestroyImageView) != nil:
    for iv in sc.imageViews:
      if cast[uint64](iv) != 0:
        vkDestroyImageView(sc.device, iv, nil)

  if cast[uint64](sc.swapchain) != 0 and cast[pointer](vkDestroySwapchainKHR) != nil:
    vkDestroySwapchainKHR(sc.device, sc.swapchain, nil)