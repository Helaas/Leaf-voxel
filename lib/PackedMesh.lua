-- Bounded packing and upload through LÖVE's data API (FFI is not available
-- inside Gen1Recomp's mod sandbox). No per-vertex Lua number tables.
local V = ...
local Budget = V.require("BuildBudget")
local Voxel3D = V.require("Voxel3D")
local PackedMesh = {}
function PackedMesh.new()
  local chunks, pending, vertices = {}, {}, 0
  local function flush()
    if #pending == 0 then return end
    chunks[#chunks + 1] = table.concat(pending)
    pending = {}
  end
  return {
    push = function(corners, uv, shade)
      local v = {}
      for i = 1, 4 do
        local c, t = corners[i], uv[i]
        v[i] = love.data.pack("string", "ffffff", c[1], c[2], c[3],
          t[1], t[2], type(shade) == "table" and shade[i] or shade)
      end
      for _, i in ipairs({1, 2, 3, 1, 3, 4}) do pending[#pending + 1] = v[i] end
      vertices = vertices + 6
      if #pending >= 3072 then flush() end
      Budget.tick()
    end,
    finish = function()
      if vertices == 0 then return nil end
      flush()
      local mesh
      local ok, err = pcall(function()
        mesh = love.graphics.newMesh(Voxel3D.FORMAT, vertices, "triangles", "static")
        local first = 1
        for i, blob in ipairs(chunks) do
          local data = love.data.newByteData(blob)
          mesh:setVertices(data, first)
          data:release()
          first = first + #blob / 24
          chunks[i] = false
          Budget.check()
        end
      end)
      if not ok then
        if mesh then mesh:release() end
        error(err)
      end
      return mesh
    end,
  }
end
return PackedMesh
