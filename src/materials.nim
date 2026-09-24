import pushConstant

# Default PBR materials list (Albedo, Metallic, Roughness, AO)
const DefaultPBRMaterial*: seq[PushConstantValue] = @[
  PushConstantValue(kind: pckVec3, vec3Val: [0'f32, 0.2'f32, 0.2'f32]), # Albedo
  PushConstantValue(kind: pckFloat, floatVal: 0.0'f32),                     # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.5'f32),                     # Roughness
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                      # AO
]
