-- A cached, shallow stage under the engine's native sprites, HUD and effects.
-- No map meshes, extra battle simulation, sprite captures or per-frame shader.
local V = ...
local Battle = {}
Battle.setting = V.require("ModSetting").new("battleMode", "BATTLE",
  {"light", "classic"}, {"LIGHT", "CLASSIC"})
local Voxel = V.require("VoxelState")
local Map = require("src.world.Map")
local BattleState = require("src.battle.BattleState")
local target, signature

function Battle.invalidate()
  if target then target:release() end
  target, signature = nil, nil
end

local function stage(battle)
  local g, renderer = love.graphics, battle.game.renderer
  local r = renderer:frameRects()
  local map = battle.game.overworld and battle.game.overworld.map
  local outdoor = map and (Map.isOutdoor(map.def) or map.def.tileset == "FOREST") or false
  local wide = battle:wideLayout() and true or false
  local scale = V.require("Quality").scale()
  local key = table.concat({r.pw, r.ph, r.Up, r.uox, r.uoy,
    r.vx, r.vy, scale, tostring(wide), tostring(outdoor)}, ":")
  if target and signature == key then return target end
  Battle.invalidate()
  local small = g.newCanvas(math.floor(r.pw / scale), math.floor(r.ph / scale), {dpiscale=1})
  small:setFilter("nearest", "nearest")
  g.push("all")
  g.setCanvas(small)
  g.origin()
  g.setShader()
  g.setDepthMode()
  g.setScissor()
  g.setBlendMode("alpha")
  if outdoor then g.clear(.72, .84, .81, 1) else g.clear(.70, .74, .80, 1) end
  g.scale(small:getWidth()/r.pw, small:getHeight()/r.ph)
  g.translate(r.uox*r.dpiX-r.vx, r.uoy*r.dpiY-r.vy)
  g.scale(r.Up)
  local left = -(r.uox*r.dpiX-r.vx)/r.Up
  local right = left + r.pw/r.Up
  local bottom = (r.ph-r.uoy*r.dpiY+r.vy)/r.Up
  local function tint(a,b,c)
    if outdoor then g.setColor(a,b,c,1)
    else local gray=(a+b+c)/3; g.setColor(gray*.87,gray*.91,gray,1) end
  end
  tint(.68,.73,.62)
  g.rectangle("fill", left, 43, right-left, bottom-43)
  -- A broad floor and two bevelled slabs give depth at native battle anchors.
  tint(.73,.79,.65)
  g.polygon("fill", left, bottom, 60,43, wide and 280 or 155,43, right,bottom)
  local function slab(x,y,rx,ry)
    tint(.41,.50,.34)
    g.polygon("fill", x-rx,y, x,y+ry, x+rx,y, x+rx,y+4, x,y+ry+4, x-rx,y+4)
    tint(.78,.84,.66)
    g.polygon("fill", x-rx,y, x,y-ry, x+rx,y, x,y+ry)
    tint(.87,.91,.76)
    g.polygon("fill", x-rx,y, x,y-ry, x+rx,y, x+rx-3,y+1, x,y-ry+2, x-rx+3,y+1)
  end
  slab(wide and 260 or 124, 57, 34, 9)
  slab(wide and 84 or 64, wide and 102 or 94, 43, 12)
  target = g.newCanvas(r.pw,r.ph,{dpiscale=1})
  target:setFilter("nearest","nearest")
  g.setCanvas(target)
  g.origin()
  g.setBlendMode("replace","premultiplied")
  g.setColor(1,1,1,1)
  g.draw(small,0,0,0,r.pw/small:getWidth(),r.ph/small:getHeight())
  g.pop()
  small:release()
  signature = key
  return target
end

local draw = BattleState.draw
function BattleState:draw(...)
  if not Voxel.active() or Battle.setting:get() ~= "light" or self.blankForAskName then
    return draw(self, ...)
  end
  self.game.renderer:setWorldOverride(stage(self))
  local g, white = love.graphics, self.letterboxWhite
  self.letterboxWhite = false
  -- Same narrow field-fill seam as upstream's standalone battle host. Keep
  -- all later full-screen fills: move flashes must still cover the battle.
  local rectangle, suppressed = g.rectangle, false
  g.clear(0,0,0,0)
  g.rectangle = function(mode,x,y,w,h,...)
    local _,_,_,alpha = g.getColor()
    if not suppressed and mode == "fill" and x == 0 and y == 0
        and h == 144 and (w == 160 or w == 304) and alpha > .99 then
      suppressed = true
      local canvas = g.getCanvas()
      if canvas and (canvas == self.bgCanvas or canvas == self.waveCanvas) then
        g.clear(0,0,0,0)
      end
      return
    end
    return rectangle(mode,x,y,w,h,...)
  end
  local ok, result = pcall(draw, self, ...)
  g.rectangle = rectangle
  self.letterboxWhite = white
  if not ok then error(result,0) end
  return result
end
return Battle
