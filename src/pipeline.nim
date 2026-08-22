import vk14

type
  VulkanPipeline* = ref object
    device*: VkDevice
    pipelineLayout*: VkPipelineLayout
    pipeline*: VkPipeline

# Helper: Load binary file from path and convert to VkShaderModule
proc createShaderModule*(device: VkDevice, filePath: string): VkShaderModule =
  var code: string
  try:
    code = readFile(filePath)
  except IOError:
    raise newException(IOError, "Failed to read shader file at path: " & filePath)

  if code.len == 0 or code.len mod 4 != 0:
    raise newException(ValueError, "Shader file at " & filePath & " is empty or invalid SPIR-V bytecode alignment!")

  var createInfo: VkShaderModuleCreateInfo
  createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
  createInfo.codeSize = code.len.uint
  createInfo.pCode = cast[ptr uint32](unsafeAddr code[0])

  if vkCreateShaderModule(device, addr createInfo, nil, addr result) != VK_SUCCESS:
    raise newException(Exception, "Failed to create shader module for: " & filePath)

# Create Graphics Pipeline with configurable SPIR-V shader paths
proc newVulkanPipeline*(
    device: VkDevice,
    renderPass: VkRenderPass,
    extent: VkExtent2D,
    vertPath: string = "shaders/vert.spv",
    fragPath: string = "shaders/frag.spv"
): VulkanPipeline =
  new(result)
  result.device = device

  # 1. Load SPIR-V Shaders
  let vertShaderModule = createShaderModule(device, vertPath)
  let fragShaderModule = createShaderModule(device, fragPath)

  # Destroy shader modules immediately after pipeline construction finished
  defer:
    if cast[pointer](vkDestroyShaderModule) != nil:
      vkDestroyShaderModule(device, vertShaderModule, nil)
      vkDestroyShaderModule(device, fragShaderModule, nil)

  # 2. Shader Stage Create Infos
  var vertShaderStageInfo: VkPipelineShaderStageCreateInfo
  vertShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
  vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT
  vertShaderStageInfo.module = vertShaderModule
  vertShaderStageInfo.pName = "main"

  var fragShaderStageInfo: VkPipelineShaderStageCreateInfo
  fragShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
  fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT
  fragShaderStageInfo.module = fragShaderModule
  fragShaderStageInfo.pName = "main"

  var shaderStages = [vertShaderStageInfo, fragShaderStageInfo]

  # 3. Dynamic States (Viewport & Scissor can be updated without recreating pipeline)
  var dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]

  var dynamicStateInfo: VkPipelineDynamicStateCreateInfo
  dynamicStateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
  dynamicStateInfo.dynamicStateCount = dynamicStates.len.uint32
  dynamicStateInfo.pDynamicStates = addr dynamicStates[0]

  # 4. Vertex Input State (Hardcoded vertex positions in shader for now)
  var vertexInputInfo: VkPipelineVertexInputStateCreateInfo
  vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
  vertexInputInfo.vertexBindingDescriptionCount = 0
  vertexInputInfo.vertexAttributeDescriptionCount = 0

  # 5. Input Assembly State
  var inputAssembly: VkPipelineInputAssemblyStateCreateInfo
  inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
  inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
  inputAssembly.primitiveRestartEnable = false.VkBool32

  # 6. Viewport State
  var viewportState: VkPipelineViewportStateCreateInfo
  viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
  viewportState.viewportCount = 1
  viewportState.scissorCount = 1

  # 7. Rasterization State
  var rasterizer: VkPipelineRasterizationStateCreateInfo
  rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
  rasterizer.depthClampEnable = false.VkBool32
  rasterizer.rasterizerDiscardEnable = false.VkBool32
  rasterizer.polygonMode = VK_POLYGON_MODE_FILL
  rasterizer.lineWidth = 1.0f
  rasterizer.cullMode = VK_CULL_MODE_NONE.VkCullModeFlags # Set to NONE for initial triangle rendering
  rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE
  rasterizer.depthBiasEnable = false.VkBool32

  # 8. Multisampling State
  var multisampling: VkPipelineMultisampleStateCreateInfo
  multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
  multisampling.sampleShadingEnable = false.VkBool32
  multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT

  # 9. Color Blending State
  var colorBlendAttachment: VkPipelineColorBlendAttachmentState
  colorBlendAttachment.colorWriteMask = cast[VkColorComponentFlags](
    VK_COLOR_COMPONENT_R_BIT.uint32 or
    VK_COLOR_COMPONENT_G_BIT.uint32 or
    VK_COLOR_COMPONENT_B_BIT.uint32 or
    VK_COLOR_COMPONENT_A_BIT.uint32
  )
  colorBlendAttachment.blendEnable = false.VkBool32

  var colorBlending: VkPipelineColorBlendStateCreateInfo
  colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
  colorBlending.logicOpEnable = false.VkBool32
  colorBlending.attachmentCount = 1
  colorBlending.pAttachments = addr colorBlendAttachment

  # 10. Pipeline Layout
  var pipelineLayoutInfo: VkPipelineLayoutCreateInfo
  pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
  pipelineLayoutInfo.setLayoutCount = 0
  pipelineLayoutInfo.pushConstantRangeCount = 0

  if vkCreatePipelineLayout(device, addr pipelineLayoutInfo, nil, addr result.pipelineLayout) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Vulkan Pipeline Layout!")

  # 11. Create Graphics Pipeline
  var pipelineInfo: VkGraphicsPipelineCreateInfo
  pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
  pipelineInfo.stageCount = shaderStages.len.uint32
  pipelineInfo.pStages = addr shaderStages[0]
  pipelineInfo.pVertexInputState = addr vertexInputInfo
  pipelineInfo.pInputAssemblyState = addr inputAssembly
  pipelineInfo.pViewportState = addr viewportState
  pipelineInfo.pRasterizationState = addr rasterizer
  pipelineInfo.pMultisampleState = addr multisampling
  pipelineInfo.pColorBlendState = addr colorBlending
  pipelineInfo.pDynamicState = addr dynamicStateInfo
  pipelineInfo.layout = result.pipelineLayout
  pipelineInfo.renderPass = renderPass
  pipelineInfo.subpass = 0

  if vkCreateGraphicsPipelines(device, cast[VkPipelineCache](0), 1, addr pipelineInfo, nil, addr result.pipeline) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Vulkan Graphics Pipeline!")

# Cleanup pipeline & layout
proc cleanup*(pipe: VulkanPipeline) =
  if pipe == nil or cast[pointer](pipe.device) == nil:
    return

  if cast[uint64](pipe.pipeline) != 0 and cast[pointer](vkDestroyPipeline) != nil:
    vkDestroyPipeline(pipe.device, pipe.pipeline, nil)
    pipe.pipeline = cast[VkPipeline](0)

  if cast[uint64](pipe.pipelineLayout) != 0 and cast[pointer](vkDestroyPipelineLayout) != nil:
    vkDestroyPipelineLayout(pipe.device, pipe.pipelineLayout, nil)
    pipe.pipelineLayout = cast[VkPipelineLayout](0)