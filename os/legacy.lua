-- KL OS / HackOS 2.4.0: diagnostics plus a scoped, destructive Minecraft exploit-lab service.
-- This creates a Minecraft-only exploit-lab mechanic. It does NOT provide a shell,
-- arbitrary command execution, or unrestricted filesystem access.
local V = {}
V.PROTOCOL = "klos_legacy_diag_v1"
local CONFIG = "/hackos/legacy-security.json"
local net = require("os.network")
local recovery = require("os.recovery")
local privacy = require("os.privacy")
local sessions = {}
local systemSessions = {}

local function readConfig()
  fs.makeDir("/hackos")
  local cfg = { exposed = true }
  if fs.exists(CONFIG) then
    local f = fs.open(CONFIG, "r")
    if f then
      local raw = f.readAll(); f.close()
      local saved = textutils.unserializeJSON(raw)
      if type(saved) == "table" then cfg.exposed = saved.exposed == true end
    end
  end
  return cfg
end

local function writeConfig(cfg)
  fs.makeDir("/hackos")
  local f, err = fs.open(CONFIG, "w")
  if not f then return false, err end
  f.write(textutils.serialiseJSON(cfg)); f.close()
  return true
end

function V.getStatus()
  return readConfig().exposed
end

function V.revokeLabSessions()
  sessions, systemSessions = {}, {}
  return true
end

function V.patch()
  local ok, err = writeConfig({ exposed = false })
  if ok then
    sessions, systemSessions = {}, {}
    privacy.log("GUEST_DIAGNOSTICS_PATCHED", "Read-only guest diagnostics and active lab sessions disabled")
  end
  return ok, err
end

function V.unpatch()
  local ok, err = writeConfig({ exposed = true })
  if ok then privacy.log("GUEST_DIAGNOSTICS_EXPOSED", "Read-only legacy diagnostics enabled for lab use") end
  return ok, err
end

local function getEdition()
  if fs.exists("/hackos/edition.cfg") then
    local f = fs.open("/hackos/edition.cfg", "r")
    if f then
      local value = f.readAll(); f.close()
      if value == "government" then return "HackOS Government" end
    end
  end
  return "KL OS Standard"
end

local function getInfo()
  local free = "unknown"
  if fs.getFreeSpace then
    local ok, value = pcall(fs.getFreeSpace, "/")
    if ok then free = tostring(value) end
  end
  local remoteEnabled = false
  local ok, remote = pcall(require, "os.remote")
  if ok and remote and remote.getStatus then
    local statusOK, enabled = pcall(remote.getStatus)
    if statusOK then remoteEnabled = enabled == true end
  end
  return {
    os = getEdition(),
    version = "2.4.0",
    hostname = net.getHostname(),
    ip = net.getIP(),
    computer = os.getComputerID(),
    uptime = math.floor(os.clock()),
    freeSpace = free,
    remoteAccessEnabled = remoteEnabled,
    access = "READ-ONLY GUEST DIAGNOSTICS",
  }
end

local function safePublicPath(name)
  if type(name) ~= "string" or #name < 1 or #name > 80 then return nil end
  if name:sub(1, 1) == "/" or name:find("..", 1, true) or name:find("\\", 1, true) or name:find(":", 1, true) then
    return nil
  end
  return fs.combine("/public", name)
end

local function listPublic()
  fs.makeDir("/public")
  local ok, entries = pcall(fs.list, "/public")
  if not ok then return false, "Could not list the public directory." end
  table.sort(entries)
  return true, entries
end

local function readPublic(name)
  local path = safePublicPath(name)
  if not path then return false, "Invalid public filename." end
  if not fs.exists(path) then return false, "File not found in /public." end
  if fs.isDir(path) then return false, "That entry is a directory." end
  local size = fs.getSize(path)
  if size > 4096 then return false, "Public file is larger than the 4096-byte guest limit." end
  local f, err = fs.open(path, "r")
  if not f then return false, tostring(err or "Could not open public file.") end
  local data = f.readAll(); f.close()
  return true, data
end

local function tokenFor(id)
  local seed = (math.floor(os.clock() * 100000) + id * 7919 + os.getComputerID() * 104729) % 2147483647
  return string.format("%08x%04x", seed, (id * 31 + os.getComputerID()) % 65536)
end

local function send(id, payload)
  if rednet and rednet.isOpen() then rednet.send(id, payload, V.PROTOCOL) end
end

