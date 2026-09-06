return function(T)
  T.test("recent map reuse is bounded and never keeps obsolete jobs", function()
    local saved = package.loaded["src.render.Assets"]
    package.loaded["src.render.Assets"] = {register = function() end}
    local Mesher = assert(loadfile("lib/ChunkMesher.lua"))({require = function()
      return {invalidate = function() end}
    end})
    local released = {}
    Mesher.build = function(map)
      return {getVertexCount = function() return map.vertices end,
        release = function() released[map.id] = true end}
    end
    local town, room, huge = {id="town",vertices=60}, {id="room",vertices=12},
      {id="huge",vertices=600000}
    local original = Mesher.get(town, false)
    Mesher.get(room, false)
    Mesher.request(town, true)
    local keep = Mesher.setLive({room=true}, "town")
    assert(keep.town and Mesher.peek(town,false) == original)
    assert(Mesher.pending() == 0)
    Mesher.setLive({town=true}, "room")
    assert(Mesher.peek(town,false) == original)
    Mesher.get(huge,false)
    Mesher.setLive({huge=true}, "room")
    assert(released.town and not released.room)
    keep = Mesher.setLive({room=true}, "huge")
    assert(not keep.huge and released.huge)
    Mesher.invalidate()
    package.loaded["src.render.Assets"] = saved
  end)

  T.test("warp hold releases on ready, failure, disable or timeout and keeps callbacks", function()
    local saved, oldLove = package.loaded["src.render.Transition"], love
    local time, active, terrain, pending = 0, true, nil, true
    love = {timer={getTime=function() return time end}}
    local Transition = {new=function(game,midpoint,done,warp,opts)
      return {game=game,onMidpoint=midpoint,onDone=done,framesIn=opts and opts.framesIn or 0,
        phase="out",t=0}
    end, update=function(self) self.t = self.t+1 end}
    package.loaded["src.render.Transition"] = Transition
    assert(loadfile("lib/SceneTransitions.lua"))({require=function(name)
      if name == "VoxelState" then return {active=function() return active end} end
      if name == "VoxelScene" then return {prefetch=function() return terrain end} end
      return {jobPending=function() return pending end}
    end})
    local game = {overworld={map={id="room"}}}
    local callback = function() end
    local function warp()
      local t = Transition.new(game,callback,callback,true)
      assert(t.framesIn == 8 and t.onMidpoint == callback and t.onDone == callback)
      t.phase = "in"
      return t
    end
    local t = warp()
    Transition.update(t,1/60); assert(t.t == 0)
    terrain = {}; Transition.update(t,1/60); assert(t.t == 1)
    terrain = nil; t = warp(); pending = false
    Transition.update(t,1/60); assert(t.t == 1)
    pending = true; t = warp(); Transition.update(t,1/60)
    time = 4; Transition.update(t,1/60); assert(t.t == 1)
    t = warp(); active = false; Transition.update(t,1/60); assert(t.t == 1)
    assert(not Transition.new(game,callback,callback,true).leafWait)
    active = true
    assert(not Transition.new(game,callback,callback,false).leafWait)
    assert(Transition.new(game,callback,callback,true,{framesIn=24}).framesIn == 24)
    love, package.loaded["src.render.Transition"] = oldLove, saved
  end)
end
