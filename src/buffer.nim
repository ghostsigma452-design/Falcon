# src/buffer.nim
import vk14

type
  VulkanBuffer* = ref object
    device*: VkDevice
    buffer*: VkBuffer
    memory*: VkDeviceMemory
    size*: VkDeviceSize

# Helper to find correct memory type index on GPU
proc findMemoryType*(
    physicalDevice: VkPhysicalDevice,
    typeFilter: uint32,
    properties: VkMemoryPropertyFlags
): uint32 =
  var memProperties: VkPhysicalDeviceMemoryProperties
  vkGetPhysicalDeviceMemoryProperties(physicalDevice, addr memProperties)

  let reqProps = properties.uint32

  for i in 0..<memProperties.memoryTypeCount:
    let matchBit = (typeFilter and (1.uint32 shl i)) != 0
    let currentProps = memProperties.memoryTypes[i].propertyFlags.uint32

    if matchBit and (currentProps and reqProps) == reqProps:
      return i

  raise newException(Exception, "Failed to find suitable memory type!")

# Create Vulkan Buffer and allocate memory
proc newVulkanBuffer*(
    physicalDevice: VkPhysicalDevice,
    device: VkDevice,
    size: VkDeviceSize,
    usage: VkBufferUsageFlags,
    properties: VkMemoryPropertyFlags
): VulkanBuffer =
  new(result)
  result.device = device
  result.size = size

  # 1. Create Buffer Handle
  var bufferInfo: VkBufferCreateInfo
  bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
  bufferInfo.size = size
  bufferInfo.usage = usage
  bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE

  if vkCreateBuffer(device, addr bufferInfo, nil, addr result.buffer) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Vulkan Buffer!")

  # 2. Get Memory Requirements
  var memRequirements: VkMemoryRequirements
  vkGetBufferMemoryRequirements(device, result.buffer, addr memRequirements)

  # 3. Allocate GPU Memory
  var allocInfo: VkMemoryAllocateInfo
  allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
  allocInfo.allocationSize = memRequirements.size
  allocInfo.memoryTypeIndex = findMemoryType(physicalDevice, memRequirements.memoryTypeBits, properties)

  if vkAllocateMemory(device, addr allocInfo, nil, addr result.memory) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate Buffer Memory!")

  # 4. Bind Memory to Buffer
  discard vkBindBufferMemory(device, result.buffer, result.memory, 0)



# Map data from host RAM to GPU buffer
proc copyData*(buf: VulkanBuffer, data: pointer, size: VkDeviceSize) =
  var mapped: pointer
  if vkMapMemory(buf.device, buf.memory, 0, size, cast[VkMemoryMapFlags](0), addr mapped) == VK_SUCCESS:
    copyMem(mapped, data, size)
    vkUnmapMemory(buf.device, buf.memory)

# Copy staging buffer to GPU-local buffer
proc copyBuffer*(
    device: VkDevice,
    commandPool: VkCommandPool,
    queue: VkQueue,
    srcBuffer, dstBuffer: VkBuffer,
    size: VkDeviceSize
) =
  var allocInfo: VkCommandBufferAllocateInfo
  allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
  allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
  allocInfo.commandPool = commandPool
  allocInfo.commandBufferCount = 1

  var cmdBuffer: VkCommandBuffer
  discard vkAllocateCommandBuffers(device, addr allocInfo, addr cmdBuffer)

  var beginInfo: VkCommandBufferBeginInfo
  beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.VkCommandBufferUsageFlags

  discard vkBeginCommandBuffer(cmdBuffer, addr beginInfo)

  var copyRegion: VkBufferCopy
  copyRegion.srcOffset = 0
  copyRegion.dstOffset = 0
  copyRegion.size = size
  vkCmdCopyBuffer(cmdBuffer, srcBuffer, dstBuffer, 1, addr copyRegion)

  discard vkEndCommandBuffer(cmdBuffer)

  var submitInfo: VkSubmitInfo
  submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
  submitInfo.commandBufferCount = 1
  submitInfo.pCommandBuffers = addr cmdBuffer

  discard vkQueueSubmit(queue, 1, addr submitInfo, cast[VkFence](0))
  discard vkQueueWaitIdle(queue)

  vkFreeCommandBuffers(device, commandPool, 1, addr cmdBuffer)

# Cleanup Buffer
proc cleanup*(buf: VulkanBuffer) =
  if buf == nil or cast[pointer](buf.device) == nil:
    return

  if cast[uint64](buf.buffer) != 0 and cast[pointer](vkDestroyBuffer) != nil:
    vkDestroyBuffer(buf.device, buf.buffer, nil)
    buf.buffer = cast[VkBuffer](0)

  if cast[uint64](buf.memory) != 0 and cast[pointer](vkFreeMemory) != nil:
    vkFreeMemory(buf.device, buf.memory, nil)
    buf.memory = cast[VkDeviceMemory](0)