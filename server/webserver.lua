-- Persistent rednet website host. Pages are read from /www and served to KL Browser / HackOS Browser.
local ui = require("os.ui")
local net = require("os.network")
local Site = require("os.site")
local privacy = require("os.privacy")
local S = {}
local WEB, LEGACY = net.WEB_PROTOCOL, net.LEGACY_WEB_PROTOCOL
local CFG = "/hackos/web.cfg"

local function readConfig()
  fs.makeDir("/hackos")
  local cfg = { enabled = false, domain = net.getHostname() .. ".cc" }
  if fs.exists(CFG) then
    local f = fs.open(CFG, "r")
    if f then
      local saved = textutils.unserializeJSON(f.readAll()); f.close()
      if type(saved) == "table" then
        cfg.enabled = saved.enabled == true
        if type(saved.domain) == "string" and saved.domain:match("^[%w%-%.]+$") and #saved.domain <= 48 then cfg.domain = saved.domain:lower() end
      end
    end
  end
  return cfg
end

local function saveConfig(cfg)
  fs.makeDir("/hackos")
  local f, err = fs.open(CFG, "w")
  if not f then return false, err end
  f.write(textutils.serialiseJSON(cfg)); f.close()
  return true
end

function S.getConfig()
  local cfg = readConfig()
  return cfg.enabled, cfg.domain
end

function S.setEnabled(enabled)
  local cfg = readConfig(); cfg.enabled = not not enabled
  local ok, err = saveConfig(cfg)
  if ok then privacy.log("WEBSITE_HOSTING", cfg.enabled and "enabled" or "disabled") end
  return ok, err
end

function S.setDomain(domain)
  domain = tostring(domain or ""):lower()
  if #domain < 1 or #domain > 48 or not domain:match("^[%w%-%.]+$") then return false, "Domain can contain letters, numbers, dots and hyphens." end
  local cfg = readConfig(); cfg.domain = domain
  return saveConfig(cfg)
end

local function notFound(path)
  return { title = "404 - Not Found", bg = colors.white, fg = colors.black, lines = {
    { text = "404 - PAGE NOT FOUND", color = colors.red },
    { text = "The page " .. tostring(path) .. " does not exist on this site." },
    { text = "" }, { link = "Back to home", to = "/" },
  } }
end

local function offer(cfg)
  return { kind = "OFFER", version = 2, ip = net.getIP(), hostname = net.getHostname(),
    services = { "WEB", "DISCOVERY" }, webDomain = cfg.domain }
end

local function handleRequest(id, req, protocol)
  if type(req) ~= "table" then return end
  local cfg = readConfig()
  if req.method == "INFO" then
    rednet.send(id, { domain = cfg.domain, ip = net.getIP(), hostname = net.getHostname() }, protocol)
    return
  end
  if req.method ~= "GET" then
    rednet.send(id, { status = 405, error = "Method not allowed" }, protocol)
    return
  end
  local page, err = Site.readPage(req.path or "/")
  local status = page and 200 or 404
  if not page then page = notFound(req.path or "/") end
  rednet.send(id, { status = status, page = page, ip = net.getIP(), hostname = cfg.domain, error = err }, protocol)
end

function S.service()
  Site.ensureFiles()
  local active, activeDomain = false, nil
  while true do
    local opened = net.open()
    if not opened then
      if active then rednet.unhost(WEB); rednet.unhost(LEGACY); active = false; activeDomain = nil end
      os.sleep(3)
    else
      local cfg = readConfig()
      if cfg.enabled and (not active or activeDomain ~= cfg.domain) then
        if active then rednet.unhost(WEB); rednet.unhost(LEGACY) end
        rednet.host(WEB, cfg.domain)
        rednet.host(LEGACY, cfg.domain)
        active, activeDomain = true, cfg.domain
      elseif not cfg.enabled and active then
        rednet.unhost(WEB); rednet.unhost(LEGACY)
        active, activeDomain = false, nil
      end

      local ev = { os.pullEvent() }
      if active and ev[1] == "rednet_message" then
        local id, msg, protocol = ev[2], ev[3], ev[4]
        if protocol == net.PROTOCOL and type(msg) == "table" and msg.kind == "DISCOVER" and privacy.get("network_discovery") then
          rednet.send(id, offer(cfg), net.PROTOCOL)
        elseif protocol == WEB or protocol == LEGACY then
          handleRequest(id, msg, protocol)
        end
      end
    end
  end
end

function S.run()
  Site.ensureFiles()
  while true do
    local enabled, domain = S.getConfig()
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.bg, T.fg); ui.header("Website Server", "REDNET HOST")
    ui.text(2, 3, "Website folder : /www", T.accent, T.bg)
    ui.text(2, 4, "Domain         : " .. domain, T.fg, T.bg)
    ui.text(2, 5, "Server         : " .. (enabled and "ONLINE" or "OFFLINE"), enabled and T.good or T.bad, T.bg)
    ui.text(2, 7, "The OS background service serves your HTML pages.", T.fg, T.bg)
    ui.text(2, 8, "Edit pages in Website Studio while hosting stays online.", T.fg, T.bg)
    ui.text(2, 9, "Supported HTML: title, headings, paragraphs, links and line breaks.", T.fg, T.bg)
    local toggle = ui.button(2, h - 4, enabled and "Stop hosting" or "Start hosting")
    local setDomain = ui.button(2, h - 2, "Set domain")
    local studio = ui.button(17, h - 2, "Website Studio")
    local back = ui.button(w - 8, h - 2, "Back")
    local ev = { os.pullEvent() }
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(toggle, x, y) then local ok, err = S.setEnabled(not enabled); if not ok then ui.message("Server", tostring(err)) end
      elseif ui.hit(setDomain, x, y) then
        local value = ui.input("Set website domain", "Example: mysite.cc", domain)
        if value and value ~= "" then local ok, err = S.setDomain(value); if not ok then ui.message("Invalid domain", tostring(err)) end end
      elseif ui.hit(studio, x, y) then require("apps.site").run()
      elseif ui.hit(back, x, y) then return end
    elseif ev[1] == "key" and ev[2] == keys.escape then return end
  end
end

return S
