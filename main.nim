import falcon

var win = newVulkanWindow("Falcon", 1000, 1000)

# 1. Load instance procs for physical device inspection
loadPhysicalDeviceProcs(win.vkInstance)

  # 2. Pick GPU and locate queue families
let (physicalDevice, queueIndices) = pickPhysicalDevice(win.vkInstance, win.vkSurface)

echo "Graphics Queue Family Index: ", queueIndices.graphicsFamily
echo "Present Queue Family Index: ", queueIndices.presentFamily

let dev = newVulkanDevice(win.vkInstance, physicalDevice, queueIndices)
echo "Logical Device created successfully: ", cast[uint64](dev.logicalDevice)

var event: Event

var running = true

while running:
  while pollEvent(event):
    if event.kind == QuitEvent:
      running = false
  delay(16)

win.cleanup()


  
