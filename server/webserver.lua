-- HackOS node server. Every CC computer can run this app and host a site.
local ui = require("os.ui")
local net = require("os.network")
local S = {}
local NET, WEB, LEGACY = net.PROTOCOL, net.WEB_PROTOCOL, net.LEGACY_WEB_PROTOCOL
local C = colors

local pages = {
  ["/"] = { title = "HackOS Node", bg = C.white, fg = C.black, lines = {
    { text = "HACKOS NETWORK NODE", color = C.blue },
    { text = "This site is running from a CC:Tweaked computer." },
    { text = "Node address is shown in the browser address bar." },
    { text = "" },
    { link = "System status", to = "/status" },
    { link = "About this node", to = "/about" },
  } },
  ["/status"] = { title = "System status", bg = C.white, fg = C.black, lines = {
    { text = "STATUS: ONLINE", color = C.lime },
    { text = "Service: HackOS Web" },
    { text = "Transport: rednet" },
    { text = "" },
    { link = "Home", to = "/" },
  } },
  ["/about"] = { title = "About", bg = C.white, fg = C.black, lines = {
    { text = "HackOS is an in-game operating environment for CC: Tweaked." },
    { text = "It is a Minecraft roleplay / hobby project, not a real secure government system." },
    { text = "" },
    { link = "Home", to = "/" },
  } },
}

local function notFound(path)
  return { title = "404 - Not Found", bg = C.white, fg = C.black, lines = {
    { text = "404 - PAGE NOT FOUND", color = C.red },
    { text = "The requested path '" .. path .. "' does not exist." },
    { text = "" },
    { link = "Back to home", to = "/" },
  } }
end

local function offer()
  return { kind = "OFFER", version = 1, ip = net.getIP(), hostname = net.getHostname(), services = { "WEB", "DISCOVERY" } }
end

local function cleanPath(path)
  path = tostring(path or "/"):gsub("%?.*$", "")
  path = path:gsub("\\", "/")
  if path == "" then path = "/" end
  if path:sub(1, 1) ~= "/" then path = "/" .. path end
  path = path:gsub("/+$", "")
  if path == "" then path = "/" end
  if path:find("%.%.", 1, false) then return nil end
  return path
end

local function handleRequest(id, req, protocol, log)
  if type(req) ~= "table" then return end
  if req.method == "INFO" then
    rednet.send(id, { domain = net.getHostname(), ip = net.getIP() }, protocol)
    return
  end
  if req.method ~= "GET" then
    rednet.send(id, { status = 405, error = "Method not allowed" }, protocol)
    return
  end
  local path = cleanPath(req.path)
  if not path then
    rednet.send(id, { status = 400, error = "Bad path" }, protocol)
    return
  end
  local page = pages[path]
  rednet.send(id, { status = page and 200 or 404, page = page or notFound(path), ip = net.getIP(), hostname = net.getHostname() }, protocol)
  log[#log + 1] = string.format("#%d GET %s -> %d", id, path, page and 200 or 404)
  while #log > 5 do table.remove(log, 1) end
end

function S.run()
  local ok, err = net.open()
  if not ok then ui.message("HackOS Server", err); return end
  rednet.host(WEB, net.getHostname())
  rednet.host(LEGACY, net.getHostname())
  local log = {}
  local running = true
  while running do
    local w, h = ui.size()
    local T = ui.theme()
    ui.clear(T.bg, T.fg)
    ui.header("HackOS Server Manager", "NODE ONLINE")
    ui.text(2, 3, "SERVER STATUS", T.accent, T.bg)
    ui.text(2, 4, "Hostname : " .. net.getHostname(), T.fg, T.bg)
    ui.text(2, 5, "IPv4     : " .. net.getIP(), T.fg, T.bg)
    ui.text(2, 6, "Computer : #" .. os.getComputerID(), T.fg, T.bg)
    ui.text(2, 7, "Services : HackOS Web / Node Discovery", T.fg, T.bg)
    ui.text(2, 9, "REQUEST LOG", T.accent, T.bg)
    for i = 1, 5 do ui.text(2, 9 + i, ui.pad(log[i] or "Waiting for clients...", w - 3), T.fg, T.bg) end
    ui.text(2, h - 2, "Keep this window open while clients connect.", T.fg, T.bg)
    local stop = ui.button(w - 10, h, "Stop server")
    ui.drawCursor()
    local ev = { os.pullEvent() }
    if ev[1] == "rednet_message" then
      local id, msg, protocol = ev[2], ev[3], ev[4]
      if protocol == NET and type(msg) == "table" and msg.kind == "DISCOVER" then
        rednet.send(id, offer(), NET)
      elseif protocol == WEB or protocol == LEGACY then
        handleRequest(id, msg, protocol, log)
      end
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" and ui.hit(stop, x, y) then running = false end
    end
  end
  rednet.unhost(WEB)
  rednet.unhost(LEGACY)
end

return S
