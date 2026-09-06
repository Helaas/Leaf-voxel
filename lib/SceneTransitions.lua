-- Let door fades cover asynchronous meshing, without blocking the event loop.
local V = ...
local Voxel = V.require("VoxelState")
local Scene = V.require("VoxelScene")
local Mesher = V.require("ChunkMesher")
local Transition = require("src.render.Transition")
local new, update = Transition.new, Transition.update

function Transition.new(game, midpoint, done, warp, opts)
  local self = new(game, midpoint, done, warp, opts)
  if warp and Voxel.active() then
    self.framesIn = math.max(self.framesIn or 0, 8)
    self.leafWait = true
  end
  return self
end

function Transition:update(dt)
  if self.leafWait and self.phase == "in" and self.t == 0 then
    local ow = self.game.overworld
    if Voxel.active() and ow and ow.map then
      local terrain = Scene.prefetch(ow)
      self.leafWaitStarted = self.leafWaitStarted or love.timer.getTime()
      if not terrain and Mesher.jobPending(ow.map.id, false)
          and love.timer.getTime() - self.leafWaitStarted < 4 then
        return
      end
    end
    self.leafWait = nil
  end
  return update(self, dt)
end
return Transition
