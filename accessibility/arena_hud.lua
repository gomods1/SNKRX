-- Situational awareness inside the arena.
--
-- The arena is the part of SNKRX that cannot be solved with speech alone. The
-- snake never stops moving, enemies converge from every side, and the only
-- control is "turn left" or "turn right". A player needs a continuous sense of
-- where the threats are, not a sentence about them two seconds later.
--
-- So this module runs a set of continuous sonars -- enemies, the elite, walls,
-- pickups -- plus spoken announcements for the moments that matter (a wave, a
-- hero lost, a headbutter charging, a mine) and a set of on-demand reports for
-- the things that are better said than sung: wave progress, party health,
-- build composition.
--
-- The enemy, elite and pickup sonars are *beacons*: one tone per target that
-- holds for as long as the target is there, panning and rising as the snake
-- moves relative to it. Walls keep their knocking pings, because a wall is not
-- something you steer towards and a held tone for one would never stop.

local hud = {}
access.hud = hud

local describe = access.describe

hud.sonar_enemies = true
hud.sonar_walls = true
hud.sonar_pickups = true
hud.announce_combat = true
-- Continuous tones for the things worth steering towards or away from, rather
-- than pings that only say where something was when the timer last came round.
hud.beacons = true

local timers = {enemy = 0, wall = 0, edge = 0, pickup = 0, scan = 0, boss = 0, pinch = 0, shot = 0}
local cache = {enemies = {}, pickups = {}}
local watched = {}
-- Mines burning down, and the delayed second half of a special enemy's ping.
-- Both are declared up here with the rest of the state rather than beside the
-- code that fills them, because hud.reset has to be able to empty them and it
-- is defined next.
local mines = {}
local pending = {}
local shots = {}
local cue_last = {}


function hud.reset()
  timers = {enemy = 0, wall = 0, edge = 0, pickup = 0, scan = 0, boss = 0, pinch = 0, shot = 0}
  cache = {enemies = {}, pickups = {}}
  watched = {elite = {}, seen = {}, low = {}}
  mines = {}
  pending = {}
  shots = {}
  cue_last = {}
  hud._spawn_pending, hud._spawn_scheduled, hud._spawn_boss = nil, nil, nil
  hud._arrivals, hud._arrivals_scheduled = nil, nil
  hud._last_bounce, hud._last_boss_attack = nil, nil
  if access.audio.stop_beacons then access.audio.stop_beacons() end
end
hud.reset()


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
  if a.lesson_result then return false end
  if slow_amount and slow_amount < 0.2 then return false end
  return true
end


-- Bearing of a point relative to where the snake is pointing: 0 is dead ahead,
-- positive is to the player's right.
local function relative_bearing(p, x, y)
  return describe.wrap_angle(math.atan2(y - p.y, x - p.x) - p.r)
end


local function range_and_bearing(p, o)
  local dx, dy = o.x - p.x, o.y - p.y
  return math.sqrt(dx * dx + dy * dy), describe.wrap_angle(math.atan2(dy, dx) - p.r)
end


-- One cue for one thing that happened, however many times the game says it.
--
-- The abilities down at the hook points are all drawn once per target rather
-- than once per action: a dying speed booster throws a line at every enemy in
-- range, the forcer throws one per escort, and a swarmer's critters arrive
-- twice over -- once as the elite's attack and again as five separate
-- critters. So the limiter is keyed on the cue rather than on the caller, and
-- the callers collapse against each other as well as against themselves.
local function cue_once(name, bearing, volume, gap)
  local now = love.timer.getTime()
  if cue_last[name] and (now - cue_last[name]) < (gap or 0.5) then return end
  cue_last[name] = now
  access.audio.play(name, math.sin(bearing), 1, volume or 1)
end


-- ------------------------------------------------------------------ sonar --

local function scan_enemies(p, a)
  local list = {}
  local objects = a.main:get_objects_by_classes(a.enemies)
  for _, e in ipairs(objects) do
    if not e.dead then
      local d, b = range_and_bearing(p, e)
      -- What kind it is, carried along with where it is, because every sonar
      -- decision below is now made per kind and working it out again for each
      -- of them would mean walking the same field tests three times a frame.
      table.insert(list, {o = e, d = d, b = b, kind = describe.enemy_key(e)})
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
          local d, b = range_and_bearing(p, g)
          table.insert(list, {o = g, d = d, b = b, kind = (class_name == 'Gold') and 'gold' or 'orb'})
        end
      end
    end
  end
  table.sort(list, function(l, r) return l.d < r.d end)
  return list
end


-- The separate-pings mode that B switches back to has no held tone to carry a
-- timbre, and its pitch and its rate are both spoken for by distance. What is
-- left is rhythm: a plain seeker stays the single ping it always was, and each
-- special follows it with one echo at a spacing of its own. Even unparsed, two
-- taps instead of one already says "not an ordinary enemy", which is the half
-- of the message that has to arrive inside a second.
local PING_TAG = {
  critter       = 0.05,
  speed_booster = 0.09,
  exploder      = 0.14,
  shooter       = 0.20,
  headbutter    = 0.27,
  tank          = 0.36,
  spawner       = 0.46,
}


