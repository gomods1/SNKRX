-- Situational awareness inside the arena.
--
-- The arena is the part of SNKRX that cannot be solved with speech alone. The
-- snake never stops moving, enemies converge from every side, and the only
-- control is "turn left" or "turn right". A player needs a continuous sense of
-- where the threats are, not a sentence about them two seconds later.
--
-- So this module runs three continuous sonars -- enemies, walls, pickups --
-- plus a set of on-demand spoken reports for the things that are better said
-- than sung: wave progress, party health, build composition.

local hud = {}
access.hud = hud

local describe = access.describe

hud.sonar_enemies = true
hud.sonar_walls = true
hud.sonar_pickups = true
hud.announce_combat = true

local timers = {enemy = 0, wall = 0, edge = 0, pickup = 0, scan = 0}
local cache = {enemies = {}, pickups = {}}
local watched = {}


function hud.reset()
  timers = {enemy = 0, wall = 0, edge = 0, pickup = 0, scan = 0}
  cache = {enemies = {}, pickups = {}}
  watched = {}
end


local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function remap(v, a, b, x, y)
  if b == a then return x end
  return x + (clamp(v, math.min(a, b), math.max(a, b)) - a) * (y - x) / (b - a)
end


local function arena()
  local st = main and main.current
  if st and st.is and st:is(Arena) then return st end
  return nil
end


-- The snake head: the only thing the player actually steers.
local function head()
  local a = arena()
  if not a then return nil end
  local p = a.player
  if not p or p.dead then return nil end
  return p, a
end


local function playable()
  local a = arena()
  if not a then return false end
  if a.paused or a.died or a.won or a.choosing_passives or a.transitioning then return false end
  if slow_amount and slow_amount < 0.2 then return false end
  return true
end


-- Bearing of a point relative to where the snake is pointing: 0 is dead ahead,
-- positive is to the player's right.
local function relative_bearing(p, x, y)
  return describe.wrap_angle(math.atan2(y - p.y, x - p.x) - p.r)
end


-- ------------------------------------------------------------------ sonar --

local function scan_enemies(p, a)
  local list = {}
  local objects = a.main:get_objects_by_classes(a.enemies)
  for _, e in ipairs(objects) do
    if not e.dead then
      local dx, dy = e.x - p.x, e.y - p.y
      local d = math.sqrt(dx * dx + dy * dy)
      table.insert(list, {o = e, d = d, b = describe.wrap_angle(math.atan2(dy, dx) - p.r)})
    end
  end
  table.sort(list, function(l, r) return l.d < r.d end)
  return list
end


local function scan_pickups(p, a)
  local list = {}
  for _, class_name in ipairs({'Gold', 'HealingOrb'}) do
    local class = _G[class_name]
    if class then
      for _, g in ipairs(a.main:get_objects_by_class(class)) do
        if not g.dead then
          local dx, dy = g.x - p.x, g.y - p.y
          local d = math.sqrt(dx * dx + dy * dy)
          table.insert(list, {o = g, d = d, b = describe.wrap_angle(math.atan2(dy, dx) - p.r),
            kind = (class_name == 'Gold') and 'gold' or 'orb'})
        end
      end
    end
  end
  table.sort(list, function(l, r) return l.d < r.d end)
  return list
end


local function ping_enemy(e, volume)
  local pan = math.sin(e.b)
  local front = math.cos(e.b) > 0
  local pitch = remap(e.d, 16, 240, 1.9, 0.6)
  local name = front and 'enemy_front' or 'enemy_back'
  -- Contact range: the snake takes damage from touching an enemy, so the last
  -- few pixels get their own unmistakable sound.
  if e.d < 26 then name = 'enemy_close' end
  access.audio.play(name, pan, pitch, volume or 1)
end


-- How far ahead the wall is, following the current heading.
local function wall_ahead(p, a)
  local dx, dy = math.cos(p.r), math.sin(p.r)
  local t = math.huge
  if dx > 1e-6 then t = math.min(t, (a.x2 - p.x) / dx)
  elseif dx < -1e-6 then t = math.min(t, (a.x1 - p.x) / dx) end
  if dy > 1e-6 then t = math.min(t, (a.y2 - p.y) / dy)
  elseif dy < -1e-6 then t = math.min(t, (a.y1 - p.y) / dy) end
  if t == math.huge then return nil end
  return math.max(0, t)
