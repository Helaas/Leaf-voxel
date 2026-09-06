-- Apply the Leaf Voxel reference settings to a Gen1Recomp options.lua.
--
--   lua scripts/apply-settings.lua options.lua                 -- in place
--   lua scripts/apply-settings.lua options.lua --out new.lua
--   lua scripts/apply-settings.lua options.lua --dry-run
--   lua scripts/apply-settings.lua options.lua --enable-for red,blue
--
-- Setting these by hand means a lot of menu-poking on a handheld. This merges
-- the tuned values into an existing profile and leaves everything else exactly
-- as it was: it never removes a key, and it only writes the keys listed in
-- PROFILE below.
--
-- Nothing personal is written. The profile carries display, battle and
-- performance choices only -- no playthrough ids, save slots, arena
-- fingerprints, sync display name, or another mod's player id. Those keys live
-- in the same file and are carried through untouched; PRESERVED lists them and
-- the script verifies they survived before writing.
--
-- Close Gen1Recomp first. The engine rewrites options.lua as it exits, so a
-- patch applied while it runs is overwritten.

local PROFILE = {
  -- Colour: ADVANCED is the `redpp` id in PaletteFX.MODES (pokered-gbc
  -- per-tile), the richest of the three colourisations.
  colors = "redpp",
  palette = "",
  gbcfx = 0,

  -- Battle presentation.
  battleLayout = "wide",
  battleFit = "fill",
  battleHud = "extended",
  battleStyle = "shift",
  battleBg = "white",

  -- Performance. The frame cap belongs to the engine, not the mod.
  fpsCap = 30,
  performance = "low",
  faithfulRes = 2,
  logicClock = "60",
  animations = true,

  -- World and display.
  voidFill = "trees",
  videoMode = "borderless",
  uiLayout = "dynamic",
  uiLetterbox = "auto",
  screenPos = "center",
  zoom = 0,

  -- Leaf Voxel's own options. These are also the package defaults, so this
  -- only matters when a previous install left different values behind.
  modOptions = {
    LEAF_VOXEL = { renderScale = 3, battleMode = "light" },
  },
}

-- Written only with --enable-for. Leaf Voxel conflicts with these.
local CONFLICTING = {
  "DRAMALESS_SHAPE", "DRAMATIC_SHAPE", "TERRARIUM",
  "BATTLE_ART_VOXEL_FORK", "potato_voxel",
}

-- Never written, and checked to be intact afterwards.
local PRESERVED = {
  "playthroughIds", "saveSlots", "saveSync", "arenaProfiles", "cartOptions",
  "cartMods", "lastVersion", "modIndexCache", "modIndexes", "modUpdateCache",
}

local function die(fmt, ...)
  io.stderr:write("apply-settings: " .. string.format(fmt, ...) .. "\n")
  os.exit(1)
end

-- ---------------------------------------------------------------- load

local function loadOptions(path)
  local f = io.open(path, "rb")
  if not f then die("cannot read %s", path) end
  local source = f:read("*a")
  f:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  if not chunk then die("%s does not parse: %s", path, err) end
  -- No globals: the file is data, so a chunk touching anything else is a
  -- reason to stop rather than to guess.
  if setfenv then setfenv(chunk, {}) end
  local ok, value = pcall(chunk)
  if not ok then die("%s did not evaluate: %s", path, value) end
  if type(value) ~= "table" then die("%s did not return a table", path) end
  return value, source
end

-- ---------------------------------------------------------------- serialise
-- Byte-for-byte in the engine's own format: two-space indent, keys sorted,
-- trailing comma on every entry, empty tables inline. Round-tripping an
-- untouched file must reproduce it exactly (see --dry-run output).

local function isIdentifier(key)
  return type(key) == "string" and key:match("^[%a_][%w_]*$") ~= nil
end

