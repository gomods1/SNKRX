-- Steam integration for shipped builds.
--
-- SNKRX calls steam.init() once and then calls into steam.friends and
-- steam.userStats unconditionally, all over arena.lua and main.lua. Those calls
-- go straight into an uninitialised Steam API whenever the client refuses to
-- connect -- it isn't running, or the account doesn't own the app -- and the
-- game dies with an access violation before it reaches the main menu. A build
-- that is handed to a player directly, rather than installed by Steam, hits
-- that path on the first launch.
--
-- Lua's require searches package.path before package.cpath, so this file
-- shadows luasteam.dll and becomes the module the game talks to. It loads the
-- real library itself, gates every call on init() having actually succeeded,
-- and pcalls the rest. Under Steam that means achievements, stats and rich
-- presence work exactly as before; outside it, every call is a no-op and the
-- game runs.
--
-- Not to be confused with the gitignored dev stub of the same name at the repo
-- root, which never loads the real library at all.

local function load_native()
  local paths = {}

  local ok, base = pcall(love.filesystem.getSourceBaseDirectory)
  if ok and base then paths[#paths + 1] = base .. '/luasteam.dll' end
  paths[#paths + 1] = 'luasteam.dll'
  for template in tostring(package.cpath or ''):gmatch('[^;]+') do
    paths[#paths + 1] = (template:gsub('%?', 'luasteam'))
  end

  for _, path in ipairs(paths) do
    local opened, chunk = pcall(package.loadlib, path, 'luaopen_luasteam')
    if opened and chunk then
      local called, module = pcall(chunk)
      if called and type(module) == 'table' then return module, path end
    end
  end
end


local native, native_path = load_native()
local live = false


-- A call is only forwarded while the API is known to be up. Anything the real
-- library doesn't provide, or that throws, becomes a no-op returning nil.
local function forward(section, name)
  return function(...)
    if not live then return end
    local t = section and native[section] or native
    if type(t) ~= 'table' or type(t[name]) ~= 'function' then return end
    local ok, result = pcall(t[name], ...)
    if ok then return result end
  end
end


local steam = {
  friends = {
    setRichPresence = forward('friends', 'setRichPresence'),
  },
  userStats = {
    requestCurrentStats = forward('userStats', 'requestCurrentStats'),
    resetAllStats = forward('userStats', 'resetAllStats'),
    setAchievement = forward('userStats', 'setAchievement'),
    storeStats = forward('userStats', 'storeStats'),
  },
  runCallbacks = forward(nil, 'runCallbacks'),
}


function steam.init()
  if not native or type(native.init) ~= 'function' then
    print('[steam] luasteam.dll not loaded - Steam features disabled')
    return false
  end
  local ok, result = pcall(native.init)
  live = ok and result ~= false and result ~= nil
  if live then
    print('[steam] connected (' .. tostring(native_path) .. ')')
  else
    print('[steam] client unavailable - Steam features disabled')
  end
  return live
end


-- The game shuts down from three places (quit event, main menu, pause menu), so
-- this has to stay safe to call twice.
function steam.shutdown()
  if not live then return end
  live = false
  if type(native.shutdown) == 'function' then pcall(native.shutdown) end
end


return steam
