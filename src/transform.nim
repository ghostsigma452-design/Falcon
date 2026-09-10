import cglm, helper

type
  Transform* = object 
    pos*: Vec3
    rot*: Vec3    
    scale*: Vec3

proc getModelMatrix*(t: Transform): Mat4 =
  glm_mat4_identity(result)
  glm_translate(result, t.pos)
  glm_rotate(result, t.rot[0], [1.0'f32, 0.0'f32, 0.0'f32])
  glm_rotate(result, t.rot[1], [0.0'f32, 1.0'f32, 0.0'f32])
  glm_rotate(result, t.rot[2], [0.0'f32, 0.0'f32, 1.0'f32])
  glm_scale(result, t.scale)
  return result

proc setPos*(t: var Transform, v: Vec3)=
  t.pos = v

proc setRot*(t: var Transform, v: Vec3)=
  t.rot = v

proc setScale*(t: var Transform, v: Vec3)=
  t.scale = v

proc move*(t: var Transform, v: Vec3)=
  t.setPos(v + t.pos)

proc moveX*(t: var Transform, v: float)=
  t.setPos(vec3(v, 0f, 0f) + t.pos)

proc moveY*(t: var Transform, v: float)=
  t.setPos(vec3(0f, v, 0f) + t.pos)

proc movez*(t: var Transform, v: float)=
  t.setPos(vec3(0f, 0f, v) + t.pos)

proc rotate*(t: var Transform, v: Vec3)=
  t.setRot(v + t.pos)

proc scale*(t: var Transform, v: Vec3)=
  t.setScale(v + t.scale)

proc scale*(t: var Transform, v: float)=
  t.setScale(t.scale * v)