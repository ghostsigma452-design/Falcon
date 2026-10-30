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

proc createTextureSampler*(device: VkDevice): VkSampler =
  var samplerInfo = VkSamplerCreateInfo(
    sType: VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
    magFilter: VK_FILTER_LINEAR,
    minFilter: VK_FILTER_LINEAR,
    mipmapMode: VK_SAMPLER_MIPMAP_MODE_LINEAR,
    addressModeU: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    addressModeV: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    addressModeW: VK_SAMPLER_ADDRESS_MODE_REPEAT,
    anisotropyEnable: true.VkBool32,
    maxAnisotropy: 16.0f,
    borderColor: VK_BORDER_COLOR_INT_OPAQUE_BLACK,
    unnormalizedCoordinates: false.VkBool32,
    compareEnable: false.VkBool32,
    compareOp: VK_COMPARE_OP_ALWAYS,
    minLod: 0.0f,
    maxLod: 0.0f,
    mipLodBias: 0.0f
  )
  if vkCreateSampler(device, addr samplerInfo, nil, addr result) != VK_SUCCESS:
    raise newException(Exception, "Failed to create texture sampler!")

# Helper for single-time command buffer execution
proc beginSingleTimeCommands(device: VkDevice, commandPool: VkCommandPool): VkCommandBuffer =
  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandPool: commandPool,
    commandBufferCount: 1'u32
  )
  var commandBuffer: VkCommandBuffer
  discard vkAllocateCommandBuffers(device, addr allocInfo, addr commandBuffer)

  var beginInfo = VkCommandBufferBeginInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    flags: cast[VkCommandBufferUsageFlags](VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.uint32)
  )
  discard vkBeginCommandBuffer(commandBuffer, addr beginInfo)
  return commandBuffer

