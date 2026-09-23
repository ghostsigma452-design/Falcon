import vk14

type DepthResources* = object
  image*: VkImage
  memory*: VkDeviceMemory
  view*: VkImageView

proc findMemoryType*(physicalDevice: VkPhysicalDevice, typeFilter: uint32, properties: VkMemoryPropertyFlags): uint32 =
  var memProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(physicalDevice, addr memProperties)
  
  for i in 0'u32 ..< memProperties.memoryTypeCount:
    let propFlags = memProperties.memoryTypes[i].propertyFlags.uint32
    let reqFlags = properties.uint32
    if (typeFilter and (1'u32 shl i)) != 0 and (propFlags and reqFlags) == reqFlags:
      return i
      
  raise newException(Exception, "Failed to find suitable memory type!")

proc createDepthResources*(
    physicalDevice: VkPhysicalDevice,
    device: VkDevice,
    extent: VkExtent2D,
    format: VkFormat = VK_FORMAT_D32_SFLOAT
): DepthResources =
  # 1. Create Image
  var imageInfo = VkImageCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
    imageType: VK_IMAGE_TYPE_2D,
    extent: VkExtent3D(width: extent.width, height: extent.height, depth: 1),
    mipLevels: 1,
    arrayLayers: 1,
    format: format,
    tiling: VK_IMAGE_TILING_OPTIMAL,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
    usage: VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT.VkImageUsageFlags,
    samples: VK_SAMPLE_COUNT_1_BIT,
    sharingMode: VK_SHARING_MODE_EXCLUSIVE
  )
  if vkCreateImage(device, addr imageInfo, nil, addr result.image) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Depth Image!")

  # 2. Allocate & Bind Memory
  var memReqs: VkMemoryRequirements
  vkGetImageMemoryRequirements(device, result.image, addr memReqs)

  var allocInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: memReqs.size,
    memoryTypeIndex: findMemoryType(
      physicalDevice, 
      memReqs.memoryTypeBits, 
      VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.VkMemoryPropertyFlags
    )
  )
  if vkAllocateMemory(device, addr allocInfo, nil, addr result.memory) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate Depth Memory!")

  discard vkBindImageMemory(device, result.image, result.memory, 0)

  # 3. Create ImageView
  var viewInfo = VkImageViewCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    image: result.image,
    viewType: VK_IMAGE_VIEW_TYPE_2D,
    format: format,
    subresourceRange: VkImageSubresourceRange(
      aspectMask: VK_IMAGE_ASPECT_DEPTH_BIT.VkImageAspectFlags,
      baseMipLevel: 0,
      levelCount: 1,
      baseArrayLayer: 0,
      layerCount: 1
    )
  )
  if vkCreateImageView(device, addr viewInfo, nil, addr result.view) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Depth Image View!")

proc cleanup*(d: DepthResources, device: VkDevice) =
  if cast[uint64](d.view) != 0: vkDestroyImageView(device, d.view, nil)
  if cast[uint64](d.image) != 0: vkDestroyImage(device, d.image, nil)
  if cast[uint64](d.memory) != 0: vkFreeMemory(device, d.memory, nil)