local function handle(id, msg)
  if type(msg) ~= "table" then return end
  local cfg = readConfig()
  if msg.kind == "SYSTEM_PROBE" then
    -- Deliberate in-game vulnerability: only KL OS Standard answers. This ignores
    -- the normal Remote Access and Security Center toggles by design.
    if getEdition() == "KL OS Standard" and privacy.get("exploit_lab") then
      send(id, { kind = "SYSTEM_OFFER", vulnerable = true, computer = os.getComputerID(), hostname = net.getHostname(), ip = net.getIP(), edition = "KL OS Standard", attack = "KLOS-BOOT-OVERWRITE" })
    elseif getEdition() == "KL OS Standard" then
      privacy.log("LAB_PROBE_BLOCKED", "System exploit probe blocked by local privacy setting")
    end
  elseif msg.kind == "SYSTEM_EXPLOIT" then
    privacy.log("LAB_EXPLOIT_ATTEMPT", "Government lab exploit requested by computer #" .. tostring(id))
    if not privacy.get("exploit_lab") then
      send(id, { kind = "SYSTEM_SESSION", ok = false, error = "The KL OS exploit lab is disabled in Security & Privacy." })
      return
    end
    if getEdition() ~= "KL OS Standard" then
      send(id, { kind = "SYSTEM_SESSION", ok = false, error = "This exploit lab targets KL OS Standard only." })
      return
    end
    local token = tokenFor(id)
    systemSessions[id] = { token = token, expires = os.clock() + 120 }
    send(id, { kind = "SYSTEM_SESSION", ok = true, token = token, message = "KL OS Standard boot-file weakness reproduced. You can remove one system file; the target will blue-screen and can repair from its recovery image." })
  elseif msg.kind == "SYSTEM_LIST" then
    local session = systemSessions[id]
    if not privacy.get("exploit_lab") or getEdition() ~= "KL OS Standard" or not session or session.expires < os.clock() or msg.token ~= session.token then
      systemSessions[id] = nil
      send(id, { kind = "SYSTEM_LIST_RESULT", ok = false, error = "Exploit session expired or unsupported target." })
      return
    end
    local present = {}
    local indexFile = fs.open("/hackos/recovery/index.json", "r")
    if indexFile then
      local indexData = textutils.unserializeJSON(indexFile.readAll()); indexFile.close()
      if type(indexData) == "table" and type(indexData.paths) == "table" then
        for _, path in ipairs(indexData.paths) do
          if recovery.isSystemPath(path) and fs.exists(path) and not fs.isDir(path) then present[#present + 1] = path end
        end
      end
    end
    table.sort(present)
    send(id, { kind = "SYSTEM_LIST_RESULT", ok = true, files = present })
  elseif msg.kind == "SYSTEM_DELETE" then
    local session = systemSessions[id]
    if not privacy.get("exploit_lab") or getEdition() ~= "KL OS Standard" or not session or session.expires < os.clock() or msg.token ~= session.token then
      systemSessions[id] = nil
      send(id, { kind = "SYSTEM_DELETE_RESULT", ok = false, error = "Exploit session expired or unsupported target." })
      return
    end
    local path = tostring(msg.path or "")
    if not recovery.isSystemPath(path) or not fs.exists(path) or fs.isDir(path) then
      send(id, { kind = "SYSTEM_DELETE_RESULT", ok = false, error = "Invalid system-file selection." })
      return
    end
    send(id, { kind = "SYSTEM_DELETE_RESULT", ok = true, path = path, message = "System file removed. Target is entering recovery mode." })
    sleep(0.2)
    privacy.log("LAB_SYSTEM_FILE_DELETE", "System file selected for removal: " .. path .. " by computer #" .. tostring(id))
    local removed, why = recovery.remoteDelete(path, id)
    if removed then error("HACKOS_BSOD: SYSTEM FILE REMOVED BY HACKOS GOVERNMENT: " .. path, 0) end
    send(id, { kind = "SYSTEM_DELETE_RESULT", ok = false, error = tostring(why) })
  elseif msg.kind == "PROBE" then
    if not cfg.exposed then
      send(id, { kind = "OFFER", patched = true, computer = os.getComputerID(), hostname = net.getHostname(), ip = net.getIP() })
      return
    end
    send(id, {
      kind = "OFFER", vulnerable = true, computer = os.getComputerID(),
      hostname = net.getHostname(), ip = net.getIP(), service = "KL OS Legacy Diagnostics",
      edition = getEdition(), version = "2.4.0", access = "READ-ONLY",
    })
  elseif msg.kind == "EXPLOIT" then
    if not cfg.exposed then
      send(id, { kind = "SESSION", ok = false, error = "The legacy diagnostic service is patched on this computer." })
      return
    end
    local token = tokenFor(id)
    sessions[id] = { token = token, expires = os.clock() + 90 }
    send(id, {
      kind = "SESSION", ok = true, token = token,
      message = "Legacy diagnostic weakness reproduced. Guest access is read-only and limited to system diagnostics and /public.",
    })
  elseif msg.kind == "QUERY" then
    local session = sessions[id]
    if not cfg.exposed or not session or session.expires < os.clock() or msg.token ~= session.token then
      sessions[id] = nil
      send(id, { kind = "RESULT", ok = false, error = "Guest session expired or target is patched. Run Scan and Exploit again." })
      return
    end

    if msg.action == "INFO" then
      send(id, { kind = "RESULT", ok = true, data = getInfo() })
    elseif msg.action == "LIST_PUBLIC" then
      local ok, data = listPublic()
      send(id, { kind = "RESULT", ok = ok, data = data, error = (not ok) and data or nil })
    elseif msg.action == "READ_PUBLIC" then
      local ok, data = readPublic(msg.name)
      send(id, { kind = "RESULT", ok = ok, data = data, error = (not ok) and data or nil })
    elseif msg.action == "DISCONNECT" then
      sessions[id] = nil
      send(id, { kind = "RESULT", ok = true, data = "Guest session closed." })
    else
      send(id, { kind = "RESULT", ok = false, error = "Action not available in read-only guest mode. Arbitrary shell commands are not exposed." })
    end
  end
end

function V.run()
  fs.makeDir("/public")
  while true do
    local opened = net.open()
    if opened then
      local event, a, b, protocol = os.pullEvent()
      if event == "rednet_message" and protocol == V.PROTOCOL and a ~= os.getComputerID() then
        handle(a, b)
      end
    else
      os.sleep(4)
    end
  end
end

return V
