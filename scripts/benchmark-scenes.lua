-- POKEPORT_DRIVER, isolated test data only; never writes a save or options.
-- LEAF_BENCH_KIND=transitions (default) or battle. Actual elapsed 120 seconds.
return function(Game)
  io.stdout:setvbuf("no")
  Game.overworld.rollEncounter = function() return nil end
  Game:restoreSave(assert(require("src.core.SaveData").load()),nil,{freshBoot=true})
  while Game.stack:top() ~= Game.overworld do Game.stack:pop() end
  local V = assert(Game.mods.exports.LEAF_VOXEL).lib
  local Mesher, Light = V.require("ChunkMesher"), V.require("LightBattle")
  local mode = os.getenv("LEAF_BENCH_KIND") or "transitions"
  local started, last, report = love.timer.getTime(), nil, love.timer.getTime()
  local times, frames, elapsed, step, battle = {},0,0,1,nil
  local pendingWarp, attacked, secondAttack, wide, classic, restored, escaped
  local routes = {{8,"VIRIDIAN_FOREST"},{25,"REDS_HOUSE_2F"},
    {35,"VIRIDIAN_FOREST"},{50,"CELADON_CITY"},{75,"VIRIDIAN_FOREST"}}
  while love.timer.getTime()-started < 120 do
    local now = love.timer.getTime()
    local t = now-started
    if last then
      times[#times+1]=(now-last)*1000; elapsed=elapsed+now-last; frames=frames+1
    end
    last=now
    if now-report >= 5 and #times > 0 then
      table.sort(times)
      print(string.format("LEAF_SCENE t=%.2f fps=%.2f p95=%.2f max=%.2f lua_mb=%.1f map=%s pending=%d phase=%s layout=%s mode=%s",
        t,frames/elapsed,times[math.ceil(#times*.95)],times[#times],
        collectgarbage("count")/1024,Game.overworld.map.id,Mesher.pending(),
        battle and Game.stack:top() == battle and battle.phase
          or (Game.overworld.transitioning and "warp" or "world"),
        Game.save.options.battleLayout or "classic",Light.setting:get()))
      times,frames,elapsed,report={},0,0,now
    end
    local route = routes[step]
    if route and t >= route[1] and Game.stack:top() == Game.overworld
        and (mode == "transitions" or step == 1) then
      pendingWarp={map=route[2],started=now}
      Game.overworld:startWarpTo(route[2],route[2]=="REDS_HOUSE_2F" and 3 or 8,
        route[2]=="REDS_HOUSE_2F" and 6 or 10,"down")
      step=step+1
    end
    if pendingWarp and not Game.overworld.transitioning then
      print(string.format("LEAF_WARP map=%s seconds=%.3f ready=%s",
        pendingWarp.map,now-pendingWarp.started,
        tostring(Mesher.peek(Game.overworld.map,false) ~= nil)))
      pendingWarp=nil
    end
    if mode == "battle" then
      if not battle and t >= 20 and Game.stack:top() == Game.overworld then
        local Pokemon = require("src.pokemon.Pokemon")
        local mon=Pokemon.new(Game.data,"BLASTOISE",30)
        mon.moves={{id="SURF",pp=15},{id="BUBBLEBEAM",pp=20}}
        Game.save.party={mon}
        battle=require("src.battle.BattleState").newWild(Game,"SNORLAX",40)
        battle.onFinish=function(result) print("LEAF_BATTLE_END result="..tostring(result)) end
        Game.stack:push(battle)
      end
      if battle and Game.stack:top() == battle then
        if battle.phase == "messages" and math.floor(t*4)%2 == 0 then
          Game.input:sourcePress("a","scene-benchmark")
        else Game.input:sourceRelease("a","scene-benchmark") end
        if t >= 40 and not attacked and battle.phase == "menu" then
          assert(battle:chooseMenu("fight")); assert(battle:chooseMove(1)); attacked=true
          print("LEAF_ACTION SURF")
        end
        if t >= 60 and not wide then Game.save.options.battleLayout="wide"; wide=true end
        if t >= 65 and not secondAttack and battle.phase == "menu" then
          assert(battle:chooseMenu("fight")); assert(battle:chooseMove(2)); secondAttack=true
          print("LEAF_ACTION BUBBLEBEAM")
        end
        if t >= 80 and not classic then Light.setting:sync("classic"); classic=true end
        if t >= 100 and not restored then Light.setting:sync("light"); restored=true end
        if t >= 108 and not escaped and battle.phase == "menu" then
          assert(battle:chooseMenu("run")); escaped=true; print("LEAF_ACTION RUN")
        end
      end
    end
    coroutine.yield()
  end
end
