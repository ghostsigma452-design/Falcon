import sdl2
import vk14

type GetInstanceProcAddrProc* = proc(instance: VkInstance, name: cstring): pointer {.cdecl.}
type GetDeviceProcAddrProc* = proc(device: VkDevice, name: cstring): pointer {.cdecl.}

var getInstanceProcAddr*: GetInstanceProcAddrProc
var getDeviceProcAddr*: GetDeviceProcAddrProc

# Helper template to load an Instance-level proc pointer by name
template loadInstProc*(instance: VkInstance, procVar: untyped) =
  procVar = cast[type(procVar)](getInstanceProcAddr(instance, astToStr(procVar)))

# Helper template to load a Device-level proc pointer by name
template loadDevProc*(device: VkDevice, procVar: untyped) =
  procVar = cast[type(procVar)](getDeviceProcAddr(device, astToStr(procVar)))

# 1. Load functions available BEFORE VkInstance exists
proc loadGlobalProcs*() =
  if vulkanLoadLibrary(nil) != 0:
    raise newException(Exception, "Failed to load Vulkan library")

  getInstanceProcAddr = cast[GetInstanceProcAddrProc](vulkanGetVkGetInstanceProcAddr())
  if getInstanceProcAddr == nil:
    raise newException(Exception, "Failed to get vkGetInstanceProcAddr")

  loadInstProc(cast[VkInstance](nil), vkCreateInstance)
  loadInstProc(cast[VkInstance](nil), vkEnumerateInstanceExtensionProperties)
  loadInstProc(cast[VkInstance](nil), vkEnumerateInstanceLayerProperties)

# 2. Load functions after VkInstance creation
proc loadInstanceProcs*(instance: VkInstance) =
  loadInstProc(instance, vkDestroyInstance)
  loadInstProc(instance, vkEnumeratePhysicalDevices)
  loadInstProc(instance, vkGetPhysicalDeviceProperties)
  loadInstProc(instance, vkGetPhysicalDeviceFeatures)
  loadInstProc(instance, vkGetPhysicalDeviceQueueFamilyProperties)
  loadInstProc(instance, vkGetPhysicalDeviceMemoryProperties)
  loadInstProc(instance, vkCreateDevice)
  
  # Surface & Swapchain queries
  loadInstProc(instance, vkDestroySurfaceKHR)
  loadInstProc(instance, vkGetPhysicalDeviceSurfaceSupportKHR)
  loadInstProc(instance, vkGetPhysicalDeviceSurfaceCapabilitiesKHR)
  loadInstProc(instance, vkGetPhysicalDeviceSurfaceFormatsKHR)
  loadInstProc(instance, vkGetPhysicalDeviceSurfacePresentModesKHR)

  # Load Device Proc Fetcher
  getDeviceProcAddr = cast[GetDeviceProcAddrProc](getInstanceProcAddr(instance, "vkGetDeviceProcAddr"))

# 3. Load functions after VkDevice creation
proc loadDeviceProcs*(device: VkDevice) =
  loadDevProc(device, vkDestroyDevice)
  loadDevProc(device, vkGetDeviceQueue)
  loadDevProc(device, vkDeviceWaitIdle)
  
  # Memory & Buffers
  loadDevProc(device, vkCreateBuffer)
  loadDevProc(device, vkDestroyBuffer)
  loadDevProc(device, vkGetBufferMemoryRequirements)
  loadDevProc(device, vkAllocateMemory)
  loadDevProc(device, vkFreeMemory)
  loadDevProc(device, vkBindBufferMemory)
  loadDevProc(device, vkMapMemory)
  loadDevProc(device, vkUnmapMemory)

  # Command Pools & Buffers
  loadDevProc(device, vkCreateCommandPool)
  loadDevProc(device, vkDestroyCommandPool)
  loadDevProc(device, vkAllocateCommandBuffers)
  loadDevProc(device, vkFreeCommandBuffers)
  loadDevProc(device, vkBeginCommandBuffer)
  loadDevProc(device, vkEndCommandBuffer)

  # Pipelines, Shaders & RenderPass
  loadDevProc(device, vkCreateRenderPass)
  loadDevProc(device, vkDestroyRenderPass)
  loadDevProc(device, vkCreateShaderModule)
  loadDevProc(device, vkDestroyShaderModule)
  loadDevProc(device, vkCreateGraphicsPipelines)
  loadDevProc(device, vkDestroyPipeline)
  loadDevProc(device, vkCreatePipelineLayout)
  loadDevProc(device, vkDestroyPipelineLayout)

  # Swapchain & Present
  loadDevProc(device, vkCreateSwapchainKHR)
  loadDevProc(device, vkDestroySwapchainKHR)
  loadDevProc(device, vkGetSwapchainImagesKHR)
  loadDevProc(device, vkAcquireNextImageKHR)
  loadDevProc(device, vkQueueSubmit)
  loadDevProc(device, vkQueuePresentKHR)

