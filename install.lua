-- KL OS / HackOS edition installer. Run: wget <repo>/install.lua install.lua ; install.lua
local BASE_URL = "https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/"
local VERSION = "2.9.0"

local function theme()
  local colour = term.isColor()
  return {
    bg = colour and colors.lightGray or colors.black,
    fg = colour and colors.black or colors.white,
    title = colour and colors.blue or colors.gray,
    accent = colour and colors.cyan or colors.white,
    good = colour and colors.lime or colors.white,
    bad = colour and colors.red or colors.white,
    bar = colors.gray,
  }
end

local T = theme()
local function fill(y, bg, fg, char)
  local w = term.getSize()
  term.setCursorPos(1, y); term.setBackgroundColor(bg); term.setTextColor(fg)
  term.write((char or " "):rep(w))
end
local function text(x, y, value, fg, bg)
  local w = term.getSize()
  if y < 1 then return end
  term.setCursorPos(x, y); term.setTextColor(fg or T.fg); term.setBackgroundColor(bg or T.bg)
  term.write(tostring(value):sub(1, math.max(0, w - x + 1)))
end
local function draw(title, subtitle)
  term.setBackgroundColor(T.bg); term.setTextColor(T.fg); term.clear()
  fill(1, T.title, colors.white)
  text(2, 1, "KL OS  /  HACKOS SETUP", colors.white, T.title)
  text(2, 3, title or "System Setup", T.fg, T.bg)
  if subtitle then text(2, 4, subtitle, T.fg, T.bg) end
end
local function waitKey()
  while true do
    local e, k = os.pullEvent("key")
    if k == keys.enter or k == keys.space then return end
  end
end
local function errorScreen(message)
  draw("Installation failed", "The system was not installed.")
  local lines = require("cc.strings").wrap(tostring(message), math.max(10, term.getSize() - 4))
  for i, line in ipairs(lines) do text(2, 6 + i, line, T.bad, T.bg) end
  text(2, term.getSize() - 1, "Press Enter to return to CraftOS", T.accent, T.bg)
  waitKey()
end
local function safePath(path)
  return type(path) == "string" and path ~= "" and not path:match("^/") and not path:find("..", 1, true) and not path:find("\\", 1, true)
end
local function get(path)
  local response, err = http.get(BASE_URL .. path)
  if not response then return nil, err end
  local body = response.readAll(); response.close()
  return body
end
local function progress(i, total, label)
  local w = term.getSize()
  local bw = math.max(8, w - 8)
  local filled = math.floor(bw * i / math.max(1, total))
  text(2, 7, label, T.fg, T.bg)
  text(2, 9, "[" .. ("#"):rep(filled) .. ("-"):rep(math.max(0, bw - filled)) .. "]", T.accent, T.bg)
  text(2, 10, tostring(i) .. " / " .. tostring(total), T.fg, T.bg)
