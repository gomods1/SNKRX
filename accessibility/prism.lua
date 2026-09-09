-- Speech output for SNKRX, built on the Prism screen reader / TTS library.
--
-- Prism ships as a C shared library; LOVE runs on LuaJIT so we bind it through
-- the FFI. When a screen reader (NVDA, JAWS, VoiceOver, Orca...) is running
-- Prism routes speech through it, which is what a blind player expects: their
-- own voice, their own rate, their own punctuation settings. When no screen
-- reader is present it falls back to the platform's TTS engine (SAPI/OneCore
-- on Windows, AVSpeech on macOS, speech-dispatcher on Linux).
--
-- Every entry point here is failure tolerant: if the library can't be loaded
-- the game must still run normally, just without speech.

local ffi = require('ffi')

local tts = {}
access.tts = tts

tts.available = false
tts.backend_name = nil
tts.error = nil

-- Feature bits from prism.h (PrismBackendFeature).
local FEATURE = {
  SPEAK       = 4,      -- 1 << 2
  BRAILLE     = 16,     -- 1 << 4
  OUTPUT      = 32,     -- 1 << 5, speak + braille in one call
  IS_SPEAKING = 64,     -- 1 << 6
  STOP        = 128,    -- 1 << 7
  SET_VOLUME  = 1024,   -- 1 << 10
  SET_RATE    = 4096,   -- 1 << 12
  SET_PITCH   = 16384,  -- 1 << 14
}

pcall(ffi.cdef, [[
typedef struct PrismContext PrismContext;
typedef struct PrismBackend PrismBackend;
typedef struct PrismRegistry PrismRegistry;
typedef uint64_t PrismBackendId;
typedef void (__cdecl *PrismAvailabilityCallback)(void *userdata, PrismBackendId backend, const char *name, bool available);
typedef struct {
  uint8_t version;
  PrismRegistry *registry;
  PrismAvailabilityCallback availability_callback;
  void *availability_userdata;
  uint32_t availability_poll_interval_ms;
  uint32_t availability_debounce_samples;
  uint32_t availability_backoff_max_ms;
  bool availability_auto_power_manage;
} PrismConfig;
PrismConfig  __cdecl prism_config_init(void);
PrismContext * __cdecl prism_init(PrismConfig *cfg);
void         __cdecl prism_shutdown(PrismContext *ctx);
size_t       __cdecl prism_registry_count(PrismContext *ctx);
PrismBackendId __cdecl prism_registry_id_at(PrismContext *ctx, size_t index);
const char * __cdecl prism_registry_name(PrismContext *ctx, PrismBackendId id);
PrismBackend * __cdecl prism_registry_acquire_best(PrismContext *ctx);
PrismBackend * __cdecl prism_registry_acquire(PrismContext *ctx, PrismBackendId id);
const char * __cdecl prism_backend_name(PrismBackend *backend);
uint64_t     __cdecl prism_backend_get_features(PrismBackend *backend);
int          __cdecl prism_backend_initialize(PrismBackend *backend);
int          __cdecl prism_backend_speak(PrismBackend *backend, const char *text, bool interrupt);
int          __cdecl prism_backend_output(PrismBackend *backend, const char *text, bool interrupt);
int          __cdecl prism_backend_braille(PrismBackend *backend, const char *text);
int          __cdecl prism_backend_stop(PrismBackend *backend);
int          __cdecl prism_backend_is_speaking(PrismBackend *backend, bool *out_speaking);
int          __cdecl prism_backend_set_rate(PrismBackend *backend, float rate);
int          __cdecl prism_backend_set_volume(PrismBackend *backend, float volume);
const char * __cdecl prism_error_string(int error);
const char * __cdecl prism_version_string(void);
]])

local lib, ctx, backend, features


local function library_names()
  local os_name = love.system.getOS()
  if os_name == 'Windows' then return {'prism.dll'}
  elseif os_name == 'OS X' then return {'libprism.dylib', 'prism.dylib'}
  else return {'libprism.so', 'prism.so'} end
end


