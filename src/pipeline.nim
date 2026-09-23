import vk14

type
  VulkanPipeline* = ref object
    device*: VkDevice
    layout*: VkPipelineLayout
    pipeline*: VkPipeline

proc readShaderFile(path: string): seq[uint32] =
  let f = open(path, fmRead)
  defer: f.close()
  let size = f.getFileSize()
  
  var buffer = newSeq[uint32](size div sizeof(uint32))
  if buffer.len > 0:
    discard f.readBuffer(addr buffer[0], size)
  return buffer

proc createShaderModule(device: VkDevice, code: seq[uint32]): VkShaderModule =
  var createInfo: VkShaderModuleCreateInfo
  createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
  createInfo.codeSize = (code.len * sizeof(uint32)).uint
  createInfo.pCode = unsafeAddr code[0]

  if vkCreateShaderModule(device, addr createInfo, nil, addr result) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Shader Module!")

proc newVulkanPipeline*(
    device: VkDevice,
    extent: VkExtent2D,
    layoutInfo: VkPipelineLayoutCreateInfo,
    vertPath, fragPath: string,
    colorFormat: VkFormat = VK_FORMAT_B8G8R8A8_SRGB,
    depthFormat: VkFormat = VK_FORMAT_D32_SFLOAT
): VulkanPipeline =
  new(result)
  result.device = device

  var mutLayoutInfo = layoutInfo
  if vkCreatePipelineLayout(device, addr mutLayoutInfo, nil, addr result.layout) != VK_SUCCESS:
    raise newException(Exception, "Failed to create pipeline layout!")

  let vertCode = readShaderFile(vertPath)
  let fragCode = readShaderFile(fragPath)

  let vertModule = createShaderModule(device, vertCode)
  let fragModule = createShaderModule(device, fragCode)

  var vertStage = VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: VK_SHADER_STAGE_VERTEX_BIT,
    module: vertModule,
    pName: "main"
  )

  var fragStage = VkPipelineShaderStageCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    stage: VK_SHADER_STAGE_FRAGMENT_BIT,
    module: fragModule,
    pName: "main"
  )

  var shaderStages = [vertStage, fragStage]

  var vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
  )

  var inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    primitiveRestartEnable: false.VkBool32
  )

  var dummyViewport: VkViewport
  var dummyScissor: VkRect2D

  var viewportState = VkPipelineViewportStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    viewportCount: 1,
    pViewports: addr dummyViewport,
    scissorCount: 1,
    pScissors: addr dummyScissor
  )

  var rasterizer = VkPipelineRasterizationStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    depthClampEnable: false.VkBool32,
    rasterizerDiscardEnable: false.VkBool32,
    polygonMode: VK_POLYGON_MODE_FILL,
    cullMode: cast[VkCullModeFlags](VK_CULL_MODE_BACK_BIT.uint32),
    frontFace: VK_FRONT_FACE_COUNTER_CLOCKWISE,
    depthBiasEnable: false.VkBool32,
    lineWidth: 1.0f
  )

  var multisampling = VkPipelineMultisampleStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
    sampleShadingEnable: false.VkBool32
  )

  var depthStencil = VkPipelineDepthStencilStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
    depthTestEnable: true.VkBool32,
    depthWriteEnable: true.VkBool32,
    depthCompareOp: VK_COMPARE_OP_LESS,
    depthBoundsTestEnable: false.VkBool32,
    stencilTestEnable: false.VkBool32
  )

  var colorBlendAttachment = VkPipelineColorBlendAttachmentState(
    colorWriteMask: cast[VkColorComponentFlags](1'u32 or 2'u32 or 4'u32 or 8'u32),
    blendEnable: false.VkBool32
  )

  var colorBlending = VkPipelineColorBlendStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    logicOpEnable: false.VkBool32,
    attachmentCount: 1,
    pAttachments: addr colorBlendAttachment
  )

  var dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
  var dynamicState = VkPipelineDynamicStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
    dynamicStateCount: dynamicStates.len.uint32,
    pDynamicStates: addr dynamicStates[0]
  )

  # Dynamic Rendering Info (Vulkan 1.3+)
  var targetColorFormat = colorFormat
  var pipelineRenderingInfo = VkPipelineRenderingCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
    colorAttachmentCount: 1,
    pColorAttachmentFormats: addr targetColorFormat,
    depthAttachmentFormat: depthFormat
  )

  var pipelineInfo = VkGraphicsPipelineCreateInfo(
    sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    pNext: addr pipelineRenderingInfo, # Link dynamic rendering info
    stageCount: 2,
    pStages: addr shaderStages[0],
    pVertexInputState: addr vertexInputInfo,
    pInputAssemblyState: addr inputAssembly,
    pViewportState: addr viewportState,
    pRasterizationState: addr rasterizer,
    pMultisampleState: addr multisampling,
    pDepthStencilState: addr depthStencil,
    pColorBlendState: addr colorBlending,
    pDynamicState: addr dynamicState,
    layout: result.layout,
    renderPass: cast[VkRenderPass](0),
    subpass: 0
  )

  if vkCreateGraphicsPipelines(device, cast[VkPipelineCache](0), 1, addr pipelineInfo, nil, addr result.pipeline) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Graphics Pipeline!")

  vkDestroyShaderModule(device, vertModule, nil)
  vkDestroyShaderModule(device, fragModule, nil)

proc cleanup*(p: VulkanPipeline) =
  if p == nil or cast[pointer](p.device) == nil: return
  if cast[uint64](p.pipeline) != 0: vkDestroyPipeline(p.device, p.pipeline, nil)
  if cast[uint64](p.layout) != 0: vkDestroyPipelineLayout(p.device, p.layout, nil)