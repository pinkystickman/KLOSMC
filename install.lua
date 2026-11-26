-- HackOS installer. Run with: wget .../install.lua install.lua ; install.lua
local BASE_URL = "https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/"
local VERSION = "2.0.0"

local function theme()
  local colour = term.isColor()
  return {
    bg = colour and colors.lightGray or colors.black,
    fg = colour and colors.black or colors.white,
    title = colour and colors.blue or colors.gray,
    accent = colour and colors.cyan or colors.white,
    good = colour and colors.lime or colors.white,
    bad = colour and colors.red or colors.white,
    bar = colour and colors.gray or colors.gray,
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
  text(2, 1, "HACKOS  /  INSTALLER", colors.white, T.title)
  text(2, 3, title or "HackOS Setup", T.fg, T.bg)
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
  local body = response.readAll()
  response.close()
  return body
end

local function progress(i, total, label)
  local w, h = term.getSize()
  local bw = math.max(8, w - 8)
  local filled = math.floor(bw * i / math.max(1, total))
  text(2, 7, label, T.fg, T.bg)
  fill(9, T.bg, T.fg)
  text(2, 9, "[" .. ("#"):rep(filled) .. ("-"):rep(math.max(0, bw - filled)) .. "]", T.accent, T.bg)
  text(2, 10, tostring(i) .. " / " .. tostring(total), T.fg, T.bg)
end

local function install()
  if not http then error("HTTP API is disabled. Enable http in the CC:Tweaked server configuration.", 0) end
  draw("Downloading system manifest", "Source: github.com/pinkystickman/KLOSMC  |  " .. VERSION)
  local raw, err = get("manifest.json")
  if not raw then error("Could not download manifest.json: " .. tostring(err), 0) end
  local manifest = textutils.unserialiseJSON(raw)
  if type(manifest) ~= "table" or type(manifest.files) ~= "table" or #manifest.files == 0 then
    error("The GitHub manifest is invalid or empty.", 0)
  end

  local data, total = {}, #manifest.files
  for i, path in ipairs(manifest.files) do
    if not safePath(path) then error("Unsafe file path in manifest: " .. tostring(path), 0) end
    progress(i - 1, total, "Downloading " .. path)
    local body, why = get(path)
    if not body then error("Download failed for " .. path .. ": " .. tostring(why), 0) end
    data[path] = body
  end

  draw("Installing HackOS", "Writing system files...")
  local startupBackup = false
  if fs.exists("startup.lua") then
    local f = fs.open("startup.lua", "r")
    local current = f and f.readAll() or ""
    if f then f.close() end
    if not current:find("HackOS", 1, true) then
      if fs.exists("startup.lua.bak") then fs.delete("startup.lua.bak") end
      fs.copy("startup.lua", "startup.lua.bak")
      startupBackup = true
    end
  end

  local paths = {}
  for path in pairs(data) do paths[#paths + 1] = path end
  table.sort(paths)
  for i, path in ipairs(paths) do
    progress(i - 1, #paths, "Writing " .. path)
    local dir = fs.getDir(path)
    if dir ~= "" then fs.makeDir(dir) end
    local f, why = fs.open(path, "w")
    if not f then error("Cannot write " .. path .. ": " .. tostring(why), 0) end
    f.write(data[path]); f.close()
  end
  progress(#paths, #paths, "Finishing installation")
  draw("Installation complete", "HackOS " .. VERSION .. " is ready.")
  text(2, 6, "System files installed successfully.", T.good, T.bg)
  if startupBackup then text(2, 7, "Previous startup.lua saved as startup.lua.bak", T.fg, T.bg) end
  text(2, 9, "The computer will reboot into HackOS.", T.fg, T.bg)
  sleep(2)
  os.reboot()
end

if not http then errorScreen("HTTP API is disabled. Enable it in the CC:Tweaked configuration."); return end

draw("Welcome to HackOS Setup", "A graphical installer for the HackOS operating environment.")
text(2, 6, "This will download the latest files from the configured GitHub repository.", T.fg, T.bg)
text(2, 8, "Requirements: HTTP enabled and a modem is recommended for networking.", T.fg, T.bg)

local function button(x, y, label, selected, fg)
  local value = "  " .. label .. "  "
  local bg = selected and T.accent or T.title
  text(x, y, value, fg or colors.white, bg)
  return { x1 = x, y1 = y, x2 = x + #value - 1, y2 = y }
end

local selected = 1
while true do
  local installButton = button(2, 10, "Install HackOS", selected == 1, T.good)
  local cancelButton = button(23, 10, "Cancel", selected == 2, T.fg)
  local event, a, b, c = os.pullEvent()
  if event == "key" then
    if a == keys.left or a == keys.right or a == keys.tab then
      selected = selected == 1 and 2 or 1
    elseif a == keys.enter or a == keys.space then
      if selected == 1 then
        local ok, err = pcall(install)
        if not ok then errorScreen(err) end
        return
      else
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
        term.clear(); term.setCursorPos(1, 1)
        print("HackOS setup cancelled.")
        return
      end
    elseif a == keys.q or a == keys.escape then
      term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
      term.clear(); term.setCursorPos(1, 1)
      print("HackOS setup cancelled.")
      return
    end
  elseif event == "mouse_click" and a == 1 then
    local x, y = b, c
    local function hit(rect)
      return x >= rect.x1 and x <= rect.x2 and y == rect.y1
    end
    if hit(installButton) then
      local ok, err = pcall(install)
      if not ok then errorScreen(err) end
      return
    elseif hit(cancelButton) then
      term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
      term.clear(); term.setCursorPos(1, 1)
      print("HackOS setup cancelled.")
      return
    end
  end
end
