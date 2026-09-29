import std/[strutils, tables]
import cglm
import builtins  # Contains GPUVertex definition

## Parses a Wavefront OBJ file and returns interleaved vertex data and an index buffer.
proc parseOBJ*(path: string): tuple[vertices: seq[float32], indices: seq[uint32]] =
  # Use standard Nim arrays instead of C-imported cglm types to avoid C array casting errors
  var positions: seq[array[3, float32]] = @[]
  var normals:   seq[array[3, float32]] = @[]
  var texcoords: seq[array[2, float32]] = @[]

  var vertices: seq[float32] = @[]
  var indices:  seq[uint32] = @[]
  var vertexMap = initTable[(int, int, int), uint32]()

  for line in lines(path):
    let trimmed = line.strip()
    if trimmed.len == 0 or trimmed[0] == '#':
      continue
    let parts = trimmed.splitWhitespace()
    if parts[0] == "v":
      # vertex position
      positions.add([parts[1].parseFloat().float32,
                     parts[2].parseFloat().float32,
                     parts[3].parseFloat().float32])
    elif parts[0] == "vn":
      # vertex normal
      normals.add([parts[1].parseFloat().float32,
                   parts[2].parseFloat().float32,
                   parts[3].parseFloat().float32])
    elif parts[0] == "vt":
      # texture coordinate (u, v)
      texcoords.add([parts[1].parseFloat().float32,
                    parts[2].parseFloat().float32])
    elif parts[0] == "f":
      # face – each token may be v/vt/vn (OBJ indices are 1‑based)
      var faceIdx: seq[uint32] = @[]
      for i in 1 ..< parts.len:
        let token = parts[i]
        var vIdx, vtIdx, vnIdx: int
        let comps = token.split('/')
        # position index
        vIdx = comps[0].parseInt()
        # texture index (optional)
        if comps.len > 1 and comps[1].len > 0:
          vtIdx = comps[1].parseInt()
        else:
          vtIdx = 0
        # normal index (optional)
        if comps.len > 2 and comps[2].len > 0:
          vnIdx = comps[2].parseInt()
        else:
          vnIdx = 0
        # OBJ uses 1‑based indexing, convert to 0‑based for our tables
        let key = (vIdx - 1, vtIdx - 1, vnIdx - 1)
        if not vertexMap.hasKey(key):
          let pos = positions[key[0]]
          let norm: array[3, float32] = if key[2] >= 0: normals[key[2]] else: [0'f32, 0'f32, 0'f32]
          let tex: array[2, float32] = if key[1] >= 0: texcoords[key[1]] else: [0'f32, 0'f32]
          # Append interleaved data (3 position + 3 normal + 2 texcoord = 8 floats)
          vertices.add(pos[0]); vertices.add(pos[1]); vertices.add(pos[2])
          vertices.add(norm[0]); vertices.add(norm[1]); vertices.add(norm[2])
          vertices.add(tex[0]); vertices.add(tex[1])
          let newIdx = uint32(vertices.len div 8 - 1)
          vertexMap[key] = newIdx
        faceIdx.add(vertexMap[key])
      # Triangulate polygon (fan method)
      for i in 1 ..< faceIdx.len - 1:
        indices.add(faceIdx[0])
        indices.add(faceIdx[i])
        indices.add(faceIdx[i+1])

  result = (vertices, indices)

proc toGPUVertices*(rawVerts: seq[float32]): seq[GPUVertex] =
  let vertexCount = rawVerts.len div 8
  result = newSeq[GPUVertex](vertexCount)

  for i in 0 ..< vertexCount:
    let offset = i * 8
    result[i] = GPUVertex(
      pos: [
        rawVerts[offset + 0],
        rawVerts[offset + 1],
        rawVerts[offset + 2],
        1.0'f32 # Homogeneous coordinate
      ],
      color: [
        1.0'f32, 1.0'f32, 1.0'f32, 1.0'f32 # Default white color multiplier
      ],
      normal: [
        rawVerts[offset + 3],
        rawVerts[offset + 4],
        rawVerts[offset + 5],
        0.0'f32
      ]
    )

proc format*(data: tuple[vertices: seq[float32], indices: seq[uint32]]): tuple[vertices: seq[GPUVertex], indices: seq[uint32]] = 
  let gpuVerts = data.vertices.toGPUVertices()
  result = (gpuVerts, data.indices)