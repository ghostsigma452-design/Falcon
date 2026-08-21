import sdl2
import vk14
import vkLoader

type


  VulkanWindow* = ref object
    sdlWindow*: WindowPtr
    vkInstance*: VkInstance
    vkSurface*: VkSurfaceKHR




proc newVulkanWindow*(title: string, width, height: int): VulkanWindow =
  new(result)

  # 1. Initialize SDL Video subsystem
  if not sdl2.init(INIT_VIDEO):
    raise newException(Exception, "SDL2 init failed: " & $getError())

  # 2. Create SDL Window configured for Vulkan rendering
  result.sdlWindow = createWindow(
    title,
    SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED,
    width.cint,
    height.cint,
    SDL_WINDOW_VULKAN or SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE
  )

  if result.sdlWindow == nil:
    raise newException(Exception, "Failed to create SDL Window: " & $getError())

  # 3. Dynamically load Vulkan driver & global functions
  loadGlobalProcs()

  # 4. Fetch required Vulkan extension names from SDL2
  var extensionCount: cuint = 0
  if not vulkanGetInstanceExtensions(result.sdlWindow, addr extensionCount, nil):
    raise newException(Exception, "Failed to get Vulkan extension count")

  var extNames = newSeq[cstring](extensionCount)
  if extensionCount > 0:
    if not vulkanGetInstanceExtensions(result.sdlWindow, addr extensionCount, cast[cstringArray](addr extNames[0])):
      raise newException(Exception, "Failed to get Vulkan extension names")

  # 5. Populate VkInstanceCreateInfo
  var createInfo: VkInstanceCreateInfo
  createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
  createInfo.flags = VkInstanceCreateFlags(0)
  createInfo.pApplicationInfo = nil
  createInfo.enabledLayerCount = 0
  createInfo.ppEnabledLayerNames = nil
  createInfo.enabledExtensionCount = extensionCount
  if extensionCount > 0:
    createInfo.ppEnabledExtensionNames = cast[cstringArray](addr extNames[0])
  else:
    createInfo.ppEnabledExtensionNames = nil

  # 6. Create Vulkan Instance
  let instanceResult = vkCreateInstance(addr createInfo, nil, addr result.vkInstance)
  if instanceResult != VK_SUCCESS:
    raise newException(Exception, "Vulkan instance creation failed with code: " & $instanceResult)

  # 7. Bind Instance-level Vulkan procedures
  loadInstanceProcs(result.vkInstance)

  # 8. Create Vulkan Window Surface
  if vulkanCreateSurface(result.sdlWindow, cast[VulkanInstance](result.vkInstance), cast[ptr VulkanSurface](addr result.vkSurface)) == false.Bool32:
    raise newException(Exception, "Vulkan surface creation failed")

proc cleanup*(win: VulkanWindow) =
  if win != nil:
    if cast[uint64](win.vkSurface) != 0 and vkDestroySurfaceKHR != nil:
      vkDestroySurfaceKHR(win.vkInstance, win.vkSurface, nil)
    if cast[pointer](win.vkInstance) != nil and vkDestroyInstance != nil:
      vkDestroyInstance(win.vkInstance, nil)
    vulkanUnloadLibrary()
    if win.sdlWindow != nil:
      destroy(win.sdlWindow)
    sdl2.quit()

