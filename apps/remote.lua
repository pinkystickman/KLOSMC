-- Government Remote Center: multi-PC dashboard, remote desktop, shell, files and power.
local ui = require("os.ui")
local net = require("os.network")
local remote = require("os.remote")
local A = {}
local requestID = 0

local function request(peer, pin, kind, payload, expected, timeout)
  requestID = requestID + 1
  local id = requestID
  payload = payload or {}
  payload.kind, payload.pin, payload.request = kind, pin, id
  rednet.send(peer.id, payload, remote.PROTOCOL)
  local deadline = os.clock() + (timeout or 4)
  while os.clock() < deadline do
    local sender, msg = rednet.receive(remote.PROTOCOL, math.max(0.05, deadline - os.clock()))
    if not sender then break end
    if sender == peer.id and type(msg) == "table" and msg.kind == expected and (msg.request == nil or msg.request == id) then return msg end
  end
  return nil
end

local function hasService(peer, name)
  for _, service in ipairs(peer.services or {}) do if service == name then return true end end
  return false
end

-- The remote display is cropped at the lower/right edge when resolutions differ,
-- so preserve the visible top-left character coordinates for mouse input.
local function scalePoint(x, y, localW, localH, remoteW, remoteH)
  local rx = math.max(1, math.min(remoteW, math.floor(x)))
  local ry = math.max(1, math.min(remoteH, math.floor(y)))
  return rx, ry
end

