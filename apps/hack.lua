-- HackOS Government: simulated exploit console for the KL OS legacy diagnostic weakness.
-- Provides read-only diagnostics and /public file access only; never executes remote shell commands.
local ui = require("os.ui")
local net = require("os.network")
local legacy = require("os.legacy")
local A = {}

local function waitMessage(peerID, expected, timeout)
  local deadline = os.clock() + (timeout or 3)
  while os.clock() < deadline do
    local left = deadline - os.clock()
    local id, msg = rednet.receive(legacy.PROTOCOL, left)
    if not id then return nil end
    if id == peerID and type(msg) == "table" and msg.kind == expected then return msg end
  end
  return nil
end

local function scan(timeout)
  local opened, err = net.open()
  if not opened then return nil, err end
  rednet.broadcast({ kind = "PROBE", version = 1 }, legacy.PROTOCOL)
  local peers, seen = {}, {}
  local deadline = os.clock() + (timeout or 2)
  while os.clock() < deadline do
    local id, msg = rednet.receive(legacy.PROTOCOL, deadline - os.clock())
    if not id then break end
    if type(msg) == "table" and msg.kind == "OFFER" and id ~= os.getComputerID() and not seen[id] then
      seen[id] = true
      peers[#peers + 1] = {
        id = id, ip = tostring(msg.ip or "unknown"), hostname = tostring(msg.hostname or ("computer-" .. id)),
        edition = tostring(msg.edition or (msg.patched and "KL OS (patched)" or "Unknown")),
        vulnerable = msg.vulnerable == true, patched = msg.patched == true,
      }
    end
  end
  table.sort(peers, function(a, b) return a.id < b.id end)
  return peers
end

local function query(peer, token, action, name)
  rednet.send(peer.id, { kind = "QUERY", token = token, action = action, name = name }, legacy.PROTOCOL)
  local response = waitMessage(peer.id, "RESULT", 4)
  if not response then return nil, "No response from target." end
  if not response.ok then return nil, response.error or "Request denied." end
  return response.data
end

local function showInfo(data)
  if type(data) ~= "table" then ui.message("Exploit result", tostring(data)); return end
  local text = table.concat({
    "OS: " .. tostring(data.os),
    "Version: " .. tostring(data.version),
    "Hostname: " .. tostring(data.hostname),
    "IPv4: " .. tostring(data.ip),
    "Computer ID: #" .. tostring(data.computer),
    "Uptime: " .. tostring(data.uptime) .. " seconds",
    "Free space: " .. tostring(data.freeSpace),
    "Remote Access enabled: " .. tostring(data.remoteAccessEnabled),
    "Privilege: " .. tostring(data.access),
  }, "\n")
  ui.message("System diagnostics", text)
end

local function guestSession(peer)
  ui.clear(ui.theme().bg, ui.theme().fg)
  ui.header("Exploit attempt", "KL-LEGACY-DIAG")
  ui.text(2, 3, "Target: " .. peer.hostname .. " (#" .. peer.id .. ")", ui.theme().fg, ui.theme().bg)
  ui.text(2, 5, "Reproducing legacy diagnostics weakness...", ui.theme().accent, ui.theme().bg)
  rednet.send(peer.id, { kind = "EXPLOIT", exploit = "KLOS-LEGACY-DIAG-01" }, legacy.PROTOCOL)
  local session = waitMessage(peer.id, "SESSION", 4)
  if not session then ui.message("Exploit failed", "No response. The target may be offline or the diagnostic service may be patched."); return end
  if not session.ok then ui.message("Exploit failed", session.error or "Target rejected the request."); return end

  ui.message("Guest session opened", session.message or "Read-only diagnostic access established.")
  while true do
    local choice = ui.input("Guest session: " .. peer.hostname,
      "1 System info | 2 List /public | 3 Read public file | 4 Disconnect", "1")
    if not choice or choice == "4" then
      query(peer, session.token, "DISCONNECT")
      return
    elseif choice == "1" then
      local data, err = query(peer, session.token, "INFO")
      if data then showInfo(data) else ui.message("Diagnostics", err) end
    elseif choice == "2" then
      local data, err = query(peer, session.token, "LIST_PUBLIC")
      if data then
        if type(data) == "table" and #data == 0 then data = { "(empty)" } end
        ui.message("Public files on " .. peer.hostname, type(data) == "table" and table.concat(data, "\n") or tostring(data))
      else ui.message("Public directory", err) end
    elseif choice == "3" then
      local name = ui.input("Read public file", "Filename inside /public (example: welcome.txt)", "welcome.txt")
      if name and name ~= "" then
        local data, err = query(peer, session.token, "READ_PUBLIC", name)
        if data then ui.message("/public/" .. name, data) else ui.message("Read failed", err) end
      end
    else
      ui.message("Guest session", "Choose 1, 2, 3 or 4. This session is read-only.")
    end
  end
end

function A.run()
  local opened, openError = net.open()
  if not opened then ui.message("Hack Console", openError); return end
  local peers, selected, status, scroll = {}, 1, "Ready", 0
  while true do
    local w, h = ui.size()
    local T = ui.theme()
    ui.clear(T.bg, T.fg)
    ui.header("HackOS Exploit Console", "LEGACY DIAGNOSTICS")
    ui.text(2, 3, "This lab exploit does not require Remote Access to be enabled.", T.accent, T.bg)
    ui.text(2, 4, "Guest access is read-only: diagnostics and files in /public.", T.fg, T.bg)
    ui.text(2, 6, "DISCOVERED KL OS / HACKOS NODES", T.accent, T.bg)
    local first, visible = 7, math.max(1, h - 12)
    scroll = math.max(0, math.min(scroll, math.max(0, #peers - visible)))
    for i = 1, visible do
      local p = peers[scroll + i]
      if p then
        local state = p.vulnerable and "EXPOSED" or (p.patched and "PATCHED" or "UNKNOWN")
        local line = string.format("%s  %-12s  #%d  %s", p.ip, p.hostname, p.id, state)
        ui.text(2, first + i - 1, ui.pad(line, w - 3), selected == scroll + i and T.selectedfg or T.fg, selected == scroll + i and T.selected or T.bg)
      end
    end
    ui.text(2, h - 4, "Status: " .. status, T.fg, T.bg)
    local scanBtn = ui.button(2, h - 2, "Scan")
    local exploitBtn = ui.button(13, h - 2, "Exploit")
    local backBtn = ui.button(w - 8, h - 2, "Back")
    ui.drawCursor()

    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = scroll + ev[2] * 2 end
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(math.max(1, #peers), selected + 1)
      elseif ev[2] == keys.enter and peers[selected] then guestSession(peers[selected]) end
    end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      local row = y - first + 1 + scroll
      if y >= first and y < first + visible and peers[row] then selected = row
      elseif ui.hit(scanBtn, x, y) then
        status = "Scanning rednet..."
        peers = scan(2) or {}
        selected, scroll = 1, 0
        status = "Found " .. #peers .. " KL OS / HackOS node(s)"
      elseif ui.hit(exploitBtn, x, y) and peers[selected] then
        guestSession(peers[selected])
      elseif ui.hit(backBtn, x, y) then return end
    end
  end
end

return A
