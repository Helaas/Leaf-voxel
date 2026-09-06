-- A cached, shallow stage under the engine's native sprites, HUD and effects.
-- No map meshes, extra battle simulation, sprite captures or per-frame shader.
local V = ...
local Battle = {}
Battle.setting = V.require("ModSetting").new("battleMode", "BATTLE",
  {"light", "classic"}, {"LIGHT", "CLASSIC"})
local Voxel = V.require("VoxelState")
local Map = require("src.world.Map")
local BattleState = require("src.battle.BattleState")
local PaletteFX = require("src.render.PaletteFX")
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

local function enabled(battle)
  return Voxel.active() and Battle.setting:get() == "light" and not battle.blankForAskName
end

local drawHUDs = BattleState.drawHUDs
function BattleState:drawHUDs(slide)
  -- WIDE already has status boxes. Back only the classic name rows, keeping
  -- the stage visible through the rest of the status area.
  if enabled(self) and not self:wideLayout() and not self.fieldCleared
      and self:statusHUDVisible() and slide == 0 then
    local g = love.graphics
    local r, green, b, a = g.getColor()
    g.setColor(1,1,1,.9)
    if self.enemy and not self.showEnemyTrainer and not self.enemySendingOut
        and not self.enemyHudPending and not self:growInScale(self.enemy)
        and not self.introBalls and not self.enemy.fainted then
      g.rectangle("fill", 4 + ((self.fx and self.fx.hudShakeX) or 0), 0, 88, 10)
    end
    if self.player and not self.safari and not self.demo and not self.showPlayerBack
        and not self.player.fainted then
      g.rectangle("fill", 78, 54, 82, 12)
    end
    g.setColor(r,green,b,a)
  end
  return drawHUDs(self, slide)
end

local draw = BattleState.draw
function Battle.drawNative(self, ...)
  local g, white = love.graphics, self.letterboxWhite
  self.letterboxWhite = false
  -- Remove paper used to clear intermediate battle surfaces. In particular,
  -- applyWavy clears a SECOND canvas, and drawZonePass fills every palette
  -- zone during a hit shake. Neither fill belongs over the cached stage.
  local rectangle, suppressed = g.rectangle, false
  g.clear(0,0,0,0)
  g.rectangle = function(mode,x,y,w,h,...)
    local _,_,_,alpha = g.getColor()
    if mode == "fill" then
      local canvas = g.getCanvas()
      local full = x == 0 and y == 0 and h == 144 and (w == 160 or w == 304)
      local intermediate = canvas and (canvas == self.bgCanvas or canvas == self.waveCanvas)
      if full and alpha > .99 and (intermediate or not suppressed) then
        suppressed = true
        if intermediate then g.clear(0,0,0,0) end
        return
      end
      -- The shade shader is active only for the native zone composite here;
      -- its rectangles clear shake-exposed strips to opaque paper. Keep the
      -- shifted canvas draw, which now reveals the stage in those strips.
      local shader = g.getShader()
      if shader and shader == PaletteFX.shader() then return end
    end
    return rectangle(mode,x,y,w,h,...)
  end
  local ok, result = pcall(draw, self, ...)
  g.rectangle = rectangle
  self.letterboxWhite = white
  if not ok then error(result,0) end
  return result
end

function BattleState:draw(...)
  if not enabled(self) then return draw(self, ...) end
  self.game.renderer:setWorldOverride(stage(self))
  return Battle.drawNative(self, ...)
end
return Battle
