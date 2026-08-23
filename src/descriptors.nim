# src/descriptors.nim
import vk14
import buffer

type
  SSBOPack* = ref object
    device*: VkDevice
    layout*: VkDescriptorSetLayout
    pool*: VkDescriptorPool
    descriptorSet*: VkDescriptorSet

proc newSSBOPack*(
    device: VkDevice,
    vertexBuffer: VulkanBuffer,
    sceneBuffer: VulkanBuffer
): SSBOPack =
  new(result)
  result.device = device

  # 1. Define Layout Bindings (Binding 0 = Vertices, Binding 1 = Scene Matrix)
  var bindings: array[2, VkDescriptorSetLayoutBinding]

  bindings[0].binding = 0
  bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
  bindings[0].descriptorCount = 1
  bindings[0].stageFlags = VK_SHADER_STAGE_VERTEX_BIT.VkShaderStageFlags

  bindings[1].binding = 1
  bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
  bindings[1].descriptorCount = 1
  bindings[1].stageFlags = VK_SHADER_STAGE_VERTEX_BIT.VkShaderStageFlags

  var layoutInfo: VkDescriptorSetLayoutCreateInfo
  layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
  layoutInfo.bindingCount = bindings.len.uint32
  layoutInfo.pBindings = addr bindings[0]

  if vkCreateDescriptorSetLayout(device, addr layoutInfo, nil, addr result.layout) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Descriptor Set Layout!")

  # 2. Create Descriptor Pool
  var poolSize: VkDescriptorPoolSize
  poolSize.`type` = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
  poolSize.descriptorCount = 2

  var poolInfo: VkDescriptorPoolCreateInfo
  poolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
  poolInfo.poolSizeCount = 1
  poolInfo.pPoolSizes = addr poolSize
  poolInfo.maxSets = 1

  if vkCreateDescriptorPool(device, addr poolInfo, nil, addr result.pool) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Descriptor Pool!")

  # 3. Allocate Descriptor Set
  var allocInfo: VkDescriptorSetAllocateInfo
  allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
  allocInfo.descriptorPool = result.pool
  allocInfo.descriptorSetCount = 1
  allocInfo.pSetLayouts = addr result.layout

  if vkAllocateDescriptorSets(device, addr allocInfo, addr result.descriptorSet) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate Descriptor Set!")

  # 4. Bind SSBO Buffers to Descriptor Set
  var bufferInfo0: VkDescriptorBufferInfo
  bufferInfo0.buffer = vertexBuffer.buffer
  bufferInfo0.offset = 0
  bufferInfo0.range = VK_WHOLE_SIZE

  var bufferInfo1: VkDescriptorBufferInfo
  bufferInfo1.buffer = sceneBuffer.buffer
  bufferInfo1.offset = 0
  bufferInfo1.range = VK_WHOLE_SIZE

  var descriptorWrites: array[2, VkWriteDescriptorSet]

  descriptorWrites[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
  descriptorWrites[0].dstSet = result.descriptorSet
  descriptorWrites[0].dstBinding = 0
  descriptorWrites[0].descriptorCount = 1
  descriptorWrites[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
  descriptorWrites[0].pBufferInfo = addr bufferInfo0

  descriptorWrites[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
  descriptorWrites[1].dstSet = result.descriptorSet
  descriptorWrites[1].dstBinding = 1
  descriptorWrites[1].descriptorCount = 1
  descriptorWrites[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
  descriptorWrites[1].pBufferInfo = addr bufferInfo1

  vkUpdateDescriptorSets(device, descriptorWrites.len.uint32, addr descriptorWrites[0], 0, nil)

proc cleanup*(pack: SSBOPack) =
  if pack == nil or cast[pointer](pack.device) == nil: return
  if cast[uint64](pack.pool) != 0: vkDestroyDescriptorPool(pack.device, pack.pool, nil)
  if cast[uint64](pack.layout) != 0: vkDestroyDescriptorSetLayout(pack.device, pack.layout, nil)