-- Protected KL OS / HackOS security core.
-- This file is intentionally excluded from normal OS updates. Update it only
-- from the Antivirus application through security/manifest.json.
local SECURITY_VERSION = "1.0.2"
local BASE_URL = "https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/"
local FEED_PATH = "security/manifest.json"
local SECURITY_PATH = "/security.lua"
local VERSION_PATH = "/hackos/security-version.cfg"
local STAGE_DIR = "/hackos/security-staging"
local BACKUP_DIR = "/hackos/security-backup"
local S = {}

local function versionParts(value)
  local parts = {}
  for n in tostring(value or "0"):gmatch("%d+") do parts[#parts + 1] = tonumber(n) or 0 end
  while #parts < 3 do parts[#parts + 1] = 0 end
  return parts
end

local function compareVersions(a, b)
  local aa, bb = versionParts(a), versionParts(b)
  for i = 1, math.max(#aa, #bb) do
    local x, y = aa[i] or 0, bb[i] or 0
    if x < y then return -1 elseif x > y then return 1 end
  end
  return 0
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  if not f then return nil end
  local value = f.readAll()
  f.close()
  return value
end

local function writeFile(path, body)
  local dir = fs.getDir(path)
  if dir ~= "" then fs.makeDir(dir) end
  local f, err = fs.open(path, "w")
  if not f then return false, err end
  local ok, why = pcall(function() f.write(body); f.close() end)
  if not ok then pcall(function() f.close() end); return false, why end
  return true
end

local function get(path)
  if not http or not http.get then return nil, "HTTP API is disabled" end
  local response, err = http.get(BASE_URL .. path)
  if not response then return nil, err end
  local body = response.readAll()
  response.close()
  return body
end

local function validSource(path)
  return type(path) == "string" and path:sub(1, 17) == "security/payload/" and
    not path:match("^/") and not path:find("..", 1, true) and not path:find("\\", 1, true)
end

function S.getVersion()
  local stored = readFile(VERSION_PATH)
  if stored then
    stored = stored:gsub("%s+$", "")
    if stored:match("^%d+%.%d+%.%d+$") then return stored end
  end
  return SECURITY_VERSION
end

function S.isProtected()
  return fs.exists(SECURITY_PATH)
end

function S.checkForUpdates()
  local raw, err = get(FEED_PATH)
  if not raw then return { ok = false, error = "Could not reach the security update service: " .. tostring(err) } end
  if #raw > 32768 then return { ok = false, error = "Security update manifest is too large." } end
  local feed = textutils.unserializeJSON(raw)
  if type(feed) ~= "table" or type(feed.files) ~= "table" or #feed.files ~= 1 then
    return { ok = false, error = "The security update manifest is invalid." }
  end
  if type(feed.version) ~= "string" or not feed.version:match("^%d+%.%d+%.%d+$") then
    return { ok = false, error = "The security update version is invalid." }
  end
  local item = feed.files[1]
  if type(item) ~= "table" or item.target ~= "security.lua" or not validSource(item.source) then
    return { ok = false, error = "The feed requested a file outside the protected security module." }
  end
  local current = S.getVersion()
  return {
    ok = true,
    current = current,
    latest = feed.version,
    available = compareVersions(feed.version, current) > 0,
    notes = tostring(feed.release_notes or "Security maintenance update."),
    source = item.source,
    feed = feed,
  }
end

local function restoreSecurityFile(hadOld, backupFile)
  if fs.exists(SECURITY_PATH) then fs.delete(SECURITY_PATH) end
  if hadOld then
    if not fs.exists(backupFile) then return false, "The previous security backup is missing." end
    local ok, err = pcall(fs.copy, backupFile, SECURITY_PATH)
    if not ok or not fs.exists(SECURITY_PATH) then
      return false, "Could not restore the previous security file: " .. tostring(err)
    end
  end
  return true
end

function S.installLatest()
  local status = S.checkForUpdates()
  if not status.ok then return false, status.error end
  if not status.available then return false, "No security update is available. You already have " .. status.current .. "." end

  local body, err = get(status.source)
  if not body then return false, "Could not download security patch: " .. tostring(err) end
  if #body == 0 or #body > 65536 then return false, "Security patch size is invalid." end
  local chunk, compileError = load(body, "@security.lua")
  if not chunk then return false, "Security patch failed Lua validation: " .. tostring(compileError) end

  fs.delete(STAGE_DIR)
  fs.makeDir(STAGE_DIR)
  local staged = STAGE_DIR .. "/security.lua"
  local stagedOK, stagedErr = writeFile(staged, body)
  if not stagedOK then return false, "Could not stage security patch: " .. tostring(stagedErr) end

  fs.delete(BACKUP_DIR)
  fs.makeDir(BACKUP_DIR)
  local backupFile = BACKUP_DIR .. "/security.lua"
  local hadOld = fs.exists(SECURITY_PATH)
  if hadOld then
    local backupOK, backupErr = pcall(fs.copy, SECURITY_PATH, backupFile)
    if not backupOK or not fs.exists(backupFile) then
      fs.delete(STAGE_DIR)
      return false, "Could not back up the current security core: " .. tostring(backupErr)
    end
  end

  local previousVersion = S.getVersion()
  -- CC:Tweaked fs.copy refuses to overwrite an existing destination. Remove the
  -- live file only after the backup is verified, then move the staged file in.
  if fs.exists(SECURITY_PATH) then fs.delete(SECURITY_PATH) end
  local installOK, installErr = pcall(fs.move, staged, SECURITY_PATH)
  if not installOK or not fs.exists(SECURITY_PATH) then
    local restored, restoreErr = restoreSecurityFile(hadOld, backupFile)
    fs.delete(STAGE_DIR)
    return false, "Could not install security patch: " .. tostring(installErr) ..
      (restored and " Previous security core restored." or " " .. tostring(restoreErr))
  end

  local versionOK, versionErr = writeFile(VERSION_PATH, status.latest .. "\n")
  if not versionOK then
    local restored, restoreErr = restoreSecurityFile(hadOld, backupFile)
    writeFile(VERSION_PATH, previousVersion .. "\n")
    fs.delete(STAGE_DIR)
    return false, "Could not save security version: " .. tostring(versionErr) ..
      (restored and " Previous security core restored." or " " .. tostring(restoreErr))
  end

  -- Refresh the recovery copy so a later repair restores the patched security core.
  local indexPath = "/hackos/recovery/index.json"
  local index = { paths = {} }
  local indexRaw = readFile(indexPath)
  if indexRaw then
    local parsed = textutils.unserializeJSON(indexRaw)
    if type(parsed) == "table" and type(parsed.paths) == "table" then index = parsed end
  end
  local recoveryFile = "/hackos/recovery/files/security.lua"
  local recoveryOK = writeFile(recoveryFile, body)
  local found = false
  for _, path in ipairs(index.paths) do if path == "security.lua" then found = true; break end end
  if not found then index.paths[#index.paths + 1] = "security.lua" end
  if recoveryOK then writeFile(indexPath, textutils.serialiseJSON(index)) end

  fs.delete(STAGE_DIR)
  return true, status.latest
end

return S