end


-- The closest wall regardless of heading, with the direction it lies in.
local function nearest_wall(p, a)
  local candidates = {
    {d = p.x - a.x1, r = math.pi,     name = 'left wall'},
    {d = a.x2 - p.x, r = 0,           name = 'right wall'},
    {d = p.y - a.y1, r = -math.pi/2,  name = 'top wall'},
    {d = a.y2 - p.y, r = math.pi/2,   name = 'bottom wall'},
  }
  local best = candidates[1]
  for _, c in ipairs(candidates) do if c.d < best.d then best = c end end
  return best
end


local function update_sonar(dt)
  local p, a = head()
  if not p then return end

  timers.scan = timers.scan - dt
  if timers.scan <= 0 then
    timers.scan = 0.1
    cache.enemies = scan_enemies(p, a)
    cache.pickups = scan_pickups(p, a)
  end

  -- Enemies -------------------------------------------------------------
  if hud.sonar_enemies then
    timers.enemy = timers.enemy - dt
    local nearest = cache.enemies[1]
    if nearest and timers.enemy <= 0 then
      timers.enemy = remap(nearest.d, 20, 220, 0.10, 0.70)
      ping_enemy(nearest, 1)
      -- If there is also something closing from the opposite side, say so:
      -- being pinched is the situation that kills runs.
      for i = 2, math.min(#cache.enemies, 6) do
        local other = cache.enemies[i]
        if other.d < nearest.d * 1.8 and (other.b * nearest.b) < 0 and
           math.abs(describe.wrap_angle(other.b - nearest.b)) > math.pi / 3 then
          ping_enemy(other, 0.55)
          break
        end
      end
    end
  end

  -- Walls ---------------------------------------------------------------
  if hud.sonar_walls then
    local ahead = wall_ahead(p, a)
    if ahead and ahead < 110 then
      timers.wall = timers.wall - dt
      if timers.wall <= 0 then
        timers.wall = remap(ahead, 6, 110, 0.10, 0.55)
        access.audio.play('wall', 0, remap(ahead, 6, 110, 1.7, 0.85), remap(ahead, 6, 110, 1, 0.35))
      end
    else
      timers.wall = 0
    end

    -- Running along a wall is safe but disorienting; a quiet pad on the side
    -- the wall is on keeps the player oriented without nagging.
    local wall = nearest_wall(p, a)
    if wall.d < 34 then
      timers.edge = timers.edge - dt
      if timers.edge <= 0 then
        timers.edge = 0.45
        local b = describe.wrap_angle(wall.r - p.r)
        access.audio.play('edge', math.sin(b), remap(wall.d, 0, 34, 1.15, 0.9), remap(wall.d, 0, 34, 0.9, 0.3))
      end
    else
      timers.edge = 0
    end
  end

  -- Pickups -------------------------------------------------------------
  if hud.sonar_pickups then
    local nearest = cache.pickups[1]
    if nearest and nearest.d < 170 then
      timers.pickup = timers.pickup - dt
      if timers.pickup <= 0 then
        timers.pickup = remap(nearest.d, 20, 170, 0.45, 0.95)
        access.audio.play(nearest.kind, math.sin(nearest.b),
          remap(nearest.d, 16, 170, 1.35, 0.8), 0.8)
      end
    end
  end
end


-- ---------------------------------------------------------- announcements --

local function party_health(a)
  local hp, max = 0, 0
  local p = a.player
  if not p or not p.get_all_units then return nil end
  for _, u in ipairs(p:get_all_units()) do
    if not u.dead then
      hp = hp + math.max(0, u.hp or 0)
      max = max + (u.max_hp or 0)
    end
  end
  if max <= 0 then return nil end
  return hp / max
end


local HEALTH_STEPS = {0.75, 0.5, 0.25, 0.1}

local function watch_announcements(dt)
  local a = arena()
  if not a then return end

  -- Countdown before the first wave.
  if a.start_time and a.start_time ~= watched.start_time then
    if watched.start_time and a.start_time > 0 then
      access.say(tostring(a.start_time), {interrupt = true, priority = true})
    elseif watched.start_time and a.start_time <= 0 then
      access.say('go', {interrupt = true, priority = true})
    end
    watched.start_time = a.start_time
  end

  -- Wave progress.
  if a.wave and a.wave ~= watched.wave then
    watched.wave = a.wave
    if a.wave > 0 and a.max_waves and a.wave <= a.max_waves then
      access.say('wave ' .. a.wave .. ' of ' .. a.max_waves, {interrupt = false})
    end
  end

  -- Party health thresholds. Only ever spoken on the way down, and only once
  -- per threshold, so a long fight does not turn into a monologue.
  local frac = party_health(a)
  if frac then
    if watched.health == nil then watched.health = frac end
    for _, step in ipairs(HEALTH_STEPS) do
      if watched.health > step and frac <= step then
        access.say('party health ' .. math.floor(step * 100) .. ' percent',
          {interrupt = false, priority = step <= 0.25})
      end
    end
    if frac > (watched.health or 0) + 0.15 then
      access.say('healed', {interrupt = false})
    end
    watched.health = frac
  end

  -- Units lost.
  local p = a.player
  if p and p.get_all_units then
    local n = #p:get_all_units()
    if watched.units and n < watched.units then
      access.audio.play('unit_down', 0, 1, 1)
      access.say(n .. (n == 1 and ' hero left' or ' heroes left'), {interrupt = false, priority = true})
    end
    watched.units = n
  end

  -- "Area clear" is only worth saying when nothing is coming straight back:
  -- clearing a wave normally spawns the next one in the same breath.
  local remaining = #cache.enemies
  if hud.announce_combat and watched.remaining and remaining == 0 and watched.remaining > 0 then
    local last_wave = a.max_waves and a.wave and a.wave >= a.max_waves
    if last_wave and not a.spawning_enemies then
      access.say('area clear', {interrupt = false})
    end
  end
  watched.remaining = remaining
end


function hud.update(dt)
  if not playable() then
    -- Keep the caches warm enough that an on-demand report still works while
    -- the game is paused, but stop making noise.
    return
  end
  update_sonar(dt)
  watch_announcements(dt)
end


-- ------------------------------------------------------------- hook points --

-- Called when enemies are about to appear somewhere. The marker is on screen
-- for just over a second, which is exactly the warning a sighted player gets.
function hud.on_spawn_marker(x, y)
  local a = arena()
  if not a then return end
  -- Markers keep resolving for a second or so after the run ends; nobody needs
  -- to hear about a spawn they are no longer alive for.
  if a.died or a.won or a.choosing_passives then return end
  access.audio.play('spawn', 0, 1, 0.9)
  local p = a.player
  if p and not p.dead then
    local b = relative_bearing(p, x, y)
    access.audio.play('spawn', math.sin(b), math.cos(b) > 0 and 1.15 or 0.8, 0.9)
  end
  -- Several markers often appear at once; collapse them into one sentence.
  hud._spawn_pending = hud._spawn_pending or {}
  table.insert(hud._spawn_pending, describe.position(x, y, a))
  if not hud._spawn_scheduled then
    hud._spawn_scheduled = true
    trigger:after(0.25, function()
      hud._spawn_scheduled = false
      local places = hud._spawn_pending or {}
      hud._spawn_pending = nil
      if #places == 0 then return end
      local unique, seen = {}, {}
      for _, s in ipairs(places) do
        if not seen[s] then seen[s] = true; table.insert(unique, s) end
      end
      access.say('enemies at the ' .. describe.list(unique), {interrupt = false})
    end, 'access_spawn_announce')
  end
end


-- Shooter elites and several bosses fire volleys, which are invisible to every
-- other cue here. Only shots actually travelling towards the snake are worth a
-- sound, and only a couple per volley, or a fan of eight becomes a chord.
function hud.on_enemy_projectile(p)
  local player, a = head()
  if not player or not a then return end
  if not playable() then return end

  local now = love.timer.getTime()
  if hud._last_incoming and (now - hud._last_incoming) < 0.18 then return end

  local dx, dy = p.x - player.x, p.y - player.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d > 220 then return end

  local towards_player = math.atan2(-dy, -dx)
  if math.abs(describe.wrap_angle((p.r or 0) - towards_player)) > math.pi / 5 then return end

  hud._last_incoming = now
  local b = describe.wrap_angle(math.atan2(dy, dx) - player.r)
  access.audio.play('incoming', math.sin(b), remap(d, 20, 220, 1.5, 0.85), 0.9)
end


function hud.on_arena_enter(a)
  hud.reset()
  watched.wave = a.wave
  watched.start_time = a.start_time
  local parts = {'Round ' .. tostring(a.level)}
  if a.boss_level then
    local boss = level_to_boss and level_to_boss[a.level]
    table.insert(parts, 'elite round' .. (boss and (', ' .. describe.title(boss)) or ''))
  elseif a.max_waves then
    table.insert(parts, describe.count(a.max_waves, 'wave'))
  end
  table.insert(parts, describe.count(#(a.units or {}), 'hero', 'heroes'))
  access.say(table.concat(parts, ', ') .. '. Get ready.', {interrupt = true})
end


function hud.on_die(a)
  access.say('You died on round ' .. tostring(a.level) ..
    '. Press R to restart, or escape for the menu.', {interrupt = true, priority = true})
end


function hud.on_clear(a)
  access.say('Arena clear. Round ' .. tostring(a.level) .. ' complete.', {interrupt = true})
end


-- ---------------------------------------------------------------- reports --

function hud.report_status()
  local a = arena()
  if not a then
    -- Outside the arena the same key answers the same question: where am I in
    -- the run, and what can I afford.
    local st = main and main.current
    if st and st.is and st:is(BuyScreen) then
      access.say('Shop, round ' .. tostring(st.level) .. ', ' .. tostring(gold) .. ' gold, party ' ..
        tostring(#(st.units or {})) .. ' of ' .. tostring(max_units) ..
        ', shop level ' .. tostring(st.shop_level), {interrupt = true})
    else
      access.say('main menu', {interrupt = true})
    end
    return
  end
  local parts = {'Round ' .. tostring(a.level)}
  if a.start_time and a.start_time > 0 then
    table.insert(parts, 'starting in ' .. a.start_time)
  elseif a.boss_level then
    table.insert(parts, a.boss and not a.boss.dead and 'elite alive' or 'elite down')
  elseif a.wave and a.max_waves then
    table.insert(parts, 'wave ' .. math.max(1, math.min(a.wave, a.max_waves)) .. ' of ' .. a.max_waves)
  end
  table.insert(parts, describe.count(#cache.enemies, 'enemy', 'enemies'))
  local frac = party_health(a)
  if frac then table.insert(parts, 'party health ' .. math.floor(frac * 100 + 0.5) .. ' percent') end
  table.insert(parts, tostring(gold) .. ' gold')
  access.say(table.concat(parts, ', '), {interrupt = true})
end


function hud.report_position()
  local p, a = head()
  if not p then
    access.say('no snake to locate', {interrupt = true})
    return
  end
  local parts = {}
  table.insert(parts, 'You are in the ' .. describe.position(p.x, p.y, a))
  table.insert(parts, 'heading ' .. describe.compass(p.r))
  local ahead = wall_ahead(p, a)
  if ahead then table.insert(parts, 'wall ahead in ' .. describe.steps(ahead) .. ' steps') end
  local wall = nearest_wall(p, a)
  if wall.d < 40 then
    table.insert(parts, wall.name .. ' ' .. describe.side(describe.wrap_angle(wall.r - p.r)))
  end
  access.say(table.concat(parts, ', '), {interrupt = true})
end


function hud.report_enemies()
  local p, a = head()
  if not p then
    access.say('not in the arena', {interrupt = true})
    return
  end
  if #cache.enemies == 0 then
    access.say('no enemies', {interrupt = true})
    return
  end
  local parts = {#cache.enemies .. (#cache.enemies == 1 and ' enemy' or ' enemies')}
  -- A quadrant census first: it is what tells you which way to turn.
  local sectors = {ahead = 0, right = 0, behind = 0, left = 0}
  for _, e in ipairs(cache.enemies) do
    local b, ab = e.b, math.abs(e.b)
    if ab < math.pi / 4 then sectors.ahead = sectors.ahead + 1
    elseif ab > 3 * math.pi / 4 then sectors.behind = sectors.behind + 1
    elseif b > 0 then sectors.right = sectors.right + 1
    else sectors.left = sectors.left + 1 end
  end
  local census = {}
  for _, key in ipairs({'ahead', 'right', 'behind', 'left'}) do
    if sectors[key] > 0 then table.insert(census, sectors[key] .. ' ' .. key) end
  end
  table.insert(parts, describe.list(census))
  local n = cache.enemies[1]
  table.insert(parts, 'nearest ' .. describe.distance(n.d) .. ' at ' .. describe.clock(n.b))
  if a.boss and not a.boss.dead then
    local b = relative_bearing(p, a.boss.x, a.boss.y)
    local d = math.sqrt((a.boss.x - p.x) ^ 2 + (a.boss.y - p.y) ^ 2)
    table.insert(parts, 'elite ' .. describe.distance(d) .. ' at ' .. describe.clock(b))
  end
  access.say(table.concat(parts, '. '), {interrupt = true})
end


function hud.report_pickups()
  local p = head()
  if not p then
    access.say('not in the arena', {interrupt = true})
    return
  end
  if #cache.pickups == 0 then
    access.say('nothing to pick up', {interrupt = true})
    return
  end
  local gold_n, orb_n = 0, 0
  for _, g in ipairs(cache.pickups) do
    if g.kind == 'gold' then gold_n = gold_n + 1 else orb_n = orb_n + 1 end
  end
  local parts = {}
  if gold_n > 0 then table.insert(parts, gold_n .. ' gold') end
  if orb_n > 0 then table.insert(parts, orb_n .. ' healing ' .. (orb_n == 1 and 'orb' or 'orbs')) end
  local n = cache.pickups[1]
  table.insert(parts, 'nearest is ' .. (n.kind == 'gold' and 'gold' or 'a healing orb') ..
    ', ' .. describe.distance(n.d) .. ' at ' .. describe.clock(n.b))
  access.say(table.concat(parts, ', '), {interrupt = true})
end


function hud.report_party()
  local a = arena()
  local p = a and a.player
  if not p or not p.get_all_units then
    -- In the shop there is no live health to report, so read the roster in
    -- party order instead; slot 1 is the head and takes the hits.
    local st = main and main.current
    local units = st and st.units
    if units and #units > 0 then
      local parts = {}
      for i, u in ipairs(units) do
        table.insert(parts, i .. ', ' .. describe.character(u.character, u.level))
      end
      access.say('Party: ' .. table.concat(parts, '. '), {interrupt = true})
    else
      access.say('no party yet', {interrupt = true})
    end
    return
  end
  local parts = {}
  for _, u in ipairs(p:get_all_units()) do
    if not u.dead then
      local pct = (u.max_hp and u.max_hp > 0) and math.floor((u.hp / u.max_hp) * 100 + 0.5) or 0
      table.insert(parts, describe.character(u.character, u.level) .. ', ' .. pct .. ' percent')
    end
  end
  if #parts == 0 then
    access.say('no heroes left', {interrupt = true})
  else
    access.say(table.concat(parts, '. '), {interrupt = true})
  end
end


-- Build summary: works in the arena and in the shop, because "what am I
-- actually playing" is a question that comes up in both.
function hud.report_build()
  local st = main and main.current
  local units = st and st.units
  if not units or #units == 0 then
    access.say('no heroes yet', {interrupt = true})
    return
  end
  local parts = {}
  local names = {}
  for _, u in ipairs(units) do
    table.insert(names, describe.character(u.character, u.level))
  end
  table.insert(parts, describe.count(#units, 'hero', 'heroes') .. ': ' .. table.concat(names, ', '))

  if get_class_levels then
    local ok, levels = pcall(get_class_levels, units)
    if ok and levels then
      local active = {}
      for class, level in pairs(levels) do
        if level and level > 0 then
          table.insert(active, (class == 'conjurer' and 'builder' or describe.title(class)) .. ' ' .. level)
        end
      end
      table.sort(active)
      if #active > 0 then table.insert(parts, 'class bonuses: ' .. table.concat(active, ', ')) end
    end
  end

  local passives = st.passives
  if passives and #passives > 0 then
    local items = {}
    for _, item in ipairs(passives) do
      table.insert(items, (passive_names and passive_names[item.passive] or describe.title(item.passive)) ..
        ' level ' .. tostring(item.level))
    end
    table.insert(parts, describe.count(#items, 'item') .. ': ' .. table.concat(items, ', '))
  end

  access.say(table.concat(parts, '. '), {interrupt = true})
end
