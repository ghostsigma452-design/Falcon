import cglm, entity, transform

type
  Camera* = ref object of entity
    fov*: float32          # Field of view in radians (e.g. 45 degrees = ~0.785rad)
    aspectRatio*: float32  # Width / Height
    nearPlane*: float32    # Near clipping plane (e.g. 0.1)
    farPlane*: float32     # Far clipping plane (e.g. 100.0)

# Property accessor to easily get/modify the camera's transform component
proc transform*(cam: Camera): var Transform =
  return cam.components[0].transform

# Constructor
proc newCamera*(
    pos: Vec3 = [0.0'f32, 0.0'f32, 0.0'f32],
    fov: float32 = 0.785398'f32, # ~45 degrees in radians
    aspectRatio: float32 = 1.0'f32,
    nearPlane: float32 = 0.1'f32,
    farPlane: float32 = 100.0'f32
): Camera =
  new(result)
  result.fov = fov
  result.aspectRatio = aspectRatio
  result.nearPlane = nearPlane
  result.farPlane = farPlane

  # Initialize entity's base component array with a transform
  result.components = @[
    component(transform: Transform(
      pos: pos,
      rot: [0.0'f32, 0.0'f32, 0.0'f32],
      scale: [1.0'f32, 1.0'f32, 1.0'f32]
    ))
  ]

# Returns Vulkan perspective matrix with Y-axis flipped
proc getProjectionMatrix*(cam: Camera): Mat4 =
  glm_perspective(cam.fov, cam.aspectRatio, cam.nearPlane, cam.farPlane, result)
  result[1][1] = result[1][1] * -1.0'f32 # Vulkan coordinate system Y-flip

# Calculates View Matrix as Inverse of Camera's Model Matrix
proc getViewMatrix*(cam: Camera): Mat4 =
  var camWorld = cam.transform.getModelMatrix()
  glm_mat4_inv(camWorld, result)

# Combined View-Projection Matrix
proc getViewProjectionMatrix*(cam: Camera): Mat4 =
  let proj = cam.getProjectionMatrix()
  let view = cam.getViewMatrix()
  glm_mat4_mul(proj, view, result)

# Helper to update aspect ratio on window resize
proc setAspectRatio*(cam: Camera, width, height: float32) =
  if height > 0.0'f32:
    cam.aspectRatio = width / height