local function drawFrame(frame, status)
  if type(frame) ~= "table" or type(frame.lines) ~= "table" then return end
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
  local rows = math.min(h, tonumber(frame.height) or #frame.lines)
  for y = 1, rows do
    local row = frame.lines[y]
    if type(row) == "table" then
      term.setCursorPos(1, y)
      local text = tostring(row.text or "")
      local fg, bg = tostring(row.fg or string.rep("0", #text)), tostring(row.bg or string.rep("f", #text))
      local maxLen = math.min(w, #text, #fg, #bg)
      if maxLen > 0 then
        if term.isColor() then term.blit(text:sub(1, maxLen), fg:sub(1, maxLen), bg:sub(1, maxLen))
        else term.write(text:sub(1, maxLen)) end
      end
    end
  end
  local cx, cy = tonumber(frame.cursorX), tonumber(frame.cursorY)
  if cx and cy and cx >= 1 and cx <= w and cy >= 1 and cy <= h then
    term.setCursorPos(cx, cy)
    term.setCursorBlink(frame.cursorBlink == true)
  else
    term.setCursorBlink(false)
  end
end

local function sendInput(peer, pin, event, args)
  rednet.send(peer.id, { kind = "INPUT", pin = pin, event = event, args = args }, remote.PROTOCOL)
end

local function remoteDesktop(peer, pin)
  local lastFrame, targetW, targetH = nil, nil, nil
  local lastResponse = os.clock()
  local timer = os.startTimer(0.2)
  local localW, localH = term.getSize()
  while true do
    local ev = { os.pullEvent() }
    if ev[1] == "timer" and ev[2] == timer then
      requestID = requestID + 1
      rednet.send(peer.id, { kind = "SCREEN", pin = pin, request = requestID }, remote.PROTOCOL)
      timer = os.startTimer(0.2)
      if os.clock() - lastResponse > 4 then
        if lastFrame then drawFrame(lastFrame, nil)
        else
          term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(2, 2)
          term.write("Waiting for " .. peer.hostname .. " screen...")
          term.setCursorPos(2, 4); term.write("Check the network and access code.")
          term.setCursorPos(2, 6); term.write("Press ESC or F2 to disconnect.")
        end
      end
    elseif ev[1] == "rednet_message" and ev[2] == peer.id and ev[4] == remote.PROTOCOL and type(ev[3]) == "table" then
      local msg = ev[3]
      if msg.kind == "SCREEN_RESULT" then
        lastResponse = os.clock()
        if msg.ok and type(msg.frame) == "table" then
          lastFrame = msg.frame; targetW = tonumber(msg.frame.width) or localW; targetH = tonumber(msg.frame.height) or localH
          drawFrame(lastFrame, peer.hostname .. "  |  " .. peer.ip)
        elseif msg.error then drawFrame(lastFrame or {}, msg.error) end
      end
    elseif ev[1] == "key" then
      if ev[2] == keys.escape or ev[2] == keys.f2 then
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); return
      end
      sendInput(peer, pin, "key", { ev[2] })
    elseif ev[1] == "key_up" then sendInput(peer, pin, "key_up", { ev[2] })
    elseif ev[1] == "char" then sendInput(peer, pin, "char", { ev[2] })
    elseif ev[1] == "paste" then sendInput(peer, pin, "paste", { ev[2] })
    elseif ev[1] == "mouse_click" or ev[1] == "mouse_drag" or ev[1] == "mouse_up" then
      local tw, th = targetW or localW, targetH or localH
      local x, y = scalePoint(ev[3], ev[4], localW, localH, tw, th)
      sendInput(peer, pin, ev[1], { ev[2], x, y })
    elseif ev[1] == "mouse_scroll" then
      local tw, th = targetW or localW, targetH or localH
      local x, y = scalePoint(ev[3], ev[4], localW, localH, tw, th)
      sendInput(peer, pin, "mouse_scroll", { ev[2], x, y })
    end
  end
end

local function remoteShell(peer, pin)
  while true do
    local command = ui.input("Remote Shell: " .. peer.hostname, "CraftOS command (blank to return):", "")
    if not command or command == "" then return end
    local result = request(peer, pin, "EXEC", { command = command }, "EXEC_RESULT", 10)
    if not result then ui.message("Remote Shell", "No response from the target computer.")
    else ui.message("Remote Shell " .. (result.ok and "[OK]" or "[ERROR]"), result.output or "(No output)") end
  end
end

local function remoteFiles(peer, pin)
  while true do
    local list = request(peer, pin, "FILES_LIST", {}, "FILES_RESULT", 5)
    local entries = list and list.ok and list.entries or {}
    local lines = { "Remote shared folder: /public", "Files are limited to 8192 bytes each." }
    for _, name in ipairs(entries) do lines[#lines + 1] = name end
    ui.message("Remote Files: " .. peer.hostname, table.concat(lines, "\n"))
    local action = ui.input("Remote File Transfer", "1 Download | 2 Upload | 3 Refresh | 4 Back", "1")
    if not action or action == "4" then return
    elseif action == "1" then
      local name = ui.input("Download from " .. peer.hostname, "Filename inside remote /public:", "")
      if name and name ~= "" then
        local result = request(peer, pin, "FILES_GET", { name = name }, "FILES_RESULT", 6)
        if result and result.ok and type(result.data) == "string" then
          local folder = fs.combine("/downloads", peer.hostname)
          fs.makeDir(folder)
          local path = fs.combine(folder, name)
          local f, err = fs.open(path, "w")
          if f then f.write(result.data); f.close(); ui.message("Download complete", "Saved to " .. path)
          else ui.message("Download failed", tostring(err)) end
        else ui.message("Download failed", result and result.error or "No response from server.") end
      end
    elseif action == "2" then
      local localPath = ui.input("Upload to " .. peer.hostname, "Local file path:", "/public/notice.txt")
      if localPath and fs.exists(localPath) and not fs.isDir(localPath) then
        local f = fs.open(localPath, "r"); local data = f.readAll(); f.close()
        local name = ui.input("Remote filename", "Save as in remote /public:", fs.getName(localPath))
        if name and name ~= "" then
          local result = request(peer, pin, "FILES_PUT", { name = name, data = data }, "FILES_RESULT", 6)
          ui.message("Upload", result and (result.ok and ("Uploaded to /public/" .. name) or result.error) or "No response.")
        end
      else ui.message("Upload", "Local file not found or is a directory.") end
    elseif action ~= "3" then ui.message("File Transfer", "Choose 1, 2, 3 or 4.") end
  end
end

local function powerMenu(peer, pin)
  local choice = ui.input("Power Management: " .. peer.hostname, "1 Restart computer | 2 Shut down | 3 Cancel", "3")
  if choice ~= "1" and choice ~= "2" then return end
  local confirm = ui.input("Confirm remote power", "Type YES to " .. (choice == "1" and "restart" or "shut down") .. " " .. peer.hostname .. ":", "")
  if confirm ~= "YES" then ui.message("Power Management", "Cancelled."); return end
  local result = request(peer, pin, "POWER", { action = choice == "1" and "reboot" or "shutdown" }, "POWER_RESULT", 4)
  ui.message("Power Management", result and (result.ok and (peer.hostname .. " accepted the command.") or result.error) or "No response from target.")
end

local function manage(peer)
  if not hasService(peer, "REMOTE") then
    ui.message("Remote access unavailable", peer.hostname .. " is online, but has not enabled incoming Remote Access. The target owner must enable it locally and share its access code.")
    return
  end
  local pin = ui.input("Remote Authentication", "Access code for " .. peer.hostname .. ":", "")
  if not pin or pin == "" then return end
  local auth = request(peer, pin, "AUTH", {}, "AUTH_RESULT", 4)
  if not auth or not auth.ok then ui.message("Connection failed", auth and auth.error or "No response from target."); return end
  while true do
    local choice = ui.input("Connected: " .. peer.hostname,
      "1 Remote Desktop | 2 Remote Shell | 3 File Transfer | 4 Power | 5 Disconnect", "1")
    if not choice or choice == "5" then return
    elseif choice == "1" then remoteDesktop(peer, pin)
    elseif choice == "2" then remoteShell(peer, pin)
    elseif choice == "3" then remoteFiles(peer, pin)
    elseif choice == "4" then powerMenu(peer, pin)
    else ui.message("Remote Control", "Choose 1, 2, 3, 4 or 5.") end
  end
end

function A.run()
  local opened, openError = net.open()
  if not opened then ui.message("Remote Control", openError); return end
  local peers, selected, status, scroll = {}, 1, "Ready", 0
  while true do
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.bg, T.fg); ui.header("Remote Center", "MULTI-PC ADMIN")
    local incoming, localPin = remote.getStatus()
    ui.text(2, 3, "INCOMING ACCESS: " .. (incoming and ("ENABLED  |  CODE " .. localPin) or "DISABLED"), incoming and T.good or T.bad, T.bg)
    ui.text(2, 5, "DISCOVERED REMOTE COMPUTERS  |  " .. #peers .. " available", T.accent, T.bg)
    local first, visible = 6, math.max(1, h - 14)
    scroll = math.max(0, math.min(scroll, math.max(0, #peers - visible)))
    for i = 1, visible do
      local p = peers[scroll + i]
      if p then
        local access = hasService(p, "REMOTE") and "[REMOTE]" or "[LOCKED]"
        local label = string.format("%s  %-12s  #%d %s", p.ip, p.hostname, p.id, access)
        ui.text(2, first + i - 1, ui.pad(label, w - 3), selected == scroll + i and T.selectedfg or T.fg, selected == scroll + i and T.selected or T.bg)
      end
    end
    ui.text(2, h - 5, "Status: " .. status, T.fg, T.bg)
    local accessBtn = ui.button(2, h - 3, incoming and "Disable Access" or "Enable Access")
    local rotateBtn = ui.button(19, h - 3, "New Code")
    local scanBtn = ui.button(2, h - 2, "Scan")
    local manageBtn = ui.button(12, h - 2, "Manage Selected")
    local backBtn = ui.button(w - 8, h - 2, "Back")
    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = scroll + ev[2] * 2 end
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(math.max(1, #peers), selected + 1)
      elseif ev[2] == keys.enter and peers[selected] then manage(peers[selected]) end
    end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      local row = y - first + 1 + scroll
      if y >= first and y < first + visible and peers[row] then selected = row
      elseif ui.hit(accessBtn, x, y) then
        if incoming then
          local ok, why = remote.disable(); status = ok and "Incoming remote access disabled" or tostring(why)
        else
          local ok, value = remote.enable(); status = ok and ("Enabled. Share code: " .. value) or tostring(value)
        end
      elseif ui.hit(rotateBtn, x, y) then
        local ok, value = remote.rotatePin(); status = ok and ("New access code: " .. value) or tostring(value)
      elseif ui.hit(scanBtn, x, y) then
        status = "Scanning network..."
        local found, err = net.discover(2)
        peers = found or {}
        local enabledCount = 0
        for _, peer in ipairs(peers) do if hasService(peer, "REMOTE") then enabledCount = enabledCount + 1 end end
        selected, scroll = 1, 0
        status = err or ("Found " .. #peers .. " nodes; " .. enabledCount .. " remote-enabled")
      elseif ui.hit(manageBtn, x, y) and peers[selected] then manage(peers[selected])
      elseif ui.hit(backBtn, x, y) then return end
    end
  end
end

return A
