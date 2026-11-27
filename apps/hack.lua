-- HackOS Government exploit lab: read-only guest diagnostics plus a scoped KL OS Standard system-file exploit.
local ui = require("os.ui")
local net = require("os.network")
local legacy = require("os.legacy")
local A = {}

local function waitMessage(peerID, expected, timeout)
  local deadline = os.clock() + (timeout or 3)
  while os.clock() < deadline do
    local id, msg = rednet.receive(legacy.PROTOCOL, math.max(0.05, deadline - os.clock()))
    if not id then return nil end
    if id == peerID and type(msg) == "table" and msg.kind == expected then return msg end
  end
  return nil
end

local function scan(timeout)
  local opened, err = net.open()
  if not opened then return nil, err end
  rednet.broadcast({ kind = "PROBE", version = 1 }, legacy.PROTOCOL)
  rednet.broadcast({ kind = "SYSTEM_PROBE", version = 1 }, legacy.PROTOCOL)
  local peers, seen = {}, {}
  local deadline = os.clock() + (timeout or 2)
  while os.clock() < deadline do
    local id, msg = rednet.receive(legacy.PROTOCOL, math.max(0.05, deadline - os.clock()))
    if not id then break end
    if id ~= os.getComputerID() and type(msg) == "table" then
      local p = seen[id]
      if not p and (msg.kind == "OFFER" or msg.kind == "SYSTEM_OFFER") then
        p = { id = id, ip = tostring(msg.ip or "unknown"), hostname = tostring(msg.hostname or ("computer-" .. id)), edition = tostring(msg.edition or "Unknown"), services = {} }
        seen[id] = p; peers[#peers + 1] = p
      end
      if p and msg.kind == "OFFER" then
        p.ip = tostring(msg.ip or p.ip); p.hostname = tostring(msg.hostname or p.hostname)
        p.edition = tostring(msg.edition or p.edition)
        p.vulnerable = msg.vulnerable == true; p.patched = msg.patched == true
      elseif p and msg.kind == "SYSTEM_OFFER" then
        p.systemVulnerable = msg.vulnerable == true
        p.edition = tostring(msg.edition or p.edition)
        p.attack = tostring(msg.attack or "KLOS-BOOT-OVERWRITE")
      end
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
  ui.message("System diagnostics", table.concat({
    "OS: " .. tostring(data.os), "Version: " .. tostring(data.version),
    "Hostname: " .. tostring(data.hostname), "IPv4: " .. tostring(data.ip),
    "Computer ID: #" .. tostring(data.computer), "Uptime: " .. tostring(data.uptime) .. " seconds",
    "Free space: " .. tostring(data.freeSpace), "Remote Access enabled: " .. tostring(data.remoteAccessEnabled),
    "Privilege: " .. tostring(data.access),
  }, "\n"))
end

local function guestSession(peer)
  ui.clear(ui.theme().bg, ui.theme().fg); ui.header("Guest diagnostics", "READ ONLY")
  ui.text(2, 3, "Target: " .. peer.hostname .. " (#" .. peer.id .. ")", ui.theme().fg, ui.theme().bg)
  ui.text(2, 5, "Opening the legacy diagnostic session...", ui.theme().accent, ui.theme().bg)
  rednet.send(peer.id, { kind = "EXPLOIT", exploit = "KLOS-LEGACY-DIAG-01" }, legacy.PROTOCOL)
  local session = waitMessage(peer.id, "SESSION", 4)
  if not session then ui.message("Exploit failed", "No response. The target may be offline or patched."); return end
  if not session.ok then ui.message("Exploit failed", session.error or "Target rejected the request."); return end
  ui.message("Guest session", session.message or "Read-only diagnostic access established.")
  while true do
    local choice = ui.input("Guest session: " .. peer.hostname, "1 System info | 2 List /public | 3 Read file | 4 Disconnect", "1")
    if not choice or choice == "4" then query(peer, session.token, "DISCONNECT"); return
    elseif choice == "1" then
      local data, err = query(peer, session.token, "INFO"); if data then showInfo(data) else ui.message("Diagnostics", err) end
    elseif choice == "2" then
      local data, err = query(peer, session.token, "LIST_PUBLIC")
      if data then if #data == 0 then data = { "(empty)" } end; ui.message("Public files", type(data) == "table" and table.concat(data, "\n") or tostring(data)) else ui.message("Public files", err) end
    elseif choice == "3" then
      local name = ui.input("Read public file", "Filename inside /public:", "welcome.txt")
      if name and name ~= "" then local data, err = query(peer, session.token, "READ_PUBLIC", name); if data then ui.message("/public/" .. name, data) else ui.message("Read failed", err) end end
    else ui.message("Guest session", "Choose 1, 2, 3 or 4.") end
  end
end

local function systemExploit(peer)
  if not peer.systemVulnerable then
    ui.message("No boot exploit", "This target did not identify itself as KL OS Standard 2.4.0 or newer.")
    return
  end
  ui.clear(ui.theme().bg, ui.theme().fg); ui.header("KLOS-BOOT-OVERWRITE", "SYSTEM EXPLOIT")
  ui.text(2, 3, "Target: " .. peer.hostname .. " (#" .. peer.id .. ")", ui.theme().fg, ui.theme().bg)
  ui.text(2, 5, "Bypassing KL OS local security toggles...", ui.theme().accent, ui.theme().bg)
  rednet.send(peer.id, { kind = "SYSTEM_EXPLOIT", exploit = "KLOS-BOOT-OVERWRITE" }, legacy.PROTOCOL)
  local session = waitMessage(peer.id, "SYSTEM_SESSION", 4)
  if not session then ui.message("Exploit failed", "No response from target."); return end
  if not session.ok then ui.message("Exploit failed", session.error or "Target rejected the exploit."); return end
  rednet.send(peer.id, { kind = "SYSTEM_LIST", token = session.token }, legacy.PROTOCOL)
  local listing = waitMessage(peer.id, "SYSTEM_LIST_RESULT", 4)
  if not listing or not listing.ok then ui.message("System file list", listing and listing.error or "Target did not return a file list."); return end
  local files = listing.files or {}
  if #files == 0 then ui.message("System file list", "No removable system files were found."); return end
  local choices = {}
  for i, candidate in ipairs(files) do choices[#choices + 1] = tostring(i) .. ". " .. candidate end
  ui.message("Target system files", table.concat(choices, "\n") .. "\n\nRemoving a file triggers the target's blue-screen recovery.")
  local picked = tonumber(ui.input("Remove system file", "Enter the file number to remove (1-" .. #files .. "):", "1"))
  if not picked or picked < 1 or picked > #files or picked ~= math.floor(picked) then
    ui.message("Invalid selection", "Choose a number from the target's system-file list."); return
  end
  local path = files[picked]
  local confirm = ui.input("Confirm system damage", "Type DELETE to remove " .. path .. " on " .. peer.hostname .. ":", "")
  if confirm ~= "DELETE" then ui.message("Cancelled", "No system file was removed."); return end
  rednet.send(peer.id, { kind = "SYSTEM_DELETE", token = session.token, path = path }, legacy.PROTOCOL)
  local result = waitMessage(peer.id, "SYSTEM_DELETE_RESULT", 4)
  if result and result.ok then
    ui.message("Exploit successful", "Removed " .. path .. " from " .. peer.hostname .. ".\n\nThe target has entered its blue-screen recovery screen. Its local user can press R to repair from the recovery image.")
  else ui.message("Exploit failed", result and result.error or "No response from target.") end
end

function A.run()
  local opened, openError = net.open()
  if not opened then ui.message("Hack Console", openError); return end
  local peers, selected, status, scroll = {}, 1, "Ready", 0
  while true do
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.bg, T.fg); ui.header("HackOS Exploit Console", "KLOS LAB")
    ui.text(2, 3, "In-game exploit lab: KL OS Standard only.", T.accent, T.bg)
    ui.text(2, 4, "System-file exploit ignores KL OS Remote/Security toggles.", T.fg, T.bg)
    ui.text(2, 6, "DISCOVERED COMPUTERS", T.accent, T.bg)
    local first, visible = 7, math.max(1, h - 12)
    scroll = math.max(0, math.min(scroll, math.max(0, #peers - visible)))
    for i = 1, visible do
      local p = peers[scroll + i]
      if p then
        local state = p.systemVulnerable and "BOOT EXPLOIT" or (p.vulnerable and "GUEST" or (p.patched and "PATCHED" or "ONLINE"))
        local line = string.format("%s  %-12s  #%d  %s", p.ip, p.hostname, p.id, state)
        ui.text(2, first + i - 1, ui.pad(line, w - 3), selected == scroll + i and T.selectedfg or T.fg, selected == scroll + i and T.selected or T.bg)
      end
    end
    ui.text(2, h - 4, "Status: " .. status, T.fg, T.bg)
    local scanBtn = ui.button(2, h - 2, "Scan")
    local guestBtn = ui.button(11, h - 2, "Guest")
    local wipeBtn = ui.button(21, h - 2, "Delete system file")
    local backBtn = ui.button(w - 8, h - 2, "Back")
    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = scroll + ev[2] * 2 end
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(math.max(1, #peers), selected + 1)
      elseif ev[2] == keys.enter and peers[selected] then systemExploit(peers[selected]) end
    end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      local row = y - first + 1 + scroll
      if y >= first and y < first + visible and peers[row] then selected = row
      elseif ui.hit(scanBtn, x, y) then status = "Scanning rednet..."; peers = scan(2) or {}; selected, scroll = 1, 0; status = "Found " .. #peers .. " node(s)"
      elseif ui.hit(guestBtn, x, y) and peers[selected] then guestSession(peers[selected])
      elseif ui.hit(wipeBtn, x, y) and peers[selected] then systemExploit(peers[selected])
      elseif ui.hit(backBtn, x, y) then return end
    end
  end
end
return A
