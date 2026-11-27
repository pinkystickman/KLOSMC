-- KL OS desktop / launcher
local ui = require("os.ui")
local M = {}

local APPS = {
  { name = "Files",   mod = "apps.files" },
  { name = "Shell",   mod = "apps.shell" },
  { name = "Browser", mod = "apps.browser" },
  { name = "Security", mod = "apps.security" },
  { name = "Remote", mod = "apps.remote" },
  { name = "Mail", mod = "apps.mail" },
}

local function launch(mod)
  local ok, err = pcall(function() require(mod).run() end)
  if not ok then
    if err == "Terminated" then error(err, 0) end
    ui.message("App crashed", tostring(err))
  end
end

local function update()
  if not http then ui.message("Update OS", "The HTTP API is disabled on this server.") return end
  ui.clear()
  shell.run("/install.lua") -- reboots on success
  print() print("Press any key...")
  os.pullEvent("key")
end

function M.run()
  local timer = os.startTimer(1)
  while true do
    local w, h = ui.size()
    local T = ui.theme()
    ui.clear(T.bg)
    ui.header("KL OS", textutils.formatTime(os.time(), true))
    ui.text(2, 3, "Apps", T.accent, T.bg)
    local rects = {}
    for i, a in ipairs(APPS) do
      rects[i] = ui.button(2, 3 + i * 2, ui.pad(a.name, 14))
    end
    local upd = ui.button(2, h - 1, "Update OS")
    local ext = ui.button(14, h - 1, "Exit")
    ui.text(1, h, ui.pad(" Arrows move +, Enter clicks", w), T.fg, T.bg)
    ui.drawCursor()

    local ev = { os.pullEvent() }
    if ev[1] == "timer" and ev[2] == timer then timer = os.startTimer(1) end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      for i, a in ipairs(APPS) do
        if ui.hit(rects[i], x, y) then
          launch(a.mod)
          timer = os.startTimer(1)
          break
        end
      end
      if ui.hit(upd, x, y) then update()
      elseif ui.hit(ext, x, y) then return end
    end
  end
end

return M
