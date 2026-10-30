type
  GPUVertex* = object
    pos*: array[4, float32]      # 16 bytes (Position)
    normal*: array[4, float32]   # 16 bytes (Normal)
    texCoord*: array[4, float32] # 16 bytes (UV coordinates packed into vec4)