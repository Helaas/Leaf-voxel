local V = ...
local Quality = {}
Quality.setting = V.require("ModSetting").new("renderScale", "RES",
  {3, 2, 4}, {"1/3", "1/2", "1/4"})
function Quality.scale() return Quality.setting:get() end
function Quality.renderDistance() return 32 end
function Quality.shadows() return "off" end
function Quality.shadowsOff() return true end

-- The engine composites overrides at display size. Upscale once with nearest
-- sampling; the 3D pass remains small and the engine's UI stays at full size.
local target
function Quality.present(canvas, w, h)
  if not target or target:getWidth() ~= w or target:getHeight() ~= h then
    if target then target:release() end
    target = love.graphics.newCanvas(w, h, {dpiscale = 1})
    target:setFilter("nearest", "nearest")
  end
  love.graphics.push("all")
  love.graphics.setCanvas(target)
  love.graphics.origin()
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.setBlendMode("replace", "premultiplied")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, 0, 0, 0, w / canvas:getWidth(), h / canvas:getHeight())
  love.graphics.pop()
  return target
end
function Quality.invalidate()
  if target then target:release(); target = nil end
end
return Quality
