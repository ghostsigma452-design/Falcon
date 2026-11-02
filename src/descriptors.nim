import vk14
import buffer

type
  SSBOPack* = object
    device*: VkDevice
    descriptorSet*: VkDescriptorSet
    descriptorPool*: VkDescriptorPool
    setLayout*: VkDescriptorSetLayout

  BindlessTextures* = object
    device*: VkDevice
    descriptorSet*: VkDescriptorSet
    descriptorPool*: VkDescriptorPool
    setLayout*: VkDescriptorSetLayout

# Create Set 0 Layout & Descriptor Set for Vertex/Scene SSBOs
proc newSSBOPack*(device: VkDevice, layout: VkDescriptorSetLayout, vertexBuffer, sceneSSBO: VulkanBuffer): SSBOPack =
  var poolSizes = [
    VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount: 2'u32)
  ]

  var poolInfo = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount: 1,
    pPoolSizes: addr poolSizes[0],
    maxSets: 1
  )

  if vkCreateDescriptorPool(device, addr poolInfo, nil, addr result.descriptorPool) != VK_SUCCESS:
    raise newException(Exception, "Failed to create SSBO descriptor pool!")

  result.device = device
  result.setLayout = layout

  var allocInfo = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool: result.descriptorPool,
    descriptorSetCount: 1,
    pSetLayouts: addr result.setLayout
  )

  if vkAllocateDescriptorSets(device, addr allocInfo, addr result.descriptorSet) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate SSBO descriptor set!")

  var vertBufferInfo = VkDescriptorBufferInfo(buffer: vertexBuffer.buffer, offset: 0, range: vertexBuffer.size)
  var sceneBufferInfo = VkDescriptorBufferInfo(buffer: sceneSSBO.buffer, offset: 0, range: sceneSSBO.size)

  var descriptorWrites = [
    VkWriteDescriptorSet(
      sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
      dstSet: result.descriptorSet,
      dstBinding: 0,
      dstArrayElement: 0,
      descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
      descriptorCount: 1,
      pBufferInfo: addr vertBufferInfo
    ),
    VkWriteDescriptorSet(
      sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
      dstSet: result.descriptorSet,
      dstBinding: 1,
      dstArrayElement: 0,
      descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
      descriptorCount: 1,
      pBufferInfo: addr sceneBufferInfo
    )
  ]

  vkUpdateDescriptorSets(device, 2, addr descriptorWrites[0], 0, nil)

# Create Set 1 Bindless Texture Array Layout & Pool (Supports up to 1024 textures)
proc newBindlessTextures*(device: VkDevice): BindlessTextures =
  const maxTextures = 1024'u32

  var poolSize = VkDescriptorPoolSize(
    type: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
    descriptorCount: maxTextures
  )

  var poolInfo = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    flags: VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT.VkDescriptorPoolCreateFlags,
    poolSizeCount: 1,
    pPoolSizes: addr poolSize,
    maxSets: 1
  )

  if vkCreateDescriptorPool(device, addr poolInfo, nil, addr result.descriptorPool) != VK_SUCCESS:
    raise newException(Exception, "Failed to create bindless descriptor pool!")

  var binding = VkDescriptorSetLayoutBinding(
    binding: 0,
    descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
    descriptorCount: maxTextures,
    stageFlags: cast[VkShaderStageFlags](VK_SHADER_STAGE_FRAGMENT_BIT.uint32),
    pImmutableSamplers: nil
  )

  # Cast distinct flag enums to uint32 for bitwise OR to avoid type mismatch
  var bindingFlags = [
    cast[VkDescriptorBindingFlags](
      VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT.uint32 or
      VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT.uint32
    )
  ]

  var layoutFlagsInfo = VkDescriptorSetLayoutBindingFlagsCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
    bindingCount: 1,
    pBindingFlags: addr bindingFlags[0]
  )

  var layoutInfo = VkDescriptorSetLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    pNext: addr layoutFlagsInfo,
    flags: VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT.VkDescriptorSetLayoutCreateFlags,
    bindingCount: 1,
    pBindings: addr binding
  )

  if vkCreateDescriptorSetLayout(device, addr layoutInfo, nil, addr result.setLayout) != VK_SUCCESS:
    raise newException(Exception, "Failed to create bindless descriptor set layout!")

  var allocInfo = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool: result.descriptorPool,
    descriptorSetCount: 1,
    pSetLayouts: addr result.setLayout
  )

  if vkAllocateDescriptorSets(device, addr allocInfo, addr result.descriptorSet) != VK_SUCCESS:
    raise newException(Exception, "Failed to allocate bindless descriptor set!")

  result.device = device

proc cleanup*(pack: SSBOPack) =
  if cast[uint64](pack.descriptorPool) != 0: 
    vkDestroyDescriptorPool(pack.device, pack.descriptorPool, nil)
  if cast[uint64](pack.setLayout) != 0: 
    vkDestroyDescriptorSetLayout(pack.device, pack.setLayout, nil)

proc cleanup*(bindless: BindlessTextures) =
  if cast[uint64](bindless.descriptorPool) != 0: 
    vkDestroyDescriptorPool(bindless.device, bindless.descriptorPool, nil)
  if cast[uint64](bindless.setLayout) != 0: 
    vkDestroyDescriptorSetLayout(bindless.device, bindless.setLayout, nil)