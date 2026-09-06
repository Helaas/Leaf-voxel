-- Leaf Voxel: a small overworld-only renderer for the MLP1.
local mod = ...
mod.exports.version = "0.1.0"

local V = { mod = mod, path = mod.path }
local modules, dataFiles = {}, {}

local function chunkFor(rel)
  local source = mod:read(rel)
  if not source then error(("LEAF_VOXEL: missing %s"):format(rel), 0) end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then error(("LEAF_VOXEL: %s did not compile: %s"):format(rel, err), 0) end
  return chunk
end

function V.require(name)
  if modules[name] ~= nil then return modules[name] end
  local value = chunkFor("lib/" .. name .. ".lua")(V)
  modules[name] = value
  return value
end

function V.data(name)
  if dataFiles[name] ~= nil then return dataFiles[name] end
  local value = chunkFor("data/" .. name .. ".lua")(V)
  dataFiles[name] = value
  return value
end

local Voxel = V.require("VoxelState")
local Voxel3D = V.require("Voxel3D")
local Scene = V.require("VoxelScene")
local Mesher = V.require("ChunkMesher")
local Quality = V.require("Quality")
local Pipelines = require("src.render.Pipelines")

local voidFill
mod.content.render_pipelines:register("voxel", {
  label = "VOXEL", levels = Voxel.ANGLE_LABELS, hotkey = "v", priority = 20,
  available = Voxel3D.available,
  update = function(dt, level)
    local currentFill = require("src.render.TileRenderer").voidFill
    if voidFill ~= nil and currentFill ~= voidFill then Mesher.invalidate() end
    voidFill = currentFill
    Voxel.update(dt, level)
    if not Voxel.active() then return end
    local Game = require("src.core.Game")
    local ow = Game.overworld
    if ow and ow.map and ow.camera then Scene.prefetch(ow) end
    Mesher.pump(Game.stack and Game.stack:top() ~= ow)
  end,
  drawWorld = function(ctx)
    local w, h = love.graphics.getPixelDimensions()
    local scale = Quality.scale()
    local canvas = Scene.render(ctx.state, math.floor(w / scale),
      math.floor(h / scale), ctx.vw, ctx.vh, ctx.paletteFor)
    if not canvas then return nil end
    if Voxel3D.beginOverlay() then
      ctx.drawFx(function(x, y) return Voxel3D.project(x, 0, y) end,
        ctx.scale / scale)
      Voxel3D.endOverlay()
    end
    return Quality.present(canvas, w, h)
  end,
  invalidate = function()
    Quality.invalidate()
    Voxel3D.invalidate()
    Mesher.invalidate()
  end,
})

mod.options:define({ Quality.setting:schema("Resolution of the voxel world; menus stay sharp.") })
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  out[#out + 1] = Quality.setting:row()
  return out
end)
mod.events:on("mod.options_changed", function(payload)
  if payload and payload.mod == mod.id and payload.key == Quality.setting.key then
    Quality.setting:sync(payload.value)
  end
end)

local function restore(payload)
  local save = payload and payload.save
  if save and Voxel.seedOptions(save.options) then Pipelines.applyOptions(save.options) end
end
mod.events:on("save.loaded", restore)
mod.events:on("save.created", restore)
mod.events:on("world.block_replaced", function(payload)
  local id = payload and (payload.mapId or (payload.map and payload.map.id))
  if id then Mesher.refresh(id) end
end)
mod.events:on("map.reloaded", function(payload)
  if payload and payload.reason == "colors" then return end
  local id = payload and (payload.mapId or (payload.map and payload.map.id))
  if id then Mesher.invalidate(id) end
end)

-- Cut must refresh the mesh even on engines that do not emit the block event.
local Map = require("src.world.Map")
local setBlock = Map.setBlock
function Map:setBlock(bx, by, block)
  local before = self:blockAt(bx, by)
  setBlock(self, bx, by, block)
  if self.id and self:blockAt(bx, by) ~= before then Mesher.refresh(self.id) end
end
mod.exports.lib = V
