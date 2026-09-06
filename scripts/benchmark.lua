-- Run with POKEPORT_DRIVER against an isolated copy of the user's data.
-- The engine advances one 1/60 logic step per driver frame; use a 60 FPS cap.
return function(Game)
  io.stdout:setvbuf("no")
  -- Keep this graphics stress route out of battles (the copied save may
  -- precede receiving a starter). Normal gameplay is checked separately.
  Game.overworld.rollEncounter = function() return nil end
  local Input = Game.input
  local def = require("src.render.Pipelines").get("voxel")
  for _, name in ipairs({"update", "drawWorld"}) do
    local fn = def[name]
    def[name] = function(...)
      local t = love.timer.getTime()
      local result = fn(...)
      local ms = (love.timer.getTime()-t)*1000
      if ms > 40 then print(string.format("LEAF_SLOW %s %.2f", name, ms)) end
      return result
    end
  end
  Game:restoreSave(assert(require("src.core.SaveData").load()), nil, {freshBoot = true})
  while Game.stack:top() ~= Game.overworld do Game.stack:pop() end
  local draw, graphicsDraw, lastStats = love.draw, love.graphics.draw, {}
  local meshDraws, meshVertices = 0, 0
  love.graphics.draw = function(object, ...)
    if object and object.typeOf and object:typeOf("Mesh") then
      meshDraws = meshDraws + 1
      meshVertices = meshVertices + object:getVertexCount()
    end
    return graphicsDraw(object, ...)
  end
  love.draw = function(...)
    meshDraws, meshVertices = 0, 0
    draw(...)
    lastStats = love.graphics.getStats()
    lastStats.vertices, lastStats.meshes = meshVertices, meshDraws
  end
  local map = os.getenv("LEAF_BENCH_MAP") or "PALLET_TOWN"
  local moved = false
  local started, last, report = love.timer.getTime(), nil, love.timer.getTime()
  local times, frames, elapsed = {}, 0, 0
  print("LEAF_BENCH start map=" .. tostring(Game.overworld.map.id))
  while love.timer.getTime() - started < 120 do
    local now = love.timer.getTime()
    if last then
      times[#times + 1] = (now - last) * 1000
      elapsed = elapsed + now - last
      frames = frames + 1
    end
    last = now
    if now - report >= 5 and #times > 0 then
      table.sort(times)
      local stats = lastStats
      local ow = Game.overworld
      print(string.format("LEAF_BENCH t=%.1f fps=%.2f p50=%.2f p95=%.2f p99=%.2f max=%.2f lua_mb=%.1f mesh_draws=%d vertices=%d map=%s x=%.1f y=%.1f top=%s",
        now-started, frames/elapsed, times[math.ceil(#times*.5)],
        times[math.ceil(#times*.95)], times[math.ceil(#times*.99)], times[#times],
        collectgarbage("count")/1024, stats.meshes or 0, stats.vertices or 0,
        tostring(ow.map.id), ow.player.px, ow.player.py, tostring(Game.stack:top().screenId)))
      times, frames, elapsed, report = {}, 0, 0, now
    end
    if not moved and now - started >= 15 then
      while Game.stack:top() do Game.stack:pop() end
      Game.stack:push(Game.overworld, map, 8, 10, "down", {via = "boot", freshBoot = true})
      moved = true
    end
    if moved and Game.stack:top() == Game.overworld then
      local dir = ({"right", "down", "left", "up"})[math.floor((now-started-15)/2)%4+1]
      for _, key in ipairs({"left", "right", "up", "down"}) do if key == dir then Input:sourcePress(key, "benchmark") else Input:sourceRelease(key, "benchmark") end end
    end
    coroutine.yield()
  end
end