proc loadLogicalDeviceProcs*(instance: VkInstance, device: VkDevice) =
  getDeviceProcAddr = cast[GetDeviceProcAddrProc](getInstanceProcAddr(instance, "vkGetDeviceProcAddr"))
  if getDeviceProcAddr == nil:
    raise newException(Exception, "Failed to load vkGetDeviceProcAddr handle")

  # Device & Queue
  loadDevProc(device, vkGetDeviceQueue)
  loadDevProc(device, vkDestroyDevice)
  loadDevProc(device, vkDeviceWaitIdle)

  # Command Pools & Command Buffers
  loadDevProc(device, vkCreateCommandPool)
  loadDevProc(device, vkDestroyCommandPool)
  loadDevProc(device, vkResetCommandPool)
  loadDevProc(device, vkAllocateCommandBuffers)
  loadDevProc(device, vkFreeCommandBuffers)
  loadDevProc(device, vkBeginCommandBuffer)
  loadDevProc(device, vkEndCommandBuffer)
  loadDevProc(device, vkResetCommandBuffer)
  loadDevProc(device, vkCmdCopyBuffer)

  # Drawing & RenderPass Commands
  loadDevProc(device, vkCmdBeginRenderPass)
  loadDevProc(device, vkCmdEndRenderPass)
  loadDevProc(device, vkCmdBindPipeline)
  loadDevProc(device, vkCmdSetViewport)
  loadDevProc(device, vkCmdSetScissor)
  loadDevProc(device, vkCmdDraw)

  # Swapchain & Image Views
  loadDevProc(device, vkCreateSwapchainKHR)
  loadDevProc(device, vkDestroySwapchainKHR)
  loadDevProc(device, vkGetSwapchainImagesKHR)
  loadDevProc(device, vkAcquireNextImageKHR)
  loadDevProc(device, vkQueuePresentKHR)
  loadDevProc(device, vkCreateImageView)
  loadDevProc(device, vkDestroyImageView)

  # Render Pass & Framebuffers
  loadDevProc(device, vkCreateRenderPass)
  loadDevProc(device, vkDestroyRenderPass)
  loadDevProc(device, vkCreateFramebuffer)
  loadDevProc(device, vkDestroyFramebuffer)

  # Shaders & Pipeline
  loadDevProc(device, vkCreateShaderModule)
  loadDevProc(device, vkDestroyShaderModule)
  loadDevProc(device, vkCreatePipelineLayout)
  loadDevProc(device, vkDestroyPipelineLayout)
  loadDevProc(device, vkCreateGraphicsPipelines)
  loadDevProc(device, vkDestroyPipeline)

  # Synchronization
  loadDevProc(device, vkCreateSemaphore)
  loadDevProc(device, vkDestroySemaphore)
  loadDevProc(device, vkCreateFence)
  loadDevProc(device, vkDestroyFence)
  loadDevProc(device, vkWaitForFences)
  loadDevProc(device, vkResetFences)

  # Buffers & Device Memory
  loadDevProc(device, vkCreateBuffer)
  loadDevProc(device, vkDestroyBuffer)
  loadDevProc(device, vkGetBufferMemoryRequirements)
  loadDevProc(device, vkAllocateMemory)
  loadDevProc(device, vkFreeMemory)
  loadDevProc(device, vkBindBufferMemory)
  loadDevProc(device, vkMapMemory)
  loadDevProc(device, vkUnmapMemory)

  # Descriptor Sets (For SSBOs)
  loadDevProc(device, vkCreateDescriptorSetLayout)
  loadDevProc(device, vkDestroyDescriptorSetLayout)
  loadDevProc(device, vkCreateDescriptorPool)
  loadDevProc(device, vkDestroyDescriptorPool)
  loadDevProc(device, vkAllocateDescriptorSets)
  loadDevProc(device, vkUpdateDescriptorSets)
  loadDevProc(device, vkCmdBindDescriptorSets)


  # Queue Submission & Sync
  loadDevProc(device, vkQueueSubmit)
  loadDevProc(device, vkQueueWaitIdle)

  # Vertex & Index Binding
  loadDevProc(device, vkCmdBindVertexBuffers)
  loadDevProc(device, vkCmdBindIndexBuffer)
  loadDevProc(device, vkCmdDrawIndexed)

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
