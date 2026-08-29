import vk14

template getBufferSize*[T](t: typedesc[T], length: int = 1): VkDeviceSize =
  (sizeof(t) * length).VkDeviceSize

template getMemFlags*(): VkMemoryPropertyFlags =
  cast[VkMemoryPropertyFlags](
    uint32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) or 
    uint32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
  )