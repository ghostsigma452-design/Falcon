import falcon

var win = newVulkanWindow("Falcon", 1000, 1000)

# 1. Load instance procs for physical device inspection
loadPhysicalDeviceProcs(win.vkInstance)

  # 2. Pick GPU and locate queue families
let (physicalDevice, queueIndices) = pickPhysicalDevice(win.vkInstance, win.vkSurface)

echo "Graphics Queue Family Index: ", queueIndices.graphicsFamily
echo "Present Queue Family Index: ", queueIndices.presentFamily

let dev = newVulkanDevice(win.vkInstance, physicalDevice, queueIndices)
loadLogicalDeviceProcs(win.vkInstance, dev.logicalDevice) # <--- MAKE SURE THIS IS HERE
echo "Logical Device created successfully: ", cast[uint64](dev.logicalDevice)


let swapchain = newVulkanSwapchain(
    physicalDevice,
    dev.logicalDevice,
    win.vkSurface,
    queueIndices,
    1000,
    1000
  )


  # 2. Create RenderPass matching Swapchain format
let renderPass = newVulkanRenderPass(dev.logicalDevice, swapchain.format)



swapchain.createFramebuffers(renderPass.renderPass)

echo "Swapchain, RenderPass, and ", swapchain.framebuffers.len, " Framebuffers ready!"

let pipeline = newVulkanPipeline(
  dev.logicalDevice,
  renderPass.renderPass,
  swapchain.extent,
  "shaders/vert.spv", # path to vertex shader
  "shaders/frag.spv"  # path to fragment shader
)

echo "Graphics Pipeline successfully initialized!"

let renderer = newVulkanRenderer(
  dev.logicalDevice,
  queueIndices.graphicsFamily.uint32,
  queueIndices.presentFamily.uint32
)

echo "Falcon Engine initialised successfully! Rendering RGB triangle..."

var event: Event
var running = true

# Main Loop
while running:
  while pollEvent(event):
    if event.kind == QuitEvent:
      running = false

  renderer.drawFrame(swapchain, renderPass.renderPass, pipeline)

# --- Correct Reverse Cleanup Order ---
renderer.cleanup()
pipeline.cleanup()
swapchain.cleanup()   # 1. Destroys Framebuffers, Image Views, and Swapchain
renderPass.cleanup()  # 2. Destroys RenderPass
dev.cleanup()         # 3. Destroys Logical Device (was missing)
win.cleanup()         # 4. Destroys Surface, Instance, and Window LAST



  
