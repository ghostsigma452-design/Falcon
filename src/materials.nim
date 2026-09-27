import pushConstant



type
  material* = seq[PushConstantValue]

# Default PBR materials list (Albedo, Metallic, Roughness, AO)

const GoldPBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [1.0'f32, 0.84'f32, 0.0'f32]),   # Albedo (warm gold)
  PushConstantValue(kind: pckFloat, floatVal: 0.4'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.25'f32),                      # Roughness (smooth)
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const SilverPBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [0.95'f32, 0.95'f32, 0.97'f32]), # Albedo (cool white-gray)
  PushConstantValue(kind: pckFloat, floatVal: 0.8'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.15'f32),                      # Roughness (very smooth)
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const GlassPBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [0.9'f32, 0.95'f32, 1.0'f32]),   # Albedo (slight blue tint)
  PushConstantValue(kind: pckFloat, floatVal: 0.2'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.05'f32),                      # Roughness (near-mirror)
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const CopperPBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [1'f32, 0.10'f32, 0.0'f32]), # Albedo (warm orange-red)
  PushConstantValue(kind: pckFloat, floatVal: 0.5'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.3'f32),                       # Roughness
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const WoodPBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [1.0'f32, 0.20'f32, 0.0'f32]), # Albedo (medium brown)
  PushConstantValue(kind: pckFloat, floatVal: 0.0'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.7'f32),                       # Roughness (matte)
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const PlasticPBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [0.05'f32, 0.05'f32, 0.08'f32]), # Albedo (dark gray)
  PushConstantValue(kind: pckFloat, floatVal: 0.0'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.35'f32),                      # Roughness (semi-gloss)
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const ConcretePBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [0.5'f32, 0.5'f32, 0.48'f32]),   # Albedo (neutral gray)
  PushConstantValue(kind: pckFloat, floatVal: 0.0'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 1'f32),                       # Roughness (very rough)
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const RubberPBR*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [0.0'f32, 0.0'f32, 0.0'f32]),    # Albedo (near-black)
  PushConstantValue(kind: pckFloat, floatVal: 0.0'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.1'f32),                      # Roughness (very matte)
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]

const DefaultPBRMaterial*: material = @[
  PushConstantValue(kind: pckVec3,  vec3Val: [0.0'f32, 0.0'f32, 0.5'f32]),    # Albedo
  PushConstantValue(kind: pckFloat, floatVal: 0.0'f32),                       # Metallic
  PushConstantValue(kind: pckFloat, floatVal: 0.5'f32),                       # Roughness
  PushConstantValue(kind: pckFloat, floatVal: 1.0'f32)                        # AO
]
