# src/pipeline.nim
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
  
  # Allocate sequence directly as uint32s to guarantee alignment and correct len
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
    renderPass: VkRenderPass,
    extent: VkExtent2D,
    descriptorSetLayout: VkDescriptorSetLayout,
    vertPath, fragPath: string
): VulkanPipeline =
  new(result)
  result.device = device

  let vertCode = readShaderFile(vertPath)
  let fragCode = readShaderFile(fragPath)

  let vertModule = createShaderModule(device, vertCode)
  let fragModule = createShaderModule(device, fragCode)

  var vertStage: VkPipelineShaderStageCreateInfo
  vertStage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
  vertStage.stage = VK_SHADER_STAGE_VERTEX_BIT
  vertStage.module = vertModule
  vertStage.pName = "main"

  var fragStage: VkPipelineShaderStageCreateInfo
  fragStage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
  fragStage.stage = VK_SHADER_STAGE_FRAGMENT_BIT
  fragStage.module = fragModule
  fragStage.pName = "main"

  var shaderStages = [vertStage, fragStage]

  var vertexInputInfo: VkPipelineVertexInputStateCreateInfo
  vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO

  var inputAssembly: VkPipelineInputAssemblyStateCreateInfo
  inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
  inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
  inputAssembly.primitiveRestartEnable = false.VkBool32

  var dummyViewport: VkViewport
  var dummyScissor: VkRect2D

  var viewportState: VkPipelineViewportStateCreateInfo
  viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
  viewportState.viewportCount = 1
  viewportState.pViewports = addr dummyViewport
  viewportState.scissorCount = 1
  viewportState.pScissors = addr dummyScissor

  var rasterizer: VkPipelineRasterizationStateCreateInfo
  rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
  rasterizer.depthClampEnable = false.VkBool32
  rasterizer.rasterizerDiscardEnable = false.VkBool32
  rasterizer.polygonMode = VK_POLYGON_MODE_FILL
  rasterizer.cullMode = cast[VkCullModeFlags](VK_CULL_MODE_NONE.uint32)
  rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE
  rasterizer.depthBiasEnable = false.VkBool32
  rasterizer.lineWidth = 1.0f

  var multisampling: VkPipelineMultisampleStateCreateInfo
  multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
  multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
  multisampling.sampleShadingEnable = false.VkBool32

  var colorBlendAttachment: VkPipelineColorBlendAttachmentState
  colorBlendAttachment.colorWriteMask = cast[VkColorComponentFlags](1'u32 or 2'u32 or 4'u32 or 8'u32)
  colorBlendAttachment.blendEnable = false.VkBool32

  var colorBlending: VkPipelineColorBlendStateCreateInfo
  colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
  colorBlending.logicOpEnable = false.VkBool32
  colorBlending.attachmentCount = 1
  colorBlending.pAttachments = addr colorBlendAttachment

  var dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
  var dynamicState: VkPipelineDynamicStateCreateInfo
  dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
  dynamicState.dynamicStateCount = dynamicStates.len.uint32
  dynamicState.pDynamicStates = addr dynamicStates[0]

  var dsLayout = descriptorSetLayout
  var pipelineLayoutInfo: VkPipelineLayoutCreateInfo
  pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
  pipelineLayoutInfo.setLayoutCount = 1
  pipelineLayoutInfo.pSetLayouts = addr dsLayout

  if vkCreatePipelineLayout(device, addr pipelineLayoutInfo, nil, addr result.layout) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Pipeline Layout!")

  var pipelineInfo: VkGraphicsPipelineCreateInfo
  pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
  pipelineInfo.stageCount = 2
  pipelineInfo.pStages = addr shaderStages[0]
  pipelineInfo.pVertexInputState = addr vertexInputInfo
  pipelineInfo.pInputAssemblyState = addr inputAssembly
  pipelineInfo.pViewportState = addr viewportState
  pipelineInfo.pRasterizationState = addr rasterizer
  pipelineInfo.pMultisampleState = addr multisampling
  pipelineInfo.pColorBlendState = addr colorBlending
  pipelineInfo.pDynamicState = addr dynamicState
  pipelineInfo.layout = result.layout
  pipelineInfo.renderPass = renderPass
  pipelineInfo.subpass = 0

  if vkCreateGraphicsPipelines(device, cast[VkPipelineCache](0), 1, addr pipelineInfo, nil, addr result.pipeline) != VK_SUCCESS:
    raise newException(Exception, "Failed to create Graphics Pipeline!")

  vkDestroyShaderModule(device, vertModule, nil)
  vkDestroyShaderModule(device, fragModule, nil)

proc cleanup*(p: VulkanPipeline) =
  if p == nil or cast[pointer](p.device) == nil: return
  if cast[uint64](p.pipeline) != 0: vkDestroyPipeline(p.device, p.pipeline, nil)
  if cast[uint64](p.layout) != 0: vkDestroyPipelineLayout(p.device, p.layout, nil)