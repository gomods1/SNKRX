-- The base GameObject class.  
-- The general way of creating an object that implements these functions goes like this:
--[[
MyGameObject = Object:extend()
MyGameObject:implement(GameObject)
function MyGameObject:init(args)
  self:init_game_object(args)
end

function MyGameObject:update(dt)
  self:update_game_object(dt)
end
]]--

-- This simply implements the GameObject class as a mixin into your own class, giving it the functions defined in this file as well as the attributes set from init_game_object.
-- In general you'd create your own game object like this, for instance:
-- group = Group()
-- MyGameObject{group = group, x = 100, y = 100, v = 100, r = math.pi/4}
-- And then this object would be automatically updated and drawn by the group.
-- Alternatively you could add the object to the group manually:
-- my_object = MyGameObject{x = 100, y = 100, v = 100, r = math.pi/4}
-- group:add(my_object)
-- One of the nice patterns I've found was a passing arguments as a key + value table.
-- So in the case above, the object would automatically have its .x, .y and .v attributes set to 100 and its .r attribute set to math.pi/4.
GameObject = Object:extend()
function GameObject:init_game_object(args)
  for k, v in pairs(args or {}) do self[k] = v end
  if self.group then self.group:add(self) end
  self.x, self.y = self.x or 0, self.y or 0
  self.r = self.r or 0
  self.sx, self.sy = self.sx or 1, self.sy or 1
  self.id = self.id or random:uid()
  -- Which frame this object came into existence on; see GameObject:pressed.
  self.created_frame = frame
  self.t = Trigger()
  self.springs = Springs()
  self.flashes = Flashes()
  self.hfx = HitFX(self) 
  self.spring = Spring(1)
  return self
end


function GameObject:update_game_object(dt)
  self.t:update(dt)
  self.springs:update(dt)
  self.flashes:update(dt)
  self.hfx:update(dt)
  self.spring:update(dt)
  if self.body then self:update_physics(dt) end

  if self.shape then
    if self.shape.vertices and self.body then
      self.shape.vertices = {self.body:getWorldPoints(self.fixture:getShape():getPoints())}
      self.shape:get_centroid()
    end
    if self.body then
      self.shape:move_to(self:get_position())
    end

    if self.interact_with_mouse then
      local colliding_with_mouse = self.shape:is_colliding_with_point(self.group:get_mouse_position())
      if colliding_with_mouse and not self.colliding_with_mouse then
        self.colliding_with_mouse = true
        if self.on_mouse_enter then self:on_mouse_enter() end
      elseif not colliding_with_mouse and self.colliding_with_mouse then
        self.colliding_with_mouse = false
        if self.on_mouse_exit then self:on_mouse_exit() end
      end
      if self.colliding_with_mouse then
        if self.on_mouse_stay then self:on_mouse_stay() end
      end
    end
  end
end


-- Input is read once at the top of a frame and every flag it sets stays set for
-- the whole of it. A widget built midway through a frame -- by the very press
-- still being handled, when a panel tears itself down and lays itself out again
-- -- therefore arrives in a frame where that press still reads as new, and
-- lands under the cursor that made it. It fires the same action, which builds
-- another widget, which fires again: the frame never ends and the game hangs.
-- That is what pressing the options screen's language button used to do.
--
-- So anything that acts on a press asks the object rather than reading input
-- directly, and an object only ever answers presses that happened after it
-- existed. Objects live for many frames, so this costs a press only in the one
-- frame where acting on it was never right in the first place.
--
-- The same question answers a second one. The options panel is drawn over the
-- screen it was opened on, but on the shop it shares a group with that screen's
-- own buttons and they keep updating underneath it -- and the panel's top row
-- lands on the button that restarts the run. A click meant for the panel was
-- taken by both. While the panel is up it owns every press on the screen.
function GameObject:accepts_presses()
  if self.created_frame == frame then return false end
  local st = main and main.current
  if st and st.paused and not self.options_widget then return false end
  return true
end


function GameObject:pressed(action)
  local a = input[action]
  return (a and a.pressed and self:accepts_presses()) or false
end


function GameObject:draw_game_object()
  if self.body then self:draw_physics() end
end
