-- KL OS / HackOS 2.2.0: intentionally exposed, read-only legacy diagnostic service.
-- This creates a Minecraft-only exploit-lab mechanic. It does NOT provide a shell,
-- arbitrary command execution, or unrestricted filesystem access.
local V = {}
V.PROTOCOL = "klos_legacy_diag_v1"
local CONFIG = "/hackos/legacy-security.json"
local net = require("os.network")
local sessions = {}

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

function V.patch()
  return writeConfig({ exposed = false })
end

function V.unpatch()
  return writeConfig({ exposed = true })
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
    version = "2.3.0",
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
  if msg.kind == "PROBE" then
    if not cfg.exposed then
      send(id, { kind = "OFFER", patched = true, computer = os.getComputerID(), hostname = net.getHostname(), ip = net.getIP() })
      return
    end
    send(id, {
      kind = "OFFER", vulnerable = true, computer = os.getComputerID(),
      hostname = net.getHostname(), ip = net.getIP(), service = "KL OS Legacy Diagnostics",
      edition = getEdition(), version = "2.3.0", access = "READ-ONLY",
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
