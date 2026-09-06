-- Isolated POKEPORT_DRIVER: keep the copied device options, never save.
-- LEAF_PRESENTATION_BASELINE=1 ends after the three fixed rendering cases.
return function(Game)
  io.stdout:setvbuf("no")
  love.errorhandler=function(message)
    print("LEAF_TEST_ERROR "..tostring(message).."\n"..debug.traceback())
    love.graphics.setCanvas()
    return function() return 1 end
  end
  Game.overworld.rollEncounter=function() return nil end
  Game:restoreSave(assert(require("src.core.SaveData").load()),nil,{freshBoot=true})
  while Game.stack:top() ~= Game.overworld do Game.stack:pop() end
  local opts=Game.save.options
  -- The engine disables pacing and forces 1/60 steps for drivers. This
  -- visual test observes once per rendered frame: restore the saved cap
  -- and give Game's normal fixed-step accumulator the matching frame dt.
  local cap=tonumber(opts.fpsCap) or 60
  if cap <= 0 then cap=60 end
  local update=Game.update
  Game.update=function(self) return update(self,1/cap) end
  local deadline=love.timer.getTime()
  print(string.format("LEAF_CONFIG layout=%s colors=%s fit=%s hud=%s cap=%s animations=%s",
    tostring(opts.battleLayout),tostring(opts.colors),tostring(opts.battleFit),
    tostring(opts.battleHud),tostring(opts.fpsCap),tostring(opts.animations)))
  Game.overworld:startWarpTo("VIRIDIAN_FOREST",8,10,"down")
  local State=require("src.battle.BattleState")
  local PaletteFX=require("src.render.PaletteFX")
  local g, draw, rectangle=love.graphics,State.draw,love.graphics.rectangle
  local battle, ready, currentCase, acted, escaped
  local zoneFills,waveFills=0,0
  g.rectangle=function(mode,x,y,w,h,...)
    if battle and mode == "fill" then
      if g.getShader() and g.getShader() == PaletteFX.shader() then zoneFills=zoneFills+1 end
      if g.getCanvas() == battle.waveCanvas and w == 160 and h == 144 then waveFills=waveFills+1 end
    end
    return rectangle(mode,x,y,w,h,...)
  end
  State.draw=function(self,...)
    local originalFx=self.fx
    self.fx=self.fx or {}
    local sx,sy,wavy=self.fx.shakeX,self.fx.shakeY,self.fx.wavy
    if currentCase == "shake" then self.fx.shakeX,self.fx.shakeY=2,2 end
    if currentCase == "wave" then self.fx.wavy={phase=0} end
    local answer=draw(self,...)
    self.fx.shakeX,self.fx.shakeY,self.fx.wavy=sx,sy,wavy
    self.fx=originalFx
    return answer
  end
  local started,report,last=love.timer.getTime(),love.timer.getTime(),nil
  local times={}
  while love.timer.getTime()-started < 120 do
    deadline=deadline+1/cap
    local delay=deadline-love.timer.getTime()
    if delay > 0 then love.timer.sleep(delay)
    elseif delay < -1/cap then deadline=love.timer.getTime() end
    local now=love.timer.getTime()
    if last then times[#times+1]=(now-last)*1000 end
    last=now
    if not battle and Game.stack:top() == Game.overworld and not Game.overworld.transitioning then
      local mon=require("src.pokemon.Pokemon").new(Game.data,"BLASTOISE",30)
      mon.moves={{id="GROWL",pp=40},{id="SURF",pp=15}}
      Game.save.party={mon}
      battle=State.newWild(Game,"SNORLAX",40)
      battle.enemy.curMoves={{id="TACKLE",pp=35}}
      battle.enemy.mon.moves=battle.enemy.curMoves
      battle.onFinish=function(result) print("LEAF_BATTLE_END "..tostring(result)) end
      Game.stack:push(battle)
    end
    if battle and Game.stack:top() == battle then
      if battle.phase == "messages" and math.floor(now*4)%2 == 0 then
        Game.input:sourcePress("a","presentation-test")
      else Game.input:sourceRelease("a","presentation-test") end
      if not ready and battle.phase == "menu" then ready=now end
      if ready then
        local elapsed=now-ready
        local nextCase=elapsed < 6 and "idle" or elapsed < 12 and "shake"
          or elapsed < 18 and "wave" or "turn"
        if nextCase ~= currentCase then
          print(string.format("LEAF_CASE %s t=%.2f",nextCase,now-started)); currentCase=nextCase
        end
        if elapsed >= 18 and os.getenv("LEAF_PRESENTATION_BASELINE") == "1" then return end
        if elapsed >= 18 and not acted and battle.phase == "menu" then
          battle:chooseMenu("fight"); battle:chooseMove(2); acted=true
          print("LEAF_ACTION SURF vs TACKLE")
        end
        if elapsed >= 65 and not escaped and battle.phase == "menu" then
          battle:chooseMenu("run"); escaped=true
        end
      end
    end
    if now-report >= 5 then
      table.sort(times)
      local file=assert(io.open("/proc/self/status"))
      local status=file:read("*a"); file:close()
      print(string.format("LEAF_PRESENT t=%.2f fps=%.2f p95=%.2f zone_fills=%d wave_fills=%d rss_kb=%s swap_kb=%s case=%s phase=%s",
        now-started,#times/(now-report),times[math.ceil(#times*.95)] or 0,
        zoneFills,waveFills,status:match("VmRSS:%s*(%d+)"),status:match("VmSwap:%s*(%d+)"),
        tostring(currentCase),Game.stack:top() == battle and battle.phase or "world"))
      times,zoneFills,waveFills,report={},0,0,now
    end
    coroutine.yield()
  end
end
