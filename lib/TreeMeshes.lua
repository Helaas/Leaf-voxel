-- One GPU mesh per tree drawing, reused at every placement. Only trees
-- intersecting the screen are submitted; whole-map duplication is expensive.
local V = ...
local Structures = V.require("Structures")
local PackedMesh = V.require("PackedMesh")
local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local Trees = {}
local models = {}

function Trees.build(map, bodyOnly, masks)
  local out = {}
  local width, height = map.def.width*32, map.def.height*32
  for _, stamp in ipairs(Structures.forMap(map).roundStamps) do
    local x, z = stamp.mx, stamp.mz
    local inside = x >= 0 and z >= 0 and x < width and z < height
    local keep = inside or not bodyOnly
    if not inside then
      for _, rect in ipairs(masks or {}) do
        if x >= rect[1] and z >= rect[2] and x < rect[3] and z < rect[4] then keep = false end
      end
    end
    if keep then
      local model = models[stamp.quads]
      if not model then
        local sink, top = PackedMesh.new(), 0
        for _, q in ipairs(stamp.quads) do
          local uv = q.uv or {{q.u,q.v},{q.u,q.v},{q.u,q.v},{q.u,q.v}}
          sink.push(q, uv, q.shade)
          for i = 1,4 do top = math.max(top,q[i][2]) end
        end
        model = {mesh = sink.finish(), top = top}
        models[stamp.quads] = model
      end
      out[#out+1] = {model = model, x = x, z = z, radius = stamp.r or 8}
    end
  end
  return out
end

function Trees.visible(tree, ox, oz)
  local m = Voxel3D.vp
  if not m then return true end
  local x, y, z = tree.x+(ox or 0), tree.model.top/2, tree.z+(oz or 0)
  local r = tree.radius
  -- AABB against the six homogeneous clip planes. Unlike projecting its
  -- corners, this also rejects offscreen boxes crossing the camera plane.
  for row = 1,3 do
    local i = (row-1)*4
    for sign = -1,1,2 do
      local a, b = m[13]+sign*m[i+1], m[14]+sign*m[i+2]
      local c, d = m[15]+sign*m[i+3], m[16]+sign*m[i+4]
      if a*x+b*y+c*z+d + math.abs(a)*r+math.abs(b)*y+math.abs(c)*r < 0 then
        return false
      end
    end
  end
  return true
end

function Trees.draw(list, atlas, ox, oz)
  if not list then return end
  for _, tree in ipairs(list) do
    if tree.model.mesh and Trees.visible(tree,ox,oz) then
      Voxel3D.draw(tree.model.mesh,atlas,Mat4.translate(tree.x+(ox or 0),0,tree.z+(oz or 0)))
    end
  end
end

function Trees.invalidate()
  for _, model in pairs(models) do
    if model.mesh then model.mesh:release() end
  end
  models = {}
end
return Trees
