-- HackOS logical IPv4-style addressing over CC: Tweaked rednet.
-- IP addresses identify CC computers; packets are still transported by rednet.
local N = {}
N.PROTOCOL = "hackos_net"
N.WEB_PROTOCOL = "hackos_web"
N.LEGACY_WEB_PROTOCOL = "ccweb"
local CONFIG = "/hackos/network.cfg"

local function defaultIP(id)
  -- Deterministic private-style address derived from the CC computer ID.
  id = tonumber(id) or 1
  local offset = id - 1
  local a = math.floor(offset / 65025) % 254
  local b = math.floor(offset / 255) % 255
  local c = offset % 255 + 1
  return string.format("10.%d.%d.%d", a, b, c)
end

local function validIP(ip)
  if type(ip) ~= "string" then return false end
  local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then return false end
  for _, n in ipairs({ tonumber(a), tonumber(b), tonumber(c), tonumber(d) }) do
    if not n or n < 0 or n > 255 then return false end
  end
  return true
end

local function readConfig()
  fs.makeDir("/hackos")
  local cfg = { ip = defaultIP(os.getComputerID()), hostname = "computer-" .. os.getComputerID() }
  if fs.exists(CONFIG) then
    local f = fs.open(CONFIG, "r")
    if f then
      local raw = f.readAll(); f.close()
      local saved = textutils.unserializeJSON(raw)
      if type(saved) == "table" then
        if validIP(saved.ip) then cfg.ip = saved.ip end
        if type(saved.hostname) == "string" and saved.hostname:match("^[%w%-%.]+$") then cfg.hostname = saved.hostname end
      end
    end
  end
  return cfg
end

local config = readConfig()
N.config = config

function N.open()
  if not rednet then return false, "Rednet API is unavailable." end
  if not peripheral or not peripheral.getNames or not peripheral.getType then
    return false, "Peripheral API is unavailable."
  end
  local found = false
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "modem" then
      found = true
      pcall(rednet.open, side)
    end
  end
  if not found or not rednet.isOpen() then
    return false, "No modem is open. Connect a wired, wireless, or Ender modem."
  end
  return true
end

function N.save()
  fs.makeDir("/hackos")
  local f, err = fs.open(CONFIG, "w")
  if not f then return false, err end
  f.write(textutils.serialiseJSON(config))
  f.close()
  return true
end

function N.setConfig(ip, hostname)
  if not validIP(ip) then return false, "Invalid IPv4 address." end
  hostname = tostring(hostname or ""):lower()
  if #hostname < 1 or #hostname > 32 or not hostname:match("^[%w%-%.]+$") then
    return false, "Hostname must be 1-32 letters, numbers, dots, or hyphens."
  end
  config.ip, config.hostname = ip, hostname
  return N.save()
end

function N.getIP() return config.ip end
function N.getHostname() return config.hostname end

function N.discover(timeout)
  local ok, err = N.open()
  if not ok then return nil, err end
  timeout = tonumber(timeout) or 1.5
  rednet.broadcast({ kind = "DISCOVER", version = 1 }, N.PROTOCOL)
  local peers, seen = {}, {}
  local deadline = os.clock() + timeout
  while true do
    local left = deadline - os.clock()
    if left <= 0 then break end
    local id, msg = rednet.receive(N.PROTOCOL, left)
    if not id then break end
    if type(msg) == "table" and msg.kind == "OFFER" and id ~= os.getComputerID() and validIP(msg.ip) then
      local peer = seen[id]
      if not peer then
        peer = { id = id, ip = msg.ip, hostname = tostring(msg.hostname or ("computer-" .. id)), services = {} }
        seen[id] = peer
        peers[#peers + 1] = peer
      end
      peer.ip = msg.ip
      peer.hostname = tostring(msg.hostname or peer.hostname or ("computer-" .. id))
      if type(msg.mailAddress) == "string" then peer.mailAddress = msg.mailAddress end
      local services = msg.services or { "HackOS node" }
      for _, service in ipairs(services) do
        local exists = false
        for _, current in ipairs(peer.services) do
          if current == service then exists = true; break end
        end
        if not exists then peer.services[#peer.services + 1] = service end
      end
    end
  end
  table.sort(peers, function(a, b) return a.ip < b.ip end)
  return peers
end

function N.findPeer(address, peers)
  address = tostring(address or ""):lower()
  if not peers then peers = N.discover(1.5) or {} end
  for _, peer in ipairs(peers) do
    if peer.ip:lower() == address or peer.hostname:lower() == address or tostring(peer.id) == address then
      return peer
    end
  end
  return nil
end

function N.isIP(value) return validIP(value) end

return N
