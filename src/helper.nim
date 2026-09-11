import vk14, cglm

proc vec3*(x, y, z: float32): Vec3 = [x, y, z]

proc `+`*(a, b: Vec3): Vec3 =
  result = [a[0] + b[0], a[1] + b[1], a[2] + b[2]]   

proc `-`*(a, b: Vec3): Vec3 =
  result = [a[0] - b[0], a[1] - b[1], a[2] - b[2]]

proc `*`*(a: Vec3, s: float32): Vec3 =
  result = [a[0] * s, a[1] * s, a[2] * s]   

template getBufferSize*[T](t: typedesc[T], length: int = 1): VkDeviceSize =
  (sizeof(t) * length).VkDeviceSize

template getMemFlags*(): VkMemoryPropertyFlags =
  cast[VkMemoryPropertyFlags](
    uint32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) or 
    uint32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
  )

proc speed*(f: float, delta: float = 1): float =
  result = f * 0.001f * delta