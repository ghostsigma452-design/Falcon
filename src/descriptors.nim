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
    layout: VkDescriptorSetLayout,
    vertexBuffer: VulkanBuffer,
    sceneBuffer: VulkanBuffer
): SSBOPack =
  new(result)
  result.device = device
  result.layout = layout

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



const MaxBindlessTextures* = 1024

type
  BindlessTexturePack* = ref object
    device*: VkDevice
    layout*: VkDescriptorSetLayout
    pool*: VkDescriptorPool
    descriptorSet*: VkDescriptorSet

proc newBindlessTexturePack*(device: VkDevice): BindlessTexturePack =
  new(result)
  result.device = device

  # 1. Explicitly type bindingFlags array to match VkDescriptorBindingFlags
  var bindingFlags: array[1, VkDescriptorBindingFlags] = [
    cast[VkDescriptorBindingFlags](
      VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT.uint32 or 
      VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT.uint32 or
      VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT.uint32
    )
  ]

  var layoutBindingFlagsInfo = VkDescriptorSetLayoutBindingFlagsCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
    bindingCount: 1,
    pBindingFlags: addr bindingFlags[0]
  )

  var samplerLayoutBinding = VkDescriptorSetLayoutBinding(
    binding: 0,
    descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
    descriptorCount: MaxBindlessTextures,
    stageFlags: cast[VkShaderStageFlags](VK_SHADER_STAGE_FRAGMENT_BIT.uint32)
  )

  # 2. Cast flags to VkDescriptorSetLayoutCreateFlags
  var layoutInfo = VkDescriptorSetLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    pNext: addr layoutBindingFlagsInfo,
    flags: cast[VkDescriptorSetLayoutCreateFlags](VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT.uint32),
    bindingCount: 1,
    pBindings: addr samplerLayoutBinding
  )

  if vkCreateDescriptorSetLayout(device, addr layoutInfo, nil, addr result.layout) != VK_SUCCESS:
    raise newException(Exception, "Failed to create bindless descriptor set layout!")

  # 3. Create Descriptor Pool with UPDATE_AFTER_BIND support (cast pool flags)
  var poolSize = VkDescriptorPoolSize(
    `type`: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
    descriptorCount: MaxBindlessTextures
  )

  var poolInfo = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    flags: cast[VkDescriptorPoolCreateFlags](VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT.uint32),
    maxSets: 1,
    poolSizeCount: 1,
    pPoolSizes: addr poolSize
  )

  if vkCreateDescriptorPool(device, addr poolInfo, nil, addr result.pool) != VK_SUCCESS:
    raise newException(Exception, "Failed to create bindless descriptor pool!")

  # 4. Allocate Descriptor Set with Variable Count
  var variableDescriptorCount = MaxBindlessTextures.uint32
  var variableCountInfo = VkDescriptorSetVariableDescriptorCountAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO,
    descriptorSetCount: 1,
    pDescriptorCounts: addr variableDescriptorCount
  )

  var allocInfo = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    pNext: addr variableCountInfo,
    descriptorPool: result.pool,
    descriptorSetCount: 1,
    pSetLayouts: addr result.layout
  )

  if vkAllocateDescriptorSets(device, addr allocInfo, addr result.descriptorSet) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate descriptor set!")