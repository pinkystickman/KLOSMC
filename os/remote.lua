-- KL OS / HackOS remote administration and live terminal screen service for CC:Tweaked.
-- Remote actions require the target computer's locally enabled access code.
local R = {}
R.PROTOCOL = "hackos_remote_v1"
local CFG = "/hackos/remote.json"
local net = require("os.network")
local privacy = require("os.privacy")

local function readConfig()
  fs.makeDir("/hackos")
  local cfg = { enabled = false, pin = "" }
  if fs.exists(CFG) then
    local f = fs.open(CFG, "r")
    if f then
      local raw = f.readAll(); f.close()
      local saved = textutils.unserializeJSON(raw)
      if type(saved) == "table" then
        cfg.enabled = saved.enabled == true
        if type(saved.pin) == "string" and saved.pin:match("^%d%d%d%d%d%d%d%d$") then cfg.pin = saved.pin end
      end
    end
  end
  return cfg
end

local function writeConfig(cfg)
  fs.makeDir("/hackos")
  local f, err = fs.open(CFG, "w")
  if not f then return false, err end
  f.write(textutils.serialiseJSON(cfg)); f.close()
  return true
end

local function newPin()
  local seed = math.floor(os.clock() * 100000) + os.getComputerID() * 7919
  if os.epoch then
    local ok, value = pcall(os.epoch, "utc")
    if ok and value then seed = (value + math.floor(os.clock() * 1000000) + os.getComputerID() * 7919) % 2147483647 end
  end
  math.randomseed(seed)
  return string.format("%08d", math.random(0, 99999999))
end

function R.getStatus()
  local cfg = readConfig()
  return cfg.enabled, cfg.pin
end

function R.enable()
  local cfg = readConfig()
  if cfg.pin == "" then cfg.pin = newPin() end
  cfg.enabled = true
  local ok, err = writeConfig(cfg)
  if not ok then return false, err end
  privacy.log("REMOTE_ACCESS_ENABLED", "Enabled on this computer")
  return true, cfg.pin
end

function R.disable()
  local cfg = readConfig(); cfg.enabled = false
  local ok, err = writeConfig(cfg)
  if ok then privacy.log("REMOTE_ACCESS_DISABLED", "Disabled on this computer") end
  return ok, err
end

function R.rotatePin()
  local cfg = readConfig(); cfg.pin = newPin(); cfg.enabled = true
  local ok, err = writeConfig(cfg)
  if not ok then return false, err end
  privacy.log("REMOTE_PIN_ROTATED", "Remote access code was changed")
  return true, cfg.pin
end

local function authorised(msg)
  local cfg = readConfig()
  return cfg.enabled and type(msg) == "table" and type(msg.pin) == "string" and msg.pin == cfg.pin
end

