return function(T)
  T.test("light battle clears wave and shake paper, preserves effects and backs only names", function()
    local oldLove = love
    local names = {"src.battle.BattleState", "src.world.Map", "src.render.PaletteFX"}
    local saved = {}
    for _, name in ipairs(names) do saved[name] = package.loaded[name] end
    local shader, canvas, color = nil, "ui", {1,1,1,1}
    local paletteShader = {}
    local rects, clears, draws = {}, {}, 0
    local g = {
      getCanvas=function() return canvas end,
      setCanvas=function(c) canvas=c end,
      getShader=function() return shader end,
      setShader=function(s) shader=s end,
      getColor=function() return table.unpack(color) end,
      setColor=function(...) color={...} end,
      rectangle=function(mode,x,y,w,h)
        rects[#rects+1]={canvas=canvas,x=x,y=y,w=w,h=h,a=color[4]}
      end,
      clear=function(_,_,_,a) clears[canvas]=a end,
      draw=function() draws=draws+1 end,
    }
    love = {graphics=g}
    local State = {
      wideLayout=function(self) return self.wide end,
      statusHUDVisible=function() return true end,
      growInScale=function(self) return self.growing end,
      drawHUDs=function() end,
      draw=function(self)
        g.setShader(); g.setColor(1,1,1,1)
        g.setCanvas(self.bgCanvas); g.rectangle("fill",0,0,160,144)
        self:drawHUDs(0)
        g.setCanvas(self.waveCanvas); g.rectangle("fill",0,0,160,144)
        g.setCanvas("ui"); g.setShader(paletteShader)
        g.rectangle("fill",0,0,88,32); g.draw(self.waveCanvas,2,0)
        g.setShader(); g.setColor(1,1,1,.85)
        g.rectangle("fill",0,0,160,144) -- intentional move flash
        g.setColor(1,1,1,1); g.rectangle("fill",0,96,160,48) -- dialogue
        if self.fail then error("native draw failed") end
      end,
    }
    package.loaded[names[1]], package.loaded[names[2]], package.loaded[names[3]] =
      State, {}, {shader=function() return paletteShader end}
    local mode = "light"
    local Battle = assert(loadfile("lib/LightBattle.lua"))({require=function(name)
      if name == "VoxelState" then return {active=function() return true end} end
      return {new=function() return {get=function() return mode end} end}
    end})
    local state=setmetatable({bgCanvas="bg",waveCanvas="wave",enemy={},player={},
      letterboxWhite=true}, {__index=State})
    local rectangle = g.rectangle
    Battle.drawNative(state)
    assert(#rects == 4 and draws == 1)
    assert(rects[1].canvas == "bg" and rects[1].w == 88 and rects[1].h == 10)
    assert(rects[2].x == 78 and rects[2].y == 54 and rects[2].h == 12)
    assert(rects[1].a == .9 and rects[2].a == .9)
    assert(rects[3].a == .85 and rects[4].y == 96)
    assert(clears.ui == 0 and clears.bg == 0 and clears.wave == 0)
    assert(g.rectangle == rectangle and state.letterboxWhite)
    state.fail=true
    assert(not pcall(Battle.drawNative,state))
    assert(g.rectangle == rectangle and state.letterboxWhite)
    state.fail=nil
    rects={}; state.wide=true; state:drawHUDs(0); assert(#rects == 0)
    state.wide=false; state.enemy.fainted=true; state:drawHUDs(0)
    assert(#rects == 1 and rects[1].x == 78)
    rects={}; mode="classic"; state:drawHUDs(0); assert(#rects == 0)
    state:draw(); assert(#rects == 5) -- native field, wave, zone, flash and dialogue
    love=oldLove
    for _, name in ipairs(names) do package.loaded[name]=saved[name] end
  end)
end
