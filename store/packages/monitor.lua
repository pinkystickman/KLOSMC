-- KL Store: System Monitor
local ui = require("os.ui")
local function readText(path, fallback)
  if not fs.exists(path) then return fallback end
  local f = fs.open(path, "r")
  if not f then return fallback end
  local value = f.readAll():gsub("%s+$", ""); f.close()
  return value ~= "" and value or fallback
end
while true do
  local w, h = ui.size(); local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header("System Monitor", "KL STORE APP")
  ui.text(2, 3, "Edition       " .. readText("/hackos/edition.cfg", "unknown"), T.fg, T.bg)
  ui.text(2, 4, "OS version    " .. readText("/hackos/version.cfg", "unknown"), T.fg, T.bg)
  ui.text(2, 5, "Computer ID   " .. tostring(os.getComputerID()), T.fg, T.bg)
  ui.text(2, 6, "Label         " .. tostring(os.getComputerLabel() or "(not set)"), T.fg, T.bg)
  ui.text(2, 7, "Lua heap      " .. tostring(math.floor(collectgarbage("count"))) .. " KB", T.fg, T.bg)
  ui.text(2, 8, "Runtime       " .. tostring(math.floor(os.clock())) .. " seconds", T.fg, T.bg)
  ui.text(2, 9, "Time          " .. textutils.formatTime(os.time(), true), T.fg, T.bg)
  ui.text(2, 11, "Filesystem    " .. tostring(#fs.list("/")) .. " root entries", T.fg, T.bg)
  local refresh = ui.button(2, h - 2, "Refresh")
  local close = ui.button(w - 8, h - 2, "Close")
  local ev = { os.pullEvent() }
  local kind, x, y = ui.pointer(ev)
  if kind == "click" and (ui.hit(close, x, y) or ui.hit(refresh, x, y)) then
    if ui.hit(close, x, y) then return end
  elseif ev[1] == "key" and ev[2] == keys.escape then return end
end