local function sortedKeys(t)
  local numbers, strings = {}, {}
  for k in pairs(t) do
    if type(k) == "number" then numbers[#numbers + 1] = k
    elseif type(k) == "string" then strings[#strings + 1] = k
    else die("unsupported key type %s", type(k)) end
  end
  table.sort(numbers)
  table.sort(strings)
  local out = {}
  for _, k in ipairs(numbers) do out[#out + 1] = k end
  for _, k in ipairs(strings) do out[#out + 1] = k end
  return out
end

local function isEmpty(t)
  return next(t) == nil
end

local function serialiseValue(value, indent, out)
  local kind = type(value)
  if kind == "table" then
    if isEmpty(value) then
      out[#out + 1] = "{}"
      return
    end
    out[#out + 1] = "{\n"
    local inner = indent .. "  "
    for _, key in ipairs(sortedKeys(value)) do
      out[#out + 1] = inner
      if isIdentifier(key) then
        out[#out + 1] = key .. " = "
      elseif type(key) == "number" then
        out[#out + 1] = "[" .. tostring(key) .. "] = "
      else
        out[#out + 1] = "[" .. string.format("%q", key) .. "] = "
      end
      serialiseValue(value[key], inner, out)
      out[#out + 1] = ",\n"
    end
    out[#out + 1] = indent .. "}"
  elseif kind == "string" then
    out[#out + 1] = string.format("%q", value)
  elseif kind == "number" or kind == "boolean" then
    out[#out + 1] = tostring(value)
  else
    die("unsupported value type %s", kind)
  end
end

local function serialise(options)
  local out = { "return " }
  serialiseValue(options, "", out)
  out[#out + 1] = "\n"
  return table.concat(out)
end

-- ---------------------------------------------------------------- merge

local changes = {}

local function describe(value)
  if type(value) == "string" then return string.format("%q", value) end
  if value == nil then return "unset" end
  return tostring(value)
end

local function merge(target, source, path)
  for _, key in ipairs(sortedKeys(source)) do
    local want, here = source[key], target[key]
    local where = path == "" and key or (path .. "." .. key)
    if type(want) == "table" then
      if type(here) ~= "table" then target[key] = {}; here = target[key] end
      merge(here, want, where)
    elseif here ~= want then
      changes[#changes + 1] = string.format("  %-28s %s -> %s", where, describe(here), describe(want))
      target[key] = want
    end
  end
end

local function setEnabled(options, versions)
  for _, version in ipairs(versions) do
    local byVersion = options.modsByVersion or {}
    options.modsByVersion = byVersion
    byVersion[version] = byVersion[version] or {}
    local slot = { LEAF_VOXEL = true }
    for _, id in ipairs(CONFLICTING) do
      -- Only turn off a conflicting renderer this profile already knows about.
      if byVersion[version][id] ~= nil then slot[id] = false end
    end
    merge(byVersion[version], slot, "modsByVersion." .. version)

    -- The launcher mirrors enablement into each mod profile; keep them in step
    -- so the UI and the engine agree.
    for index, profile in pairs(options.modProfiles or {}) do
      if type(profile) == "table" and type(profile.enabledByVersion) == "table"
          and profile.enabledByVersion[version] then
        merge(profile.enabledByVersion[version], slot,
          string.format("modProfiles[%s].enabledByVersion.%s", tostring(index), version))
      end
    end
  end
end

-- ---------------------------------------------------------------- main

local args = { ... }
local input, output, dryRun, enableFor = nil, nil, false, nil
local i = 1
while i <= #args do
  local a = args[i]
  if a == "--dry-run" then dryRun = true
  elseif a == "--out" then i = i + 1; output = args[i]
  elseif a == "--enable-for" then i = i + 1; enableFor = args[i]
  elseif a:match("^%-") then die("unknown option %s", a)
  elseif not input then input = a
  else die("unexpected argument %s", a) end
  i = i + 1
end
if not input then
  die("usage: apply-settings.lua <options.lua> [--out FILE] [--enable-for red,blue] [--dry-run]")
end
output = output or input

local options, source = loadOptions(input)

-- Round-trip check first: if re-serialising the untouched file does not
-- reproduce it byte for byte, this script does not understand the format and
-- must not rewrite the user's profile.
local roundTrip = serialise(options)
if roundTrip ~= source then
  die("refusing to write: re-serialising %s does not reproduce it byte for byte.\n"
    .. "The engine's format has changed; update the serialiser before using this script.", input)
end

local preserved = {}
for _, key in ipairs(PRESERVED) do preserved[key] = serialise({ options[key] }) end

merge(options, PROFILE, "")
if enableFor then
  local versions = {}
  for version in enableFor:gmatch("[^,]+") do versions[#versions + 1] = (version:gsub("%s", "")) end
  setEnabled(options, versions)
end

for _, key in ipairs(PRESERVED) do
  if serialise({ options[key] }) ~= preserved[key] then
    die("internal error: %s was modified; refusing to write", key)
  end
end

if #changes == 0 then
  print("Already matches the profile; nothing to change.")
  os.exit(0)
end

print("Changes:")
for _, line in ipairs(changes) do print(line) end

if dryRun then
  print("\n--dry-run: nothing written.")
  os.exit(0)
end

local text = serialise(options)
local out = io.open(output, "wb")
if not out then die("cannot write %s", output) end
out:write(text)
out:close()
print(string.format("\nWrote %s (%d bytes).", output, #text))
