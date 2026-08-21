import vk14
import vkLoader

type
  QueueFamilyIndices* = object
    graphicsFamily*: int = -1
    presentFamily*: int = -1

  VulkanDevice* = ref object
    logicalDevice*: VkDevice
    graphicsQueue*: VkQueue
    presentQueue*: VkQueue

proc isComplete*(indices: QueueFamilyIndices): bool =
  indices.graphicsFamily != -1 and indices.presentFamily != -1

# Load procedures required for physical and logical device creation
proc loadDeviceCreationProcs*(instance: VkInstance) =
  loadInstProc(instance, vkEnumeratePhysicalDevices)
  loadInstProc(instance, vkGetPhysicalDeviceProperties)
  loadInstProc(instance, vkGetPhysicalDeviceFeatures)
  loadInstProc(instance, vkGetPhysicalDeviceQueueFamilyProperties)
  loadInstProc(instance, vkGetPhysicalDeviceSurfaceSupportKHR)
  loadInstProc(instance, vkCreateDevice)

proc loadPhysicalDeviceProcs*(instance: VkInstance) =
  loadInstProc(instance, vkEnumeratePhysicalDevices)
  loadInstProc(instance, vkGetPhysicalDeviceProperties)
  loadInstProc(instance, vkGetPhysicalDeviceFeatures)
  loadInstProc(instance, vkGetPhysicalDeviceQueueFamilyProperties)
  loadInstProc(instance, vkGetPhysicalDeviceSurfaceSupportKHR)
  loadInstProc(instance, vkGetPhysicalDeviceSurfaceCapabilitiesKHR)
  loadInstProc(instance, vkGetPhysicalDeviceSurfaceFormatsKHR)
  loadInstProc(instance, vkGetPhysicalDeviceSurfacePresentModesKHR)
  loadInstProc(instance, vkCreateDevice)

# Load device-level procedure pointers dynamically
proc loadLogicalDeviceProcs*(instance: VkInstance, device: VkDevice) =
  # Fetch vkGetDeviceProcAddr using the valid VkInstance handle
  getDeviceProcAddr = cast[GetDeviceProcAddrProc](getInstanceProcAddr(instance, "vkGetDeviceProcAddr"))
  if getDeviceProcAddr == nil:
    raise newException(Exception, "Failed to load vkGetDeviceProcAddr handle")

  # Now getDeviceProcAddr is valid and won't crash when called here:
  loadDevProc(device, vkGetDeviceQueue)
  loadDevProc(device, vkDestroyDevice)
  loadDevProc(device, vkDeviceWaitIdle)

proc findQueueFamilies*(device: VkPhysicalDevice, surface: VkSurfaceKHR): QueueFamilyIndices =
  var queueCount: uint32 = 0
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr queueCount, nil)

  if queueCount == 0:
    return result

  var queueFamilies = newSeq[VkQueueFamilyProperties](queueCount)
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr queueCount, addr queueFamilies[0])

  for i, queueFamily in queueFamilies:
    if (queueFamily.queueFlags.uint32 and VK_QUEUE_GRAPHICS_BIT.uint32) != 0:
      result.graphicsFamily = i.int

    var presentSupport: VkBool32 = VK_FALSE
    discard vkGetPhysicalDeviceSurfaceSupportKHR(device, i.uint32, surface, addr presentSupport)
    if presentSupport == true.VkBool32:
      result.presentFamily = i.int

    if result.isComplete():
      break

proc pickPhysicalDevice*(instance: VkInstance, surface: VkSurfaceKHR): tuple[device: VkPhysicalDevice, indices: QueueFamilyIndices] =
  var deviceCount: uint32 = 0
  if vkEnumeratePhysicalDevices(instance, addr deviceCount, nil) != VK_SUCCESS or deviceCount == 0:
    raise newException(Exception, "Failed to find GPUs with Vulkan support!")

  var devices = newSeq[VkPhysicalDevice](deviceCount)
  if vkEnumeratePhysicalDevices(instance, addr deviceCount, addr devices[0]) != VK_SUCCESS:
    raise newException(Exception, "Failed to enumerate physical devices!")

  for dev in devices:
    let indices = findQueueFamilies(dev, surface)
    if indices.isComplete():
      return (dev, indices)

  raise newException(Exception, "Failed to find a GPU that supports graphics and presentation queues!")

proc newVulkanDevice*(
    instance: VkInstance,
    physicalDevice: VkPhysicalDevice,
    indices: QueueFamilyIndices
): VulkanDevice =
  new(result)

  # 1. Deduplicate queue family indices (if graphics & present share the same family)
  var uniqueIndices: seq[uint32] = @[indices.graphicsFamily.uint32]
  if indices.presentFamily.uint32 notin uniqueIndices:
    uniqueIndices.add(indices.presentFamily.uint32)

  var queuePriority = 1.0f
  var queueCreateInfos = newSeq[VkDeviceQueueCreateInfo]()

  for familyIndex in uniqueIndices:
    var queueCreateInfo: VkDeviceQueueCreateInfo
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    queueCreateInfo.queueFamilyIndex = familyIndex
    queueCreateInfo.queueCount = 1
    queueCreateInfo.pQueuePriorities = addr queuePriority
    queueCreateInfos.add(queueCreateInfo)

  # 2. Specify required device features and swapchain extensions
  var deviceFeatures: VkPhysicalDeviceFeatures
  var deviceExtensions = ["VK_KHR_swapchain"]
  var extNames = [deviceExtensions[0].cstring]

  # 3. Configure VkDeviceCreateInfo
  var createInfo: VkDeviceCreateInfo
  createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
  createInfo.queueCreateInfoCount = queueCreateInfos.len.uint32
  createInfo.pQueueCreateInfos = addr queueCreateInfos[0]
  createInfo.pEnabledFeatures = addr deviceFeatures
  createInfo.enabledExtensionCount = extNames.len.uint32
  createInfo.ppEnabledExtensionNames = cast[cstringArray](addr extNames[0])

  # 4. Create the Logical Device
  if vkCreateDevice(physicalDevice, addr createInfo, nil, addr result.logicalDevice) != VK_SUCCESS:
    raise newException(Exception, "Failed to create logical device!")

  # 5. Load Device-level procedures
  loadLogicalDeviceProcs(instance, result.logicalDevice)

  # 6. Retrieve Queue Handles
  vkGetDeviceQueue(result.logicalDevice, indices.graphicsFamily.uint32, 0, addr result.graphicsQueue)
  vkGetDeviceQueue(result.logicalDevice, indices.presentFamily.uint32, 0, addr result.presentQueue)

proc cleanup*(dev: VulkanDevice) =
  if dev != nil and cast[pointer](dev.logicalDevice) != nil:
    if vkDeviceWaitIdle != nil:
      discard vkDeviceWaitIdle(dev.logicalDevice)
    if vkDestroyDevice != nil:
      vkDestroyDevice(dev.logicalDevice, nil)