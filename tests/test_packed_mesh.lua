return function(T)
  T.test("packed mesh preserves triangle order, UVs and corner shading across uploads", function()
    local oldLove = love
    local uploads, checks = {}, 0
    love = {
      data = {
        pack = function(_, format, ...) return string.pack(format, ...) end,
        newByteData = function(blob) return {blob = blob, release = function() end} end,
      },
      graphics = {newMesh = function(_, count)
        return { count = count, setVertices = function(_, data, first)
          uploads[#uploads + 1] = {data.blob, first}
        end, release = function() end }
      end},
    }
    local V = {require = function(name)
      if name == "BuildBudget" then return {tick = function() end,
        check = function() checks = checks + 1 end} end
      return {FORMAT = {}}
    end}
    local Packed = assert(loadfile("lib/PackedMesh.lua"))(V)
    local empty = Packed.new()
    assert(empty.finish() == nil)
    local sink = Packed.new()
    local corners = {{1,2,3},{4,5,6},{7,8,9},{10,11,12}}
    local uv, shades = {{0,1},{1,1},{1,0},{0,0}}, {0.25,0.5,0.75,1}
    for _ = 1, 1025 do sink.push(corners, uv, shades) end
    local mesh = sink.finish()
    assert(mesh.count == 6150 and #uploads == 3 and checks == 3)
    assert(uploads[1][2] == 1 and uploads[2][2] == 3073 and uploads[3][2] == 6145)
    local order, vertex = {1,2,3,1,3,4}, 0
    for _, upload in ipairs(uploads) do
      assert(#upload[1] <= 3072 * 24)
      for pos = 1, #upload[1], 24 do
        local x,y,z,u,v,shade = string.unpack("ffffff", upload[1], pos)
        local i = order[vertex % 6 + 1]
        assert(x == corners[i][1] and y == corners[i][2] and z == corners[i][3])
        assert(u == uv[i][1] and v == uv[i][2] and shade == shades[i])
        vertex = vertex + 1
      end
    end
    assert(vertex == mesh.count)
    love = oldLove
  end)
  T.test("leaving a neighbourhood cancels all obsolete mesh jobs", function()
    local oldAssets = package.loaded["src.render.Assets"]
    package.loaded["src.render.Assets"] = {register = function() end}
    local Mesher = assert(loadfile("lib/ChunkMesher.lua"))({require = function()
      return {invalidate = function() end}
    end})
    Mesher.request({id = "town"}, false)
    Mesher.request({id = "route"}, true)
    Mesher.setLive({town = true, route = true})
    assert(Mesher.pending() == 2)
    Mesher.setLive({interior = true})
    assert(Mesher.pending() == 0)
    Mesher.refresh("town")
    Mesher.invalidate()
    package.loaded["src.render.Assets"] = oldAssets
  end)

  T.test("trees keep whole silhouettes and grass preserves walkable ground", function()
    local Shape = assert(loadfile("lib/TileShape.lua"))({
      data = function(name) return assert(loadfile("data/" .. name .. ".lua"))() end,
    })
    local map = {tileset = {id = "FOREST", grassTile = 7, animatedTiles = {}},
      isWaterCell = function() return false end,
      isWalkableCell = function() return true end}
    local shapes = Shape.forMap(map)
    for _, class in ipairs({"cylinder", "canopy", "stump", "planter", "can"}) do
      local s = shapes.classes[class]
      if class == "planter" or class == "can" then
        assert(s.class == "tree" and s.art == "upright")
      else
        assert(s.class == class and (s.art == "cylinder" or s.art == "canopy"))
      end
      assert(not s.flat and s.h > 0)
    end
    local grass = shapes.classes.grass
    assert(grass.flat and grass.art == "flat" and grass.h == 0)
    assert(Shape.at(map, {[7] = grass}, 7, 0, 0) == grass)
    assert(map:isWalkableCell(0, 0))
  end)

  T.test("building surfaces preserve footprint, atlas bounds and wall height", function()
    local template = {tiles = {{0,1},{2,3}}, roofRows = 8}
    local Buildings = assert(loadfile("lib/Buildings.lua"))({
      require = function() return {tick = function() end} end,
      data = function() return {buildings = {TEST = {template}}} end,
    })
    local S = {tileAt = {}, shapeAt = {}, skip = {}, ground = {}, objectQuads = {}}
    local function key(x,y) return (y+64)*4096+x+64 end
    for y = 0, 1 do for x = 0, 1 do
      S.tileAt[key(x,y)] = template.tiles[y+1][x+1]
    end end
    Buildings.build(S, {def = {width=1,height=1},
      tileset = {id="TEST",imageWidth=16,imageHeight=16}}, {}, 2)
    assert(#S.objectQuads == 8) -- 2 roof, 4 facade, 2 side quads
    for _, q in ipairs(S.objectQuads) do
      for i = 1, 4 do
        local v = q[i]
        assert(v[1]>=0 and v[1]<=16 and v[2]>=0 and v[2]<=8 and v[3]>=0 and v[3]<=16)
        assert(q.uv[i][1]>0 and q.uv[i][1]<1 and q.uv[i][2]>0 and q.uv[i][2]<1)
      end
    end
    for y = 0, 1 do for x = 0, 1 do assert(S.skip[key(x,y)]) end end
  end)

  T.test("round trees group once and preserve their full hull", function()
    local oldAssets, oldMap = package.loaded["src.render.Assets"], package.loaded["src.world.Map"]
    local pixels = {getPixel = function() return 0,0,0,1 end}
    package.loaded["src.render.Assets"] = {register = function() end, imageData = function() return pixels end}
    package.loaded["src.world.Map"] = {}
    local Structures = assert(loadfile("lib/Structures.lua"))({
      require = function() return {tick = function() end, invalidate = function() end} end,
      data = function() return {} end,
    })
    local S = {tileAt = {}, shapeAt = {}, skip = {}, ground = {}, roundStamps = {}}
    local function key(x,y) return (y+64)*4096+x+64 end
    for y = 0,3 do for x = 0,3 do
      S.tileAt[key(x,y)] = y*4+x
      S.shapeAt[key(x,y)] = {class="cylinder",art="cylinder",flat=false}
    end end
    S.shapeAt[key(0,0)] = {class="canopy",art="canopy",flat=false}
    Structures.buildCylinders(S,{def={width=1,height=1},
      tileset={id="TEST",image="synthetic",imageWidth=32,imageHeight=32,tilesPerRow=4}},0,3,0,3,{})
    assert(#S.roundStamps == 1 and S.roundStamps[1].r == 16)
    local quads = S.roundStamps[1].quads
    assert(#quads > 0)
    for y = 0,3 do for x = 0,3 do assert(S.skip[key(x,y)]) end end
    package.loaded["src.render.Assets"], package.loaded["src.world.Map"] = oldAssets, oldMap
  end)

  T.test("tree bounds intersect the frustum at edges and reject hidden boxes", function()
    local matrix = {.02,0,0,-1, 0,.02,0,-1, 0,0,.02,-1, 0,0,0,1}
    local Trees = assert(loadfile("lib/TreeMeshes.lua"))({require = function(name)
      if name == "Voxel3D" then return {vp=matrix} end
      return {}
    end})
    local tree = {x=50,z=50,radius=8,model={top=32}}
    assert(Trees.visible(tree))
    tree.x = 107
    assert(Trees.visible(tree))
    tree.x = 109
    assert(not Trees.visible(tree))
    tree.x, tree.z = 50,-20
    assert(not Trees.visible(tree))
    tree.z = 0
    assert(Trees.visible(tree))
    assert(not Trees.visible(tree,200,0))
  end)

  T.test("repeated trees share a mesh and neighbor masks omit border copies", function()
    local built, released = 0, 0
    local quad = {{-8,0,-8},{8,0,-8},{8,16,8},{-8,16,8},u=0.5,v=0.5,shade=1}
    local quads = {quad}
    local stamps = {{mx=8,mz=8,quads=quads},{mx=24,mz=24,quads=quads},
      {mx=40,mz=8,quads=quads}}
    local Trees = assert(loadfile("lib/TreeMeshes.lua"))({require = function(name)
      if name == "Structures" then return {forMap=function() return {roundStamps=stamps} end} end
      if name == "PackedMesh" then return {new=function()
        built = built+1
        return {push=function() end,finish=function() return {release=function() released=released+1 end} end}
      end} end
      return {}
    end})
    local map = {def={width=1,height=1}}
    local list = Trees.build(map,false,{{32,0,64,32}})
    assert(#list == 2 and built == 1 and list[1].model == list[2].model)
    assert(#Trees.build(map,true) == 2 and built == 1)
    Trees.invalidate()
    assert(released == 1)
  end)

end
