import vk14
import buffer
import stb_image/read as stbi

type
  Texture* = object
    image*: VkImage
    memory*: VkDeviceMemory
    view*: VkImageView
    sampler*: VkSampler
    textureIndex*: uint32

proc loadTexture*(
    device: VkDevice,
    physicalDevice: VkPhysicalDevice,
    commandPool: VkCommandPool,
    graphicsQueue: VkQueue,
    bindlessSet: VkDescriptorSet,
    sampler: VkSampler,
    path: string,
    textureIndex: uint32
): Texture =
  # 1. Load image using stbi wrapper
  var width, height, channels: int
  let data = stbi.load(path, width, height, channels, stbi.Default)
  
  if data.len == 0:
    raise newException(Exception, "Failed to load image file: " & path)

  let imageSize = (width * height * channels).VkDeviceSize

  # 2. Fixed parameter order (physicalDevice first) matching buffer.nim[cite: 1]
  var stagingBuffer = newVulkanBuffer(
    physicalDevice, device,
    imageSize,
    cast[VkBufferUsageFlags](VK_BUFFER_USAGE_TRANSFER_SRC_BIT.uint32),
    cast[VkMemoryPropertyFlags](VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.uint32 or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.uint32)
  )
  
  # 3. Fixed copyData call signature[cite: 1]
  copyData(stagingBuffer, unsafeAddr data[0], imageSize)

  # 4. Determine format based on channel count
  let vkFormat = if channels == 4: VK_FORMAT_R8G8B8A8_SRGB else: VK_FORMAT_R8G8B8_SRGB

  var imageInfo = VkImageCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
    imageType: VK_IMAGE_TYPE_2D,
    format: vkFormat,
    extent: VkExtent3D(width: width.uint32, height: height.uint32, depth: 1),
    mipLevels: 1,
    arrayLayers: 1,
    samples: VK_SAMPLE_COUNT_1_BIT,
    tiling: VK_IMAGE_TILING_OPTIMAL,
    usage: cast[VkImageUsageFlags](VK_IMAGE_USAGE_TRANSFER_DST_BIT.uint32 or VK_IMAGE_USAGE_SAMPLED_BIT.uint32),
    sharingMode: VK_SHARING_MODE_EXCLUSIVE,
    initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
  )

  if vkCreateImage(device, addr imageInfo, nil, addr result.image) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Vulkan texture image!")

  # 5. Fixed aspectMask cast to VkImageAspectFlags
  var viewInfo = VkImageViewCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    image: result.image,
    viewType: VK_IMAGE_VIEW_TYPE_2D,
    format: vkFormat,
    subresourceRange: VkImageSubresourceRange(
      aspectMask: cast[VkImageAspectFlags](VK_IMAGE_ASPECT_COLOR_BIT.uint32),
      baseMipLevel: 0,
      levelCount: 1,
      baseArrayLayer: 0,
      layerCount: 1
    )
  )

  if vkCreateImageView(device, addr viewInfo, nil, addr result.view) != VK_SUCCESS:
    raise newException(Exception, "Failed to create texture image view!")

  # 6. Update the bindless descriptor set at `set = 1`
  var imageDescriptorInfo = VkDescriptorImageInfo(
    sampler: sampler,
    imageView: result.view,
    imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
  )

  var descriptorWrite = VkWriteDescriptorSet(
    sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
    dstSet: bindlessSet,
    dstBinding: 0,
    dstArrayElement: textureIndex,
    descriptorCount: 1,
    descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
    pImageInfo: addr imageDescriptorInfo
  )

  vkUpdateDescriptorSets(device, 1, addr descriptorWrite, 0, nil)

  result.sampler = sampler
  result.textureIndex = textureIndex