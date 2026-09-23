import vk14
import cglm


type
  PushConstantKind* = enum
    pckFloat,
    pckVec3,
    pckMat4

  PushConstantValue* = object
    case kind*: PushConstantKind
    of pckFloat: floatVal*: float32
    of pckVec3:  vec3Val*: array[3, float32]
    of pckMat4:  mat4Val*: Mat4


const MaxPushConstantSize* = 128

type
  PushConstantBlock* = object
    data*: array[MaxPushConstantSize, byte]
    cursor*: int

proc initPushConstantBlock*(): PushConstantBlock =
  result.cursor = 0

proc clear*(pc: var PushConstantBlock) =
  pc.cursor = 0

proc pushWrite*[T](pc: var PushConstantBlock, value: T) =
  let valueSize = sizeof(T)
  assert pc.cursor + valueSize <= MaxPushConstantSize, "Push Constant limit exceeded (128 bytes max)!"
  copyMem(addr pc.data[pc.cursor], unsafeAddr value, valueSize)
  pc.cursor += valueSize

proc flush*(
    pc: var PushConstantBlock,
    cb: VkCommandBuffer,
    layout: VkPipelineLayout,
    stageFlags: VkShaderStageFlags = VkShaderStageFlags(VK_SHADER_STAGE_VERTEX_BIT)
) =
  if pc.cursor == 0: return
  vkCmdPushConstants(
    cb,
    layout,
    stageFlags,
    0'u32,
    pc.cursor.uint32,
    addr pc.data[0]
  )