-- Search next to the game before falling back to the system loader path, so a
-- copied game folder works without the player installing anything.
local function candidate_paths()
  local dirs = {}
  local ok, src = pcall(love.filesystem.getSource)
  if ok and src then table.insert(dirs, src) end
  local ok2, base = pcall(love.filesystem.getSourceBaseDirectory)
  if ok2 and base then table.insert(dirs, base) end

  local paths = {}
  for _, dir in ipairs(dirs) do
    for _, name in ipairs(library_names()) do
      table.insert(paths, dir .. '/lib/' .. name)
      table.insert(paths, dir .. '/' .. name)
    end
  end
  table.insert(paths, 'prism')  -- whatever the OS loader can find
  return paths
end


local function try_load()
  local last_err
  for _, path in ipairs(candidate_paths()) do
    local ok, result = pcall(ffi.load, path)
    if ok then return result end
    last_err = tostring(result)
  end
  return nil, last_err
end


function tts.init()
  local loaded, err = try_load()
  if not loaded then
    tts.error = 'could not load the prism library: ' .. tostring(err)
    return false
  end
  lib = loaded

  local ok, res = pcall(function()
    local cfg = lib.prism_config_init()
    return lib.prism_init(cfg)
  end)
  if not ok or res == nil then
    tts.error = 'prism_init failed: ' .. tostring(res)
    return false
  end
  ctx = res

  local ok2, b = pcall(lib.prism_registry_acquire_best, ctx)
  if not ok2 or b == nil then
    tts.error = 'no speech backend is available on this system'
    return false
  end
  backend = b

  -- PRISM_ERROR_ALREADY_INITIALIZED (15) is expected for shared backends.
  local err_code = lib.prism_backend_initialize(backend)
  if err_code ~= 0 and err_code ~= 15 then
    tts.error = 'backend init failed: ' .. ffi.string(lib.prism_error_string(err_code))
    backend = nil
    return false
  end

  features = tonumber(lib.prism_backend_get_features(backend)) or 0
  tts.backend_name = ffi.string(lib.prism_backend_name(backend))
  tts.version = ffi.string(lib.prism_version_string())
  tts.available = true
  return true
end


local function has(feature)
  if not features then return false end
  return math.floor(features / feature) % 2 == 1
end


function tts.list_backends()
  if not ctx then return {} end
  local out = {}
  local ok = pcall(function()
    local n = tonumber(lib.prism_registry_count(ctx))
    for i = 0, n - 1 do
      local id = lib.prism_registry_id_at(ctx, i)
      table.insert(out, ffi.string(lib.prism_registry_name(ctx, id)))
    end
  end)
  if not ok then return {} end
  return out
end


-- Speak a line of text. interrupt = true cuts off whatever is being said,
-- which is what you want for anything the player just asked for; queued speech
-- is for detail that follows a label.
function tts.speak(text, interrupt)
  if not tts.available or not backend then return false end
  if not text or text == '' then return false end
  local ok, err_code = pcall(function()
    -- 'output' hits both speech and a connected braille display in one call.
    if has(FEATURE.OUTPUT) then
      return lib.prism_backend_output(backend, text, interrupt and true or false)
    else
      return lib.prism_backend_speak(backend, text, interrupt and true or false)
    end
  end)
  return ok and err_code == 0
end


function tts.stop()
  if not tts.available or not backend then return end
  if not has(FEATURE.STOP) then return end
  pcall(lib.prism_backend_stop, backend)
end


function tts.is_speaking()
  if not tts.available or not backend then return false end
  if not has(FEATURE.IS_SPEAKING) then return false end
  local out = ffi.new('bool[1]')
  local ok, err_code = pcall(lib.prism_backend_is_speaking, backend, out)
  if not ok or err_code ~= 0 then return false end
  return out[0]
end


-- Only some backends let us touch rate/volume. Screen readers deliberately
-- don't, because the user already configured them, so failure here is normal.
function tts.set_rate(rate)
  if not tts.available or not backend or not has(FEATURE.SET_RATE) then return false end
  local ok, err_code = pcall(lib.prism_backend_set_rate, backend, rate)
  return ok and err_code == 0
end


function tts.set_volume(volume)
  if not tts.available or not backend or not has(FEATURE.SET_VOLUME) then return false end
  local ok, err_code = pcall(lib.prism_backend_set_volume, backend, volume)
  return ok and err_code == 0
end


function tts.shutdown()
  if not lib then return end
  pcall(function()
    if backend then lib.prism_backend_stop(backend) end
    if ctx then lib.prism_shutdown(ctx) end
  end)
  backend, ctx = nil, nil
  tts.available = false
end