end
local function button(x, y, label, selected, width)
  local value = "  " .. label .. "  "
  if width then value = (value .. (" "):rep(width)):sub(1, width) end
  local bg = selected and T.accent or T.title
  text(x, y, value, colors.white, bg)
  return { x1 = x, y1 = y, x2 = x + #value - 1, y2 = y }
end

local function install(editionKey)
  if not http then error("HTTP API is disabled. Enable http in the CC:Tweaked server configuration.", 0) end
  draw("Reading edition manifest", "Source: github.com/pinkystickman/KLOSMC  |  " .. VERSION)
  local raw, err = get("manifest.json")
  if not raw then error("Could not download manifest.json: " .. tostring(err), 0) end
  local manifest = textutils.unserializeJSON(raw)
  if type(manifest) ~= "table" or type(manifest.editions) ~= "table" then error("The edition manifest is invalid.", 0) end
  local edition = manifest.editions[editionKey]
  if type(edition) ~= "table" or type(edition.files) ~= "table" or #edition.files == 0 then
    error("The selected edition is missing from the manifest.", 0)
  end

  local data, total = {}, #edition.files
  local protectedSecurityPreserved = false
  for i, item in ipairs(edition.files) do
    local source, target, channel
    if type(item) == "string" then source, target = item, item
    elseif type(item) == "table" then source, target, channel = item.source, item.target, item.channel end
    if not safePath(source) or not safePath(target) then error("Unsafe file entry in manifest: " .. tostring(source), 0) end
    if (channel == "security" or target == "security.lua") and fs.exists("/security.lua") then
      protectedSecurityPreserved = true
    else
      progress(i - 1, total, "Downloading " .. source)
      local body, why = get(source)
      if not body then error("Download failed for " .. source .. ": " .. tostring(why), 0) end
      data[target] = body
    end
  end

  draw("Installing " .. edition.name, "Writing system files...")
  local startupBackup = false
  if fs.exists("startup.lua") then
    local f = fs.open("startup.lua", "r")
    local current = f and f.readAll() or ""
    if f then f.close() end
    if not current:find("KL OS / HackOS dual-edition startup", 1, true) then
      if fs.exists("startup.lua.bak") then fs.delete("startup.lua.bak") end
      fs.copy("startup.lua", "startup.lua.bak")
      startupBackup = true
    end
  end

  local paths = {}
  for path in pairs(data) do paths[#paths + 1] = path end
  table.sort(paths)
  -- Save a clean recovery copy before replacing the live operating-system files.
  -- Keep the existing protected security core in the recovery image even though
  -- the installer deliberately skips writing it during an upgrade.
  fs.makeDir("/hackos/recovery/files")
  local recoveryPaths = {}
  for _, path in ipairs(paths) do
    local backup = fs.combine("/hackos/recovery/files", path)
    local backupDir = fs.getDir(backup); if backupDir ~= "" then fs.makeDir(backupDir) end
    local bf, be = fs.open(backup, "w")
    if not bf then error("Cannot write recovery backup for " .. path .. ": " .. tostring(be), 0) end
    bf.write(data[path]); bf.close()
    recoveryPaths[#recoveryPaths + 1] = path
  end
  if fs.exists("/security.lua") then
    local present = false
    for _, path in ipairs(recoveryPaths) do if path == "security.lua" then present = true; break end end
    if not present then
      local recoverySecurity = "/hackos/recovery/files/security.lua"
      if fs.exists(recoverySecurity) then fs.delete(recoverySecurity) end
      local copied, copyErr = pcall(fs.copy, "/security.lua", recoverySecurity)
      if not copied then error("Cannot preserve protected security recovery file: " .. tostring(copyErr), 0) end
      recoveryPaths[#recoveryPaths + 1] = "security.lua"
    end
  end
  table.sort(recoveryPaths)
  local indexFile, indexErr = fs.open("/hackos/recovery/index.json", "w")
  if not indexFile then error("Cannot write recovery index: " .. tostring(indexErr), 0) end
  indexFile.write(textutils.serialiseJSON({ version = VERSION, edition = editionKey, paths = recoveryPaths }))
  indexFile.close()

  for i, path in ipairs(paths) do
    progress(i - 1, #paths, "Writing " .. path)
    local dir = fs.getDir(path)
    if dir ~= "" then fs.makeDir(dir) end
    local f, why = fs.open(path, "w")
    if not f then error("Cannot write " .. path .. ": " .. tostring(why), 0) end
    f.write(data[path]); f.close()
  end
  fs.makeDir("/hackos")
  local cfg, cfgErr = fs.open("/hackos/edition.cfg", "w")
  if not cfg then error("Cannot save edition selection: " .. tostring(cfgErr), 0) end
  cfg.write(editionKey); cfg.close()
  local vf, vfErr = fs.open("/hackos/version.cfg", "w")
  if not vf then error("Cannot save version metadata: " .. tostring(vfErr), 0) end
  vf.write(VERSION .. "\n"); vf.close()

  progress(#paths, #paths, "Finishing installation")
  draw("Installation complete", edition.name .. " is ready.")
  text(2, 6, "System files installed successfully.", T.good, T.bg)
  if startupBackup then text(2, 7, "Previous startup.lua saved as startup.lua.bak", T.fg, T.bg) end
  if protectedSecurityPreserved then text(2, 8, "Existing /security.lua was preserved. Use Antivirus for security patches.", T.good, T.bg) end
  text(2, 10, "The computer will reboot into " .. edition.name .. ".", T.fg, T.bg)
  sleep(2)
  os.reboot()
end

if not http then errorScreen("HTTP API is disabled. Enable it in the CC:Tweaked configuration."); return end

local selected = "standard"
local function chooseScreen()
  while true do
    draw("Choose your edition", "Select the operating system for this computer.")
    local std = button(2, 6, "STANDARD / KL OS", selected == "standard", 22)
    text(2, 7, "KL OS desktop with Files, KL Store, KL Maker, Browser, Mail, Website Hosting and Security & Privacy.", T.fg, T.bg)
    local gov = button(2, 9, "GOVERNMENT / HACKOS", selected == "government", 24)
    text(2, 10, "Windows-style desktop, KL Store, KL Maker, network tools, Remote Center, Mail and Security & Privacy.", T.fg, T.bg)
    text(2, 11, "Live Remote Desktop, mouse/keyboard control, shared files, multi-PC tools, Hack Console and internal Mail.", T.fg, T.bg)
    text(2, 13, "Remote administration requires consent; the in-game KL OS exploit lab is limited to KL OS Standard system files.", T.good, T.bg)
    local _, h = term.getSize()
    local go = button(2, h - 2, "Install selected edition", true)
    local cancel = button(30, h - 2, "Cancel", false)
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up or ev[2] == keys.down then
        selected = selected == "standard" and "government" or "standard"
      elseif ev[2] == keys.one then selected = "standard"
      elseif ev[2] == keys.two then selected = "government"
      elseif ev[2] == keys.enter or ev[2] == keys.space then return selected
      elseif ev[2] == keys.q or ev[2] == keys.escape then return nil end
    elseif ev[1] == "mouse_click" and ev[2] == 1 then
      local x, y = ev[3], ev[4]
      local function hit(r) return x >= r.x1 and x <= r.x2 and y == r.y1 end
      if hit(std) then selected = "standard"
      elseif hit(gov) then selected = "government"
      elseif hit(go) then return selected
      elseif hit(cancel) then return nil end
    end
  end
end

local editionKey = chooseScreen()
if not editionKey then
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
  term.clear(); term.setCursorPos(1, 1); print("Setup cancelled.")
  return
end
local ok, err = pcall(install, editionKey)
if not ok then errorScreen(err) end