local function tokenize(command)
  local args, token, quote, escaped = {}, "", nil, false
  for i = 1, #command do
    local ch = command:sub(i, i)
    if escaped then token = token .. ch; escaped = false
    elseif ch == "\\" and quote then escaped = true
    elseif quote then if ch == quote then quote = nil else token = token .. ch end
    elseif ch == "'" or ch == '"' then quote = ch
    elseif ch:match("%s") then if token ~= "" then args[#args + 1] = token; token = "" end
    else token = token .. ch end
  end
  if quote then return nil, "Unclosed quote in command." end
  if escaped then token = token .. "\\" end
  if token ~= "" then args[#args + 1] = token end
  if #args == 0 then return nil, "Enter a command." end
  return args
end

local function execute(command)
  command = tostring(command or "")
  if #command > 220 then return false, "Command is too long (220 characters maximum)." end
  if command:find("[\r\n]") then return false, "Only one command per request is supported." end
  local args, err = tokenize(command)
  if not args then return false, err end
  if not shell or not shell.run then return false, "CraftOS shell API is unavailable." end
  if not window or not window.create then return false, "Terminal capture API is unavailable." end

  local finished, succeeded, output = false, false, ""
  local oldTerm, oldDir
  local function restore()
    if oldDir and shell.setDir then pcall(shell.setDir, oldDir); oldDir = nil end
    if oldTerm then pcall(term.redirect, oldTerm); oldTerm = nil end
  end
  local function runJob()
    local capture
    local w, h = term.getSize()
    local jobOK, jobError = pcall(function()
      capture = window.create(term.current(), 1, 1, math.max(10, w), math.max(5, h), false)
      oldTerm = term.redirect(capture)
      oldDir = shell.dir and shell.dir() or nil
      local callOK, result = pcall(function() return shell.run(table.unpack(args)) end)
      local lines = {}
      for y = 1, h do
        local line = capture.getLine(y)
        line = (line or ""):gsub("%s+$", "")
        if line ~= "" then lines[#lines + 1] = line end
      end
      output = table.concat(lines, "\n")
      if output == "" then output = callOK and result ~= false and "Command completed with no output." or "Command returned no output." end
      succeeded = callOK and result ~= false
      if not callOK then output = output .. "\nError: " .. tostring(result) end
    end)
    restore()
    if not jobOK then succeeded = false; output = "Remote command failed: " .. tostring(jobError) end
    finished = true
  end
  local function timeout() os.sleep(8) end
  parallel.waitForAny(runJob, timeout)
  if not finished then
    restore()
    return false, "Command timed out after 8 seconds. Interactive commands are not supported."
  end
  if #output > 2200 then output = output:sub(1, 2200) .. "\n[Output truncated]" end
  return succeeded, output
end

local function getFrame()
  -- startup.lua redirects the OS to a CC:Tweaked window, which exposes getLine().
  -- Capture that shared terminal buffer so the controller sees the actual desktop/app UI.
  local t = term.current()
  if not t or type(t.getLine) ~= "function" then
    return nil, "Screen capture is unavailable. Reinstall this edition and reboot."
  end
  local ok, frame = pcall(function()
    local w, h = t.getSize()
    if type(w) ~= "number" or type(h) ~= "number" or w < 1 or h < 1 or w > 200 or h > 80 then
      error("Unsupported terminal dimensions.")
    end
    local lines = {}
    for y = 1, h do
      local lineText, fg, bg = t.getLine(y)
      lineText, fg, bg = tostring(lineText or ""), tostring(fg or ""), tostring(bg or "")
      if #lineText < w then lineText = lineText .. string.rep(" ", w - #lineText) end
      if #fg < w then fg = fg .. string.rep("0", w - #fg) end
      if #bg < w then bg = bg .. string.rep("f", w - #bg) end
      lines[y] = { text = lineText:sub(1, w), fg = fg:sub(1, w), bg = bg:sub(1, w) }
    end
    local cx, cy = t.getCursorPos()
    local blink = false
    if type(t.getCursorBlink) == "function" then blink = t.getCursorBlink() end
    return { width = w, height = h, lines = lines, cursorX = cx, cursorY = cy, cursorBlink = blink == true }
  end)
  if not ok then return nil, "Screen capture failed: " .. tostring(frame) end
  return frame
end

local function safePublicName(name)
  if type(name) ~= "string" or #name < 1 or #name > 64 then return nil end
  if name:find("..", 1, true) or name:find("/", 1, true) or name:find("\\", 1, true) or name:find(":", 1, true) then return nil end
  if name == "." or name == ".." then return nil end
  return fs.combine("/public", name)
end

local function handleInput(id, msg)
  local event = msg.event
  local args = msg.args
  if type(event) ~= "string" or type(args) ~= "table" then return end
  local allowed = { key = true, key_up = true, char = true, paste = true, mouse_click = true, mouse_drag = true, mouse_up = true, mouse_scroll = true }
  if not allowed[event] then return end
  if event == "key" or event == "key_up" then
    if type(args[1]) == "number" then os.queueEvent(event, args[1]) end
  elseif event == "char" then
    if type(args[1]) == "string" and #args[1] <= 1 then os.queueEvent(event, args[1]) end
  elseif event == "paste" then
    if type(args[1]) == "string" and #args[1] <= 256 then os.queueEvent(event, args[1]) end
  elseif event == "mouse_click" or event == "mouse_drag" or event == "mouse_up" then
    local b, x, y = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    local w, h = term.getSize()
    if b and b >= 1 and b <= 3 and x and y and x >= 1 and x <= w and y >= 1 and y <= h then os.queueEvent(event, b, math.floor(x), math.floor(y)) end
  elseif event == "mouse_scroll" then
    local d, x, y = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    local w, h = term.getSize()
    if d and (d == -1 or d == 1) and x and y and x >= 1 and x <= w and y >= 1 and y <= h then os.queueEvent(event, d, math.floor(x), math.floor(y)) end
  end
end

local function send(id, payload) rednet.send(id, payload, R.PROTOCOL) end

local function offer(id)
  if not privacy.get("network_discovery") then return end
  local cfg = readConfig()
  local services = { "DISCOVERY", "MAIL", "GUEST_DIAGNOSTICS" }
  if cfg.enabled then
    services[#services + 1] = "REMOTE"
    services[#services + 1] = "REMOTE_DESKTOP"
    services[#services + 1] = "FILE_TRANSFER"
    services[#services + 1] = "POWER"
  end
  rednet.send(id, { kind = "OFFER", version = 2, ip = net.getIP(), hostname = net.getHostname(), services = services }, net.PROTOCOL)
end

local function handleRemote(id, msg)
  if type(msg) ~= "table" then return end
  if msg.kind == "AUTH" then
    if authorised(msg) then
      privacy.log("REMOTE_AUTH_OK", "Authenticated controller computer #" .. tostring(id))
      send(id, { kind = "AUTH_RESULT", ok = true, hostname = net.getHostname(), ip = net.getIP(), computer = os.getComputerID() })
    else
      privacy.log("REMOTE_AUTH_DENIED", "Failed authentication from computer #" .. tostring(id))
      send(id, { kind = "AUTH_RESULT", ok = false, error = "Access denied. Check the access code or enable Remote Access on the target PC." })
    end
  elseif msg.kind == "EXEC" then
    if not authorised(msg) then
      privacy.log("REMOTE_DENIED", "Rejected shell request from computer #" .. tostring(id))
      send(id, { kind = "EXEC_RESULT", request = msg.request, ok = false, output = "Access denied." }); return
    end
    privacy.log("REMOTE_COMMAND", "Authenticated computer #" .. tostring(id) .. " requested a command")
    local ok, output = execute(msg.command)
    send(id, { kind = "EXEC_RESULT", request = msg.request, ok = ok, output = output })
  elseif msg.kind == "SCREEN" then
    if not authorised(msg) then
      privacy.log("REMOTE_DENIED", "Rejected screen request from computer #" .. tostring(id))
      send(id, { kind = "SCREEN_RESULT", request = msg.request, ok = false, error = "Access denied." }); return
    end
    local frame, err = getFrame()
    send(id, { kind = "SCREEN_RESULT", request = msg.request, ok = frame ~= nil, frame = frame, error = err })
  elseif msg.kind == "INPUT" then
    if authorised(msg) then handleInput(id, msg)
    else privacy.log("REMOTE_DENIED", "Rejected input request from computer #" .. tostring(id)) end
  elseif msg.kind == "FILES_LIST" then
    if not authorised(msg) then
      privacy.log("REMOTE_DENIED", "Rejected file-list request from computer #" .. tostring(id))
      send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "Access denied." }); return
    end
    fs.makeDir("/public")
    local ok, entries = pcall(fs.list, "/public")
    if not ok then send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "Could not list /public." })
    else table.sort(entries); send(id, { kind = "FILES_RESULT", request = msg.request, ok = true, entries = entries }) end
  elseif msg.kind == "FILES_GET" then
    if not authorised(msg) then
      privacy.log("REMOTE_DENIED", "Rejected file-read request from computer #" .. tostring(id))
      send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "Access denied." }); return
    end
    local path = safePublicName(msg.name)
    if not path or not fs.exists(path) or fs.isDir(path) then send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "File not found in /public." }); return end
    local f = fs.open(path, "r")
    if not f then send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "Cannot read file." }); return end
    local data = f.readAll(); f.close()
    privacy.log("REMOTE_FILE_READ", "Computer #" .. tostring(id) .. " read a public file")
    if #data > 8192 then send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "Files larger than 8192 bytes cannot be transferred." })
    else send(id, { kind = "FILES_RESULT", request = msg.request, ok = true, name = msg.name, data = data }) end
  elseif msg.kind == "FILES_PUT" then
    if not authorised(msg) then
      privacy.log("REMOTE_DENIED", "Rejected file-write request from computer #" .. tostring(id))
      send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "Access denied." }); return
    end
    local path = safePublicName(msg.name)
    if not path or type(msg.data) ~= "string" or #msg.data > 8192 then send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = "Invalid filename or file exceeds 8192 bytes." }); return end
    fs.makeDir("/public")
    local f, err = fs.open(path, "w")
    if not f then send(id, { kind = "FILES_RESULT", request = msg.request, ok = false, error = tostring(err) }); return end
    f.write(msg.data); f.close()
    privacy.log("REMOTE_FILE_WRITE", "Computer #" .. tostring(id) .. " uploaded a public file")
    send(id, { kind = "FILES_RESULT", request = msg.request, ok = true, name = msg.name })
  elseif msg.kind == "POWER" then
    if not authorised(msg) then
      privacy.log("REMOTE_DENIED", "Rejected power request from computer #" .. tostring(id))
      send(id, { kind = "POWER_RESULT", request = msg.request, ok = false, error = "Access denied." }); return
    end
    if msg.action == "reboot" or msg.action == "shutdown" then
      privacy.log("REMOTE_POWER", "Computer #" .. tostring(id) .. " requested " .. tostring(msg.action))
      send(id, { kind = "POWER_RESULT", request = msg.request, ok = true, message = "Power command accepted." })
      sleep(0.5)
      if msg.action == "reboot" then os.reboot() else os.shutdown() end
    else send(id, { kind = "POWER_RESULT", request = msg.request, ok = false, error = "Unknown power action." }) end
  end
end

function R.run()
  while true do
    local opened = net.open()
    if opened then
      while true do
        local event, a, b, c = os.pullEvent()
        if event == "rednet_message" then
          local id, msg, protocol = a, b, c
          if protocol == net.PROTOCOL and type(msg) == "table" and msg.kind == "DISCOVER" then offer(id)
          elseif protocol == R.PROTOCOL and id ~= os.getComputerID() then handleRemote(id, msg) end
        end
      end
    else os.sleep(4) end
  end
end

return R