proc endSingleTimeCommands(device: VkDevice, commandPool: VkCommandPool, graphicsQueue: VkQueue, commandBuffer: VkCommandBuffer) =
  discard vkEndCommandBuffer(commandBuffer)

  var submitInfo = VkSubmitInfo(
    sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
    commandBufferCount: 1'u32,
    pCommandBuffers: addr commandBuffer
  )
  # Fixed VkQueueSubmit argument types (1'u32 count and VkFence(0))
  discard vkQueueSubmit(graphicsQueue, 1'u32, addr submitInfo, VkFence(0))
  discard vkQueueWaitIdle(graphicsQueue)
  vkFreeCommandBuffers(device, commandPool, 1'u32, addr commandBuffer)

proc transitionImageLayout(device: VkDevice, commandPool: VkCommandPool, graphicsQueue: VkQueue, image: VkImage, oldLayout, newLayout: VkImageLayout) =
  var commandBuffer = beginSingleTimeCommands(device, commandPool)

  var barrier = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    oldLayout: oldLayout,
    newLayout: newLayout,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: image,
    subresourceRange: VkImageSubresourceRange(
      aspectMask: cast[VkImageAspectFlags](VK_IMAGE_ASPECT_COLOR_BIT.uint32),
      baseMipLevel: 0,
      levelCount: 1,
      baseArrayLayer: 0,
      layerCount: 1
    )
  )

  var sourceStage: VkPipelineStageFlags
  var destinationStage: VkPipelineStageFlags

  if oldLayout == VK_IMAGE_LAYOUT_UNDEFINED and newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL:
    barrier.srcAccessMask = cast[VkAccessFlags](0)
    barrier.dstAccessMask = cast[VkAccessFlags](VK_ACCESS_TRANSFER_WRITE_BIT.uint32)
    sourceStage = cast[VkPipelineStageFlags](VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT.uint32)
    destinationStage = cast[VkPipelineStageFlags](VK_PIPELINE_STAGE_TRANSFER_BIT.uint32)
  elif oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL:
    barrier.srcAccessMask = cast[VkAccessFlags](VK_ACCESS_TRANSFER_WRITE_BIT.uint32)
    barrier.dstAccessMask = cast[VkAccessFlags](VK_ACCESS_SHADER_READ_BIT.uint32)
    sourceStage = cast[VkPipelineStageFlags](VK_PIPELINE_STAGE_TRANSFER_BIT.uint32)
    destinationStage = cast[VkPipelineStageFlags](VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT.uint32)
  else:
    raise newException(Exception, "Unsupported layout transition!")

  # Fixed argument types and distinct casts for VkCmdPipelineBarrier
  vkCmdPipelineBarrier(
    commandBuffer,
    sourceStage,
    destinationStage,
    cast[VkDependencyFlags](0),
    0'u32, nil,
    0'u32, nil,
    1'u32, addr barrier
  )

  endSingleTimeCommands(device, commandPool, graphicsQueue, commandBuffer)

proc copyBufferToImage(device: VkDevice, commandPool: VkCommandPool, graphicsQueue: VkQueue, buffer: VkBuffer, image: VkImage, width, height: uint32) =
  var commandBuffer = beginSingleTimeCommands(device, commandPool)

  var region = VkBufferImageCopy(
    bufferOffset: 0,
    bufferRowLength: 0,
    bufferImageHeight: 0,
    imageSubresource: VkImageSubresourceLayers(
      aspectMask: cast[VkImageAspectFlags](VK_IMAGE_ASPECT_COLOR_BIT.uint32),
      mipLevel: 0,
      baseArrayLayer: 0,
      layerCount: 1
    ),
    imageOffset: VkOffset3D(x: 0, y: 0, z: 0),
    imageExtent: VkExtent3D(width: width, height: height, depth: 1)
  )

  vkCmdCopyBufferToImage(commandBuffer, buffer, image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1'u32, addr region)
  endSingleTimeCommands(device, commandPool, graphicsQueue, commandBuffer)

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
  let data = stbi.load(path, width, height, channels ,RGBA)
  
  if data.len == 0:
    raise newException(Exception, "Failed to load image file: " & path)

  let imageSize = (width * height * channels).VkDeviceSize

  # 2. Create Staging Buffer
  var stagingBuffer = newVulkanBuffer(
    physicalDevice, device,
    imageSize,
    cast[VkBufferUsageFlags](VK_BUFFER_USAGE_TRANSFER_SRC_BIT.uint32),
    cast[VkMemoryPropertyFlags](VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.uint32 or VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.uint32)
  )
  copyData(stagingBuffer, unsafeAddr data[0], imageSize)

  # 3. Create Vulkan Image
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

  # 4. Allocate and Bind Device Memory
  var memRequirements: VkMemoryRequirements
  vkGetImageMemoryRequirements(device, result.image, addr memRequirements)

  var allocInfo = VkMemoryAllocateInfo(
    sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    allocationSize: memRequirements.size,
    memoryTypeIndex: findMemoryType(physicalDevice, memRequirements.memoryTypeBits, cast[VkMemoryPropertyFlags](VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.uint32))
  )

  if vkAllocateMemory(device, addr allocInfo, nil, addr result.memory) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate texture image memory!")
  
  # Discard result of vkBindImageMemory (returns VkResult)
  discard vkBindImageMemory(device, result.image, result.memory, 0)

  # 5. Transition layout, copy buffer to image, transition to shader read-only
  transitionImageLayout(device, commandPool, graphicsQueue, result.image, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
  copyBufferToImage(device, commandPool, graphicsQueue, stagingBuffer.buffer, result.image, width.uint32, height.uint32)
  transitionImageLayout(device, commandPool, graphicsQueue, result.image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

  # 6. Create Image View
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

  # 7. Update the Bindless Descriptor Set at `set = 1`
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
    descriptorCount: 1'u32,
    descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
    pImageInfo: addr imageDescriptorInfo
  )

  vkUpdateDescriptorSets(device, 1'u32, addr descriptorWrite, 0'u32, nil)

  result.sampler = sampler
  result.textureIndex = textureIndex