-- The tap itself waits in `pending`, drained by update_sonar. A table rather
-- than a trigger:after so that a queued tap dies with the arena instead of
-- firing into the shop screen behind it.
local function ping_enemy(e, volume)
  local pan = math.sin(e.b)
  local front = math.cos(e.b) > 0
  local pitch = remap(e.d, 16, 240, 1.9, 0.6)
  local name = front and 'enemy_front' or 'enemy_back'
  -- Contact range: the snake takes damage from touching an enemy, so the last
  -- few pixels get their own unmistakable sound.
  if e.d < 26 then name = 'enemy_close' end
  access.audio.play(name, pan, pitch, volume or 1)
  local gap = e.kind and PING_TAG[e.kind]
  if gap and name ~= 'enemy_close' then
    table.insert(pending, {t = gap, name = name, pan = pan, pitch = pitch * 1.06,
      volume = (volume or 1) * 0.8})
  end
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
    {d = p.x - a.x1, r = math.pi,     name = 'a11y.wall.left'},
    {d = a.x2 - p.x, r = 0,           name = 'a11y.wall.right'},
    {d = p.y - a.y1, r = -math.pi/2,  name = 'a11y.wall.top'},
    {d = a.y2 - p.y, r = math.pi/2,   name = 'a11y.wall.bottom'},
  }
  local best = candidates[1]
  for _, c in ipairs(candidates) do if c.d < best.d then best = c end end
  return best
end


-- Each beacon's two loops, bright for ahead and dull for behind; the pair is
-- crossfaded by bearing inside access.audio.beacon.
local ENEMY_BEACON = {ahead = 'enemy_ahead', behind = 'enemy_behind'}
local ELITE_BEACON = {ahead = 'elite_ahead', behind = 'elite_behind'}
local GOLD_BEACON  = {ahead = 'gold_ahead',  behind = 'gold_behind'}
local ORB_BEACON   = {ahead = 'orb_ahead',   behind = 'orb_behind'}

-- ...and one pair per kind of enemy, so that the tone which is playing almost
-- continuously says what it is tracking and not merely where it is. Without
-- this the loudest thing in a fight is the same sound whether the thing
-- closing on you is a tank you can ignore or a headbutter about to remove a
-- hero, which is most of why the twelve tutorial runs all sounded alike.
local KIND_BEACON = {
  enemy         = ENEMY_BEACON,
  shooter       = {ahead = 'shooter_ahead',       behind = 'shooter_behind'},
  headbutter    = {ahead = 'headbutter_ahead',    behind = 'headbutter_behind'},
  tank          = {ahead = 'tank_ahead',          behind = 'tank_behind'},
  exploder      = {ahead = 'exploder_ahead',      behind = 'exploder_behind'},
  speed_booster = {ahead = 'speed_booster_ahead', behind = 'speed_booster_behind'},
  spawner       = {ahead = 'spawner_ahead',       behind = 'spawner_behind'},
  critter       = {ahead = 'critter_ahead',       behind = 'critter_behind'},
}


-- The enemy closing from the other side of the snake, if there is one. Being
-- pinched between two of them is the situation that kills runs.
local function pinching(nearest)
  for i = 2, math.min(#cache.enemies, 6) do
    local other = cache.enemies[i]
    if other.d < nearest.d * 1.8 and (other.b * nearest.b) < 0 and
       math.abs(describe.wrap_angle(other.b - nearest.b)) > math.pi / 3 then
      return other
    end
  end
  return nil
end


-- Which enemy the beacon is following.
--
-- "Whichever is nearest" was fine while every enemy sounded the same; now that
-- the beacon changes voice with the kind of thing it has hold of, two enemies
-- trading places a few pixels apart would swap the tone back and forth several
-- times a second, which is unlistenable and churns a Source each time. So the
-- one it has is kept until it dies or something gets a clear fifth closer.
local function tracked_enemy()
  -- The elite is never the enemy this tone follows. It has a beacon of its
  -- own, and at the start of every elite round it is the only enemy there is,
  -- so following it here as well played a plain seeker on top of the elite
  -- tone: the same direction twice, in two voices, until the escorts arrived.
  local nearest
  for _, e in ipairs(cache.enemies) do
    if not e.o.boss then nearest = e break end
  end
  if not nearest then
    watched.tracked_id = nil
    return nil
  end
  if watched.tracked_id and watched.tracked_id ~= nearest.o.id then
    for _, e in ipairs(cache.enemies) do
      if e.o.id == watched.tracked_id then
        if e.d <= nearest.d * 1.2 then return e end
        break
      end
    end
  end
  watched.tracked_id = nearest.o.id
  return nearest
end


local function sonar_enemies(dt, p, a)
  local nearest = tracked_enemy()

  if hud.beacons then
    -- One continuous tone for the nearest enemy. It never stops while there is
    -- something to track, so turning away from it is something you can hear
    -- happening rather than something you infer from the next ping.
    if nearest then
      access.audio.beacon('enemy', KIND_BEACON[nearest.kind] or ENEMY_BEACON, nearest.b,
        remap(nearest.d, 16, 260, 1.75, 0.70),
        remap(nearest.d, 16, 260, 0.90, 0.36))

      -- The second enemy keeps its ping rather than getting a beacon of its
      -- own: one held tone is a thing to steer by, two are a chord.
      timers.pinch = timers.pinch - dt
      if timers.pinch <= 0 then
        local other = pinching(nearest)
        if other then
          timers.pinch = 0.5
          ping_enemy(other, 0.5)
        end
      end
    end

    -- Contact keeps its own hard rattle over the top: the beacon says where
    -- something is, this says that it is on you now. Keyed to whatever is
    -- actually nearest, elite included -- the elite is the one thing the
    -- beacon above does not follow, and it hurts the most to touch.
    local contact = cache.enemies[1]
    timers.enemy = timers.enemy - dt
    if contact and contact.d < 26 and timers.enemy <= 0 then
      timers.enemy = 0.14
      access.audio.play('enemy_close', math.sin(contact.b), 1, 0.9)
    end

  else
    timers.enemy = timers.enemy - dt
    if nearest and timers.enemy <= 0 then
      timers.enemy = remap(nearest.d, 20, 220, 0.10, 0.70)
      ping_enemy(nearest, 1)
      local other = pinching(nearest)
      if other then ping_enemy(other, 0.55) end
    end
  end

  -- The elite gets a voice of its own. It is the one enemy that has to be
  -- killed to end the round, and the swarm around it hides it completely from
  -- the nearest-enemy tone.
  local boss = a.boss
  if boss and not boss.dead then
    local d, b = range_and_bearing(p, boss)
    if hud.beacons then
      access.audio.beacon('elite', ELITE_BEACON, b,
        remap(d, 30, 280, 1.35, 0.75),
        remap(d, 30, 280, 0.95, 0.50))
    else
      timers.boss = timers.boss - dt
      if timers.boss <= 0 then
        timers.boss = remap(d, 30, 250, 0.45, 1.2)
        local front = math.cos(b) > 0
        access.audio.play('boss', math.sin(b), front and remap(d, 20, 250, 1.3, 0.9) or remap(d, 20, 250, 0.85, 0.6), 1)
      end
    end
  end
end


local function sonar_walls(dt, p, a)
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

  -- Running along a wall is safe but disorienting; a quiet pad on the side the
  -- wall is on keeps the player oriented without nagging.
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


local function sonar_pickups(dt)
  if hud.beacons then
    -- Gold and orbs get a beacon each rather than taking turns as the nearest
    -- one: an orb is worth crossing the arena for and gold is worth a detour,
    -- and which of the two is momentarily closer says nothing about that.
    -- The cache is sorted by range, so the first of each kind is its nearest.
    local gold, orb
    for _, g in ipairs(cache.pickups) do
      if g.kind == 'gold' then gold = gold or g else orb = orb or g end
      if gold and orb then break end
    end
    if gold then
      access.audio.beacon('gold', GOLD_BEACON, gold.b,
        remap(gold.d, 16, 300, 1.30, 0.80),
        remap(gold.d, 16, 300, 0.85, 0.30))
    end
    if orb then
      access.audio.beacon('orb', ORB_BEACON, orb.b,
        remap(orb.d, 16, 300, 1.25, 0.80),
        remap(orb.d, 16, 300, 0.95, 0.35))
    end

  else
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


-- Mines on the ground, and how long each has been burning.
--
-- A mine used to get one tick as it was laid and a sentence, and then nothing
-- at all for the two and a half seconds it spent counting down -- which is
-- precisely the information a sighted player is being given in that time, by
-- watching it blink faster. So it ticks the whole way down, accelerating and
-- rising, and its own position is read afresh every tick: a mine does not
-- move, but the snake does, and a fuse that stays where you last heard it is
-- a fuse you steer into.
--
-- Ungated by the enemy-sonar toggle on purpose. F is for the swarm, and
-- silencing the swarm should not silence the one hazard in the game that kills
-- you for standing still.


local function fuse_length()
  -- The game's own countdown: a beat to grow, then three ticks and the ring.
  return 0.05 + 3 * math.max(0.3, 0.8 - (current_new_game_plus or 0) * 0.1)
end


local function sonar_mines(dt, p)
  for i = #mines, 1, -1 do
    local m = mines[i]
    m.t = m.t + dt
    if m.o.dead then
      -- Eight shots leave in every direction at once, so this is not a warning
      -- to steer by: it is the loudest thing the layer plays, and it means the
      -- next second belongs to whoever is furthest from where it went off.
      local d, b = range_and_bearing(p, m.o)
      access.audio.play('burst', math.sin(b), 1, remap(d, 20, 280, 1, 0.40))
      table.remove(mines, i)
    elseif m.t > m.fuse + 2 then
      -- It never reported going off. Rather than tick for ever, let it go.
      table.remove(mines, i)
    else
      m.tick = m.tick - dt
      if m.tick <= 0 then
        local u = clamp(m.t / m.fuse, 0, 1)
        m.tick = remap(u, 0, 1, 0.40, 0.10)
        local d, b = range_and_bearing(p, m.o)
        access.audio.play('mine', math.sin(b), remap(u, 0, 1, 0.85, 1.7),
          remap(d, 20, 280, 1, 0.35))
      end
    end
  end
end


-- Enemy shots in the air.
--
-- These used to get a single buzz at the moment they were fired, and only if
-- they were fired from inside 220 pixels -- which in an arena 437 pixels
-- across meant a shooter working from the far corner was silent, and a shot
-- that was going to arrive in a second and a half announced itself once, a
-- second and a half early, and then said nothing while it crossed.
--
-- So a shot is tracked instead, and buzzes as it closes, faster and higher the
-- nearer it gets, in exactly the shape the wall knock uses. Only the nearest
-- shot actually converging on the snake is ever sounded: eight of them leaving
-- a mine at once is one voice getting closer, not a chord.
local function sonar_shots(dt, p)
  local nearest, near_d
  for i = #shots, 1, -1 do
    local s = shots[i]
    s.t = s.t + dt
    if s.o.dead or s.t > 8 then
      table.remove(shots, i)
    else
      local dx, dy = s.o.x - p.x, s.o.y - p.y
      local d = math.sqrt(dx * dx + dy * dy)
      -- Converging, not merely nearby: a shot that has already gone past is a
      -- shot that no longer needs steering around, and half of a fan never
      -- comes anywhere near you.
      local towards = math.atan2(-dy, -dx)
      if d < 210 and math.abs(describe.wrap_angle((s.o.r or 0) - towards)) < math.pi / 5 then
        if not near_d or d < near_d then nearest, near_d = s, d end
      end
    end
  end

  if not nearest then
    timers.shot = 0
    return
  end
  timers.shot = timers.shot - dt
  if timers.shot <= 0 then
    timers.shot = remap(near_d, 20, 210, 0.09, 0.30)
    local b = describe.wrap_angle(math.atan2(nearest.o.y - p.y, nearest.o.x - p.x) - p.r)
    access.audio.play('incoming', math.sin(b), remap(near_d, 20, 210, 1.5, 0.85),
      remap(near_d, 20, 210, 1, 0.55))
  end
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

  -- The second tap of a special enemy's ping, once its gap has elapsed.
  for i = #pending, 1, -1 do
    local tap = pending[i]
    tap.t = tap.t - dt
    if tap.t <= 0 then
      access.audio.play(tap.name, tap.pan, tap.pitch, tap.volume)
      table.remove(pending, i)
    end
  end

  sonar_mines(dt, p)
  sonar_shots(dt, p)
  if hud.sonar_enemies then sonar_enemies(dt, p, a) end
  if hud.sonar_walls then sonar_walls(dt, p, a) end
  if hud.sonar_pickups then sonar_pickups(dt) end
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
local BOSS_STEPS = {0.75, 0.5, 0.25}


-- Which heroes are alive, by id, so that a loss can be named.
local function remember_party(a)
  local p = a.player
  if not p or not p.get_all_units then return end
  local ids = {}
  for _, u in ipairs(p:get_all_units()) do ids[u.id] = describe.character(u.character) end
  watched.unit_ids = ids
  watched.leader_id = p.id
end


local function watch_party(a)
  local p = a.player
  if not p or not p.get_all_units then return end
  local units = p:get_all_units()

  -- Heroes lost, by name. The game only shows this as a tile going grey.
  local seen = {}
  for _, u in ipairs(units) do seen[u.id] = true end
  if watched.unit_ids then
    local lost = {}
    for id, name in pairs(watched.unit_ids) do
      if not seen[id] then table.insert(lost, name) end
    end
    if #lost > 0 then
      access.audio.play('unit_down', 0, 1, 1)
      local n = #units
      access.say(T(#lost == 1 and 'a11y.party.one_down' or 'a11y.party.several_down',
        describe.list(lost), loc.count(n, 'a11y.heroes_left')), {interrupt = false, priority = true})
      -- The party total is now over fewer heroes, so it jumps; start the
      -- health thresholds afresh rather than reporting that as a heal.
      watched.health = nil
    end
  end
  local ids = {}
  for _, u in ipairs(units) do ids[u.id] = describe.character(u.character) end
  watched.unit_ids = ids

  -- When the head dies the next hero in line takes over the steering, and
  -- with it the hits.
  if watched.leader_id and p.id ~= watched.leader_id then
    access.say(T('a11y.party.new_head', describe.character(p.character)), {interrupt = false, priority = true})
  end
  watched.leader_id = p.id

  -- One hero running low is worth a word even when the party as a whole is
  -- healthy: it is usually the head, and it is about to become a loss.
  for _, u in ipairs(units) do
    if not u.dead and u.max_hp and u.max_hp > 0 then
      local f = u.hp / u.max_hp
      if f <= 0.25 and not watched.low[u.id] then
        watched.low[u.id] = true
        access.say(T('a11y.party.low', describe.character(u.character), math.floor(f * 100 + 0.5)),
          {interrupt = false})
      elseif f > 0.4 and watched.low[u.id] then
        watched.low[u.id] = nil
      end
    end
  end
end


-- Special enemies are told apart on screen by colour, and each one changes
-- how the fight should be played. Say what has turned up, and warn when a
-- headbutter is winding up or a shooter has stopped to take aim.
local function watch_enemies(a)
  local newcomers = {}
  for _, e in ipairs(cache.enemies) do
    local o = e.o
    if not watched.seen[o.id] then
      watched.seen[o.id] = true
      if not o.boss then
        local k = describe.enemy_key(o)
        if k ~= 'enemy' and k ~= 'critter' then newcomers[k] = (newcomers[k] or 0) + 1 end
      end
    end

    if o.headbutter then
      local state = (o.headbutting and 'butt') or (o.headbutt_charging and 'charge') or 'idle'
      if watched.elite[o.id] ~= state then
        watched.elite[o.id] = state
        if state == 'charge' then
          -- Two seconds of wind-up, then the charge. The two used to be the
          -- same cue at two pitches, which meant the moment worth reacting to
          -- sounded like the warning repeated slightly higher.
          access.audio.play('charge', math.sin(e.b), 1, 1)
          access.say(T('a11y.arena.headbutter_charging', describe.distance(e.d), describe.clock(e.b)), {interrupt = false})
        elseif state == 'butt' then
          access.audio.play('butt', math.sin(e.b), 1, 1)
          access.say(T('a11y.arena.headbutt_from', describe.side(e.b)), {interrupt = true, priority = true})
        end
      end
    elseif o.shooter then
      local state = o.shooting and 'shooting' or 'idle'
      if watched.elite[o.id] ~= state then
        watched.elite[o.id] = state
        if state == 'shooting' then
          -- A shooter stopping to aim is the one warning that arrives before
          -- the shots rather than with them, and it was the only special
          -- enemy's telegraph with no sound on it at all.
          access.audio.play('aim', math.sin(e.b), 1, 1)
          access.say(T('a11y.arena.shooter_aiming', describe.distance(e.d), describe.clock(e.b)), {interrupt = false})
        end
      end
    end
  end

  -- Several usually arrive in the same burst; collapse them into one line.
  if next(newcomers) then
    hud._arrivals = hud._arrivals or {}
    for k, n in pairs(newcomers) do hud._arrivals[k] = (hud._arrivals[k] or 0) + n end
    if not hud._arrivals_scheduled then
      hud._arrivals_scheduled = true
      trigger:after(0.5, function()
        pcall(function()
          hud._arrivals_scheduled = false
          local arrivals = hud._arrivals or {}
          hud._arrivals = nil
          local parts = {}
          for k, n in pairs(arrivals) do table.insert(parts, describe.count(n, 'a11y.enemy.' .. k)) end
          table.sort(parts)
          if #parts > 0 then access.say(T('a11y.arena.arriving', describe.list(parts)), {interrupt = false}) end
        end)
      end, 'access_arrivals')
    end
  end
end


local function watch_boss(a)
  local boss = a.boss
  if not boss then return end
  if not watched.boss_seen then
    watched.boss_seen = true
    access.say(T('a11y.arena.elite_here', describe.boss_name(boss.boss)), {interrupt = false, priority = true})
  end
  if boss.dead then
    if not watched.boss_dead then
      watched.boss_dead = true
      access.say(T('a11y.arena.elite_down'), {interrupt = false, priority = true})
    end
    return
  end
  if boss.max_hp and boss.max_hp > 0 then
    local f = boss.hp / boss.max_hp
    if watched.boss_hp == nil then watched.boss_hp = f end
    for _, step in ipairs(BOSS_STEPS) do
      if watched.boss_hp > step and f <= step then
        access.say(T('a11y.arena.elite_at', math.floor(step * 100)), {interrupt = false})
      end
    end
    watched.boss_hp = f
  end
end


local function watch_announcements(dt)
  local a = arena()
  if not a then return end

  -- Countdown before the first wave.
  if a.start_time and a.start_time ~= watched.start_time then
    if watched.start_time and a.start_time > 0 then
      access.say(tostring(a.start_time), {interrupt = true, priority = true})
    elseif watched.start_time and a.start_time <= 0 then
      access.say(T('a11y.arena.go'), {interrupt = true, priority = true})
    end
    watched.start_time = a.start_time
  end

  -- Wave progress.
  if a.wave and a.wave ~= watched.wave then
    watched.wave = a.wave
    if a.wave > 0 and a.max_waves and a.wave <= a.max_waves then
      access.say(T('a11y.arena.wave', a.wave, a.max_waves), {interrupt = false})
    end
  end

  if hud.announce_combat then watch_party(a) end

  -- Party health thresholds. Only ever spoken on the way down, and only once
  -- per threshold, so a long fight does not turn into a monologue.
  local frac = party_health(a)
  if frac then
    if watched.health == nil then watched.health = frac end
    for _, step in ipairs(HEALTH_STEPS) do
      if watched.health > step and frac <= step then
        access.say(T('a11y.arena.party_health', math.floor(step * 100)),
          {interrupt = false, priority = step <= 0.25})
      end
    end
    if frac > (watched.health or 0) + 0.15 then
      access.say(T('a11y.arena.healed'), {interrupt = false})
    end
    watched.health = frac
  end

  if hud.announce_combat then
    watch_enemies(a)
    watch_boss(a)
  end
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
  -- Markers keep resolving for a second or so after the round ends; nobody
  -- needs to hear about a spawn they are no longer fighting.
  if a.died or a.won or a.quitting or a.choosing_passives then return end
  access.audio.play('spawn', 0, 1, 0.9)
  local p = a.player
  if p and not p.dead then
    local b = relative_bearing(p, x, y)
    access.audio.play('spawn', math.sin(b), math.cos(b) > 0 and 1.15 or 0.8, 0.9)
  end
  -- The first marker of an elite round is the elite itself.
  if a.boss_level and not a.boss and not watched.boss_marker then
    watched.boss_marker = true
    hud._spawn_boss = true
  end
  -- Several markers often appear at once; collapse them into one sentence.
  hud._spawn_pending = hud._spawn_pending or {}
  table.insert(hud._spawn_pending, describe.position(x, y, a))
  if not hud._spawn_scheduled then
    hud._spawn_scheduled = true
    trigger:after(0.25, function()
      pcall(function()
        hud._spawn_scheduled = false
        local places = hud._spawn_pending or {}
        local boss = hud._spawn_boss
        hud._spawn_pending, hud._spawn_boss = nil, nil
        if #places == 0 then return end
        local unique, seen = {}, {}
        for _, s in ipairs(places) do
          if not seen[s] then seen[s] = true; table.insert(unique, s) end
        end
        access.say(T(boss and 'a11y.arena.elite_arriving_at' or 'a11y.arena.enemies_at', describe.list(unique)), {interrupt = false})
      end)
    end, 'access_spawn_announce')
  end
end


-- Shooters, the exploder's mines and several of the bosses all fire volleys,
-- and every one of them arrives here. The hook only writes the shot down; what
-- it sounds like on the way in is sonar_shots' business, and putting it there
-- rather than here is what lets a shot be heard closing rather than only being
-- announced as it leaves.
function hud.on_enemy_projectile(p)
  local player = head()
  if not player or not playable() then return end
  table.insert(shots, {o = p, t = 0})
end


-- An exploder has died and left a mine that will burst into a ring of shots
-- in about two seconds. On screen it is a small blinking dot, blinking faster
-- as it runs down; sonar_mines is where that becomes a fuse you can hear.
function hud.on_mine(m)
  local p, a = head()
  if not p or not a or not playable() then return end
  local d, b = range_and_bearing(p, m)
  access.audio.play('mine', math.sin(b), 0.85, 1)
  table.insert(mines, {o = m, t = 0, tick = 0.4, fuse = fuse_length()})
  access.say(T('a11y.arena.mine', describe.distance(d), describe.clock(b)), {interrupt = false})
end


-- Every elite attack, and the two abilities an ordinary enemy has, are drawn
-- as lightning from the thing doing it to the thing it is done to. Each now
-- gets a cue as well as a sentence: speech says what happened, and it arrives
-- a beat late and can be queued behind two other lines, whereas the cue is
-- immediate and is what tells you the fight just changed shape.
local BOSS_ATTACKS = {
  speed_booster = {text = 'a11y.arena.elite_speeds_allies',  cue = 'boost'},
  forcer        = {text = 'a11y.arena.elite_flings_enemies', cue = 'shove'},
  swarmer       = {text = 'a11y.arena.elite_bursts_ally',    cue = 'swarm'},
}

-- The randomizer picks one of the other elites' attacks each time and says
-- which only by the colour of the lightning.
local RANDOMIZER_ATTACKS = {
  green  = BOSS_ATTACKS.speed_booster,
  yellow = BOSS_ATTACKS.forcer,
  purple = BOSS_ATTACKS.swarmer,
  blue   = {text = 'a11y.arena.elite_detonates_ally', cue = 'burst'},
}


function hud.on_boss_attack(boss, color, target)
  if not playable() then return end
  local now = love.timer.getTime()
  if hud._last_boss_attack and (now - hud._last_boss_attack) < 1 then return end
  hud._last_boss_attack = now
  local attack = BOSS_ATTACKS[boss.boss]
  if boss.boss == 'randomizer' then
    if color == green[0] then attack = RANDOMIZER_ATTACKS.green
    elseif color == yellow[0] then attack = RANDOMIZER_ATTACKS.yellow
    elseif color == purple[0] then attack = RANDOMIZER_ATTACKS.purple
    elseif color == blue[0] then attack = RANDOMIZER_ATTACKS.blue end
  end
  -- The exploder boss plants mines, and every mine already announces itself.
  if not attack then return end
  local p = head()
  if p and attack.cue then
    -- Panned to whatever the attack was aimed at rather than to the elite: a
    -- flung escort leaves from the elite but arrives from somewhere else, and
    -- where it arrives from is the half worth knowing.
    local _, b = range_and_bearing(p, target or boss)
    cue_once(attack.cue, b, 1)
  end
  access.say(T(attack.text), {interrupt = false})
end


-- A tank shoving the enemy next to it at you, or a speed booster handing its
-- speed to everything around it as it dies. Both are ordinary-enemy abilities
-- that changed the fight and made no sound at all: the tank's push is how a
-- seeker you had accounted for arrives twice as fast as it should, and the
-- booster's parting gift is the reason a swarm you were outrunning catches up.
function hud.on_enemy_ability(src, target)
  if not playable() then return end
  local p = head()
  if not p then return end
  -- A shove is panned to the enemy being thrown, because that is the thing
  -- that arrives; a boost is panned to the booster, because nothing arrives at
  -- all and where it happened is what tells you which half of the swarm just
  -- got faster.
  local kind = src.tank and 'shove' or 'boost'
  local _, b = range_and_bearing(p, (kind == 'shove' and target) or src)
  cue_once(kind, b, 0.85)
end


-- Critters, arriving in a cloud: a spawner dying, a swarmer elite bursting one
-- of its escorts, or an infested enemy coming apart. Five to eight of them
-- appear in the same frame, so this is one cue for the cloud.
function hud.on_critter(c)
  if not playable() then return end
  -- A critter spawned at a position that came out as NaN kills itself in its
  -- constructor, before it has a place to be panned to.
  if c.dead then return end
  local p = head()
  if not p then return end
  local _, b = range_and_bearing(p, c)
  cue_once('swarm', b, 0.9)
end


-- The snake has just bounced off a wall. A bounce turns you around in a way
-- that is impossible to feel, so the new heading is spoken.
function hud.on_wall_bounce(p)
  local a = arena()
  if not a or not playable() or not hud.sonar_walls then return end
  local now = love.timer.getTime()
  if hud._last_bounce and (now - hud._last_bounce) < 0.7 then return end
  hud._last_bounce = now
  access.say(T('a11y.arena.heading', describe.compass(p.r)), {interrupt = false})
end


function hud.on_arena_enter(a)
  hud.reset()
  watched.wave = a.wave
  watched.start_time = a.start_time
  remember_party(a)

  -- A tutorial run has no round number, no waves and no gold. What it has is
  -- one enemy, which has just been described at length on the screen before
  -- this one, so all that is worth saying here is which one and how many.
  if a.lesson then
    local n = 0
    for _, squad in ipairs(a.lesson.squads) do n = n + (squad.n or 1) end
    access.say(T('a11y.arena.lesson_start', tutorial.name(a.lesson), describe.count(n, 'a11y.enemy.enemy')),
      {interrupt = true})
    return
  end

  local total = 25 * ((a.loop or 0) + 1)
  local parts = {T('a11y.arena.round', a.level, total)}
  if a.boss_level then
    local boss = level_to_boss and level_to_boss[a.level]
    table.insert(parts, T('a11y.arena.elite_round', describe.boss_name(boss)))
  elseif a.max_waves then
    table.insert(parts, describe.count(a.max_waves, 'a11y.waves'))
  end
  table.insert(parts, describe.count(#(a.units or {}), 'a11y.heroes'))
  local level = a.level - 25 * (a.loop or 0)
  if level % 3 == 0 and a.level % 25 ~= 0 and #(a.passives or {}) < 8 then
    table.insert(parts, T('a11y.arena.item_after'))
  end
  access.say(table.concat(parts, ', ') .. '. ' .. T('a11y.arena.get_ready'), {interrupt = true})

  if a.level == 1 then
    access.say(T('a11y.arena.first_round_help'), {interrupt = false})
  end
end


function hud.on_die(a)
  -- Losing a tutorial run is not losing a run; hud.on_lesson_over has already
  -- said what it is.
  if a.lesson then return end
  access.say(T('a11y.arena.died', a.level), {interrupt = true, priority = true})
end


function hud.on_lesson_over(a, outcome)
  if outcome == 'passed' then
    local done = tutorial.completed_count()
    access.say(T('a11y.lesson.cleared', tutorial.name(a.lesson), done, #tutorial.lessons),
      {interrupt = true, priority = true})
  else
    access.say(T('a11y.lesson.failed', tutorial.name(a.lesson)), {interrupt = true, priority = true})
  end
end


function hud.on_clear(a)
  access.say(T('a11y.arena.clear', a.level), {interrupt = true})
end


-- ---------------------------------------------------------------- reports --

local function boss_line(p, a)
  local boss = a.boss
  if not boss or boss.dead then return nil end
  local d, b = range_and_bearing(p, boss)
  local pct = (boss.max_hp and boss.max_hp > 0) and math.floor((boss.hp / boss.max_hp) * 100 + 0.5) or 0
  return T('a11y.report.elite', pct, describe.distance(d), describe.clock(b))
end


function hud.report_status()
  local a = arena()
  if not a then
    -- Outside the arena the same key answers the same question: where am I in
    -- the run, and what can I afford.
    local st = main and main.current
    if st and st.is and st:is(BuyScreen) then
      local parts = {T('a11y.report.shop_round', st.level, 25 * ((st.loop or 0) + 1))}
      local kind = describe.round_type(st.level, st.loop)
      if kind then table.insert(parts, kind) end
      table.insert(parts, T('a11y.gold', gold))
      table.insert(parts, T('a11y.shop.party', #(st.units or {}), max_units))
      table.insert(parts, T('a11y.shop.level', st.shop_level))
      if st.locked then table.insert(parts, T('a11y.shop.locked')) end
      access.say(table.concat(parts, ', '), {interrupt = true})
    else
      access.say(T('a11y.report.main_menu'), {interrupt = true})
    end
    return
  end
  local parts = {a.lesson and T('a11y.report.lesson_run', tutorial.name(a.lesson))
    or T('a11y.arena.round', a.level, 25 * ((a.loop or 0) + 1))}
  if a.start_time and a.start_time > 0 then
    table.insert(parts, T('a11y.report.starting_in', a.start_time))
  elseif a.lesson then
    table.insert(parts, T('a11y.report.kill_everything'))
  elseif a.boss_level then
    table.insert(parts, a.boss and not a.boss.dead and T('a11y.report.elite_alive')
      or (a.boss and T('a11y.report.elite_dead') or T('a11y.report.elite_not_here')))
  elseif a.wave and a.max_waves then
    table.insert(parts, T('a11y.arena.wave', math.max(1, math.min(a.wave, a.max_waves)), a.max_waves))
  end
  table.insert(parts, describe.count(#cache.enemies, 'a11y.enemy.enemy'))
  local frac = party_health(a)
  if frac then table.insert(parts, T('a11y.arena.party_health', math.floor(frac * 100 + 0.5))) end
  -- A tutorial run pays nothing and costs nothing, so gold there is noise.
  if not a.lesson then
    table.insert(parts, T('a11y.gold', gold))
    if (a.gold_picked_up or 0) > 0 then table.insert(parts, T('a11y.report.picked_up', a.gold_picked_up)) end
  end
  access.say(table.concat(parts, ', '), {interrupt = true})
end


function hud.report_position()
  local p, a = head()
  if not p then
    access.say(T('a11y.report.no_snake'), {interrupt = true})
    return
  end
  local parts = {}
  table.insert(parts, T('a11y.report.you_are_in', describe.position(p.x, p.y, a)))
  table.insert(parts, T('a11y.arena.heading', describe.compass(p.r)))
  local ahead = wall_ahead(p, a)
  if ahead then table.insert(parts, T('a11y.report.wall_ahead', describe.steps(ahead))) end
  local wall = nearest_wall(p, a)
  if wall.d < 40 then
    table.insert(parts, T(wall.name) .. ' ' .. describe.side(describe.wrap_angle(wall.r - p.r)))
  end
  access.say(table.concat(parts, ', '), {interrupt = true})
end


function hud.report_enemies()
  local p, a = head()
  if not p then
    access.say(T('a11y.report.not_in_arena'), {interrupt = true})
    return
  end
  if #cache.enemies == 0 then
    access.say(T('a11y.report.no_enemies'), {interrupt = true})
    return
  end
  local parts = {describe.count(#cache.enemies, 'a11y.enemy.enemy')}
  -- A quadrant census first: it is what tells you which way to turn.
  local sectors = {ahead = 0, right = 0, behind = 0, left = 0}
  local kinds = {}
  for _, e in ipairs(cache.enemies) do
    local b, ab = e.b, math.abs(e.b)
    if ab < math.pi / 4 then sectors.ahead = sectors.ahead + 1
    elseif ab > 3 * math.pi / 4 then sectors.behind = sectors.behind + 1
    elseif b > 0 then sectors.right = sectors.right + 1
    else sectors.left = sectors.left + 1 end
    local k = describe.enemy_key(e.o)
    if k ~= 'enemy' and k ~= 'elite' then kinds[k] = (kinds[k] or 0) + 1 end
  end
  local census = {}
  for _, key in ipairs({'ahead', 'right', 'behind', 'left'}) do
    if sectors[key] > 0 then table.insert(census, T('a11y.sector.' .. key, sectors[key])) end
  end
  table.insert(parts, describe.list(census))
  local specials = {}
  for k, n in pairs(kinds) do table.insert(specials, describe.count(n, 'a11y.enemy.' .. k)) end
  table.sort(specials)
  if #specials > 0 then table.insert(parts, T('a11y.report.including', describe.list(specials))) end
  local n = cache.enemies[1]
  -- "the elite" rather than "an elite": there is only ever one.
  local nearest = n.o.boss and T('a11y.report.the_elite') or describe.enemy_kind(n.o)
  table.insert(parts, T('a11y.report.nearest_is', nearest, describe.distance(n.d), describe.clock(n.b)))
  local boss = boss_line(p, a)
  if boss then table.insert(parts, boss) end
  access.say(table.concat(parts, '. '), {interrupt = true})
end


function hud.report_pickups()
  local p = head()
  if not p then
    access.say(T('a11y.report.not_in_arena'), {interrupt = true})
    return
  end
  if #cache.pickups == 0 then
    access.say(T('a11y.report.nothing_to_pick_up'), {interrupt = true})
    return
  end
  local gold_n, orb_n = 0, 0
  for _, g in ipairs(cache.pickups) do
    if g.kind == 'gold' then gold_n = gold_n + 1 else orb_n = orb_n + 1 end
  end
  local parts = {}
  if gold_n > 0 then table.insert(parts, T('a11y.gold', gold_n)) end
  if orb_n > 0 then table.insert(parts, describe.count(orb_n, 'a11y.healing_orbs')) end
  local n = cache.pickups[1]
  table.insert(parts, T('a11y.report.nearest_pickup',
    n.kind == 'gold' and T('a11y.report.pickup_gold') or T('a11y.report.pickup_orb'),
    describe.distance(n.d), describe.clock(n.b)))
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
      parts[1] = T('a11y.report.party_head_first', parts[1])
      access.say_lines(parts, {interrupt = true})
    else
      access.say(T('a11y.report.no_party'), {interrupt = true})
    end
    return
  end
  local parts = {}
  for i, u in ipairs(p:get_all_units()) do
    if not u.dead then
      local pct = (u.max_hp and u.max_hp > 0) and math.floor((u.hp / u.max_hp) * 100 + 0.5) or 0
      table.insert(parts, T(i == 1 and 'a11y.report.hero_head_pct' or 'a11y.report.hero_pct',
        describe.character(u.character, u.level), pct))
    end
  end
  if #parts == 0 then
    access.say(T('a11y.report.no_heroes_left'), {interrupt = true})
  else
    access.say_lines(parts, {interrupt = true})
  end
end


-- Build summary: works in the arena and in the shop, because "what am I
-- actually playing" is a question that comes up in both.
function hud.report_build()
  local st = main and main.current
  local units = st and st.units
  if not units or #units == 0 then
    access.say(T('a11y.report.no_heroes_yet'), {interrupt = true})
    return
  end
  local parts = {}
  local names = {}
  for _, u in ipairs(units) do
    table.insert(names, describe.character(u.character, u.level))
  end
  table.insert(parts, describe.count(#units, 'a11y.heroes') .. ': ' .. table.concat(names, ', '))

  if get_class_levels then
    local ok, levels = pcall(get_class_levels, units)
    if ok and levels then
      local active = {}
      for class, level in pairs(levels) do
        if level and level > 0 then
          table.insert(active, describe.class_name(class) .. ' ' .. level)
        end
      end
      table.sort(active)
      if #active > 0 then table.insert(parts, T('a11y.report.class_bonuses', table.concat(active, ', '))) end
    end
  end

  local passives = st.passives
  if passives and #passives > 0 then
    local items = {}
    for _, item in ipairs(passives) do
      table.insert(items, T('a11y.name_level', describe.passive_name(item.passive), item.level))
    end
    table.insert(parts, describe.count(#items, 'a11y.items') .. ': ' .. table.concat(items, ', '))
  end

  -- Heroes, class bonuses and items are one line each in the review buffer.
  access.say_lines(parts, {interrupt = true})
end
