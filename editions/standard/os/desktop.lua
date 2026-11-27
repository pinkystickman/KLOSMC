-- KL OS Standard desktop: familiar Windows-style icons, Start menu and taskbar.
local ui = require("os.ui")
local M = {}
local APPS = {
  { name = "Files", mod = "apps.files", glyph = "[F]" },
  { name = "Shell", mod = "apps.shell", glyph = "[>]" },
  { name = "Browser", mod = "apps.browser", glyph = "[W]" },
  { name = "Network", mod = "apps.network", glyph = "[N]" },
  { name = "Security", mod = "apps.security", glyph = "[S]" },
  { name = "Remote", mod = "apps.remote", glyph = "[R]" },
  { name = "Mail", mod = "apps.mail", glyph = "[@]" },
}
local function launch(mod)
  local ok, err = pcall(function() require(mod).run() end)
  if not ok then if err == "Terminated" then error(err, 0) end; ui.message("Application error", tostring(err)) end
end
local function drawIcon(x, y, glyph, name, selected)
  local T = ui.theme()
  ui.text(x, y, "  " .. glyph .. "  ", selected and T.selectedfg or colors.white, selected and T.selected or T.desktop)
  ui.text(x, y + 1, ui.pad(name, 10), selected and T.selectedfg or colors.white, selected and T.selected or T.desktop)
end
local function clock() return textutils.formatTime(os.time(), true) end
function M.run()
  local selected, startOpen = 1, false
  while true do
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.desktop, colors.white)
    ui.fill(1, 1, w, h - 2, T.desktop, colors.white)
    ui.text(3, 2, "KL OS", colors.white, T.desktop)
    ui.text(3, 3, "STANDARD EDITION", colors.lightGray, T.desktop)
    local cols = math.max(1, math.floor((w - 4) / 13))
    local iconRects = {}
    for i, app in ipairs(APPS) do
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      local x, y = 3 + col * 13, 5 + row * 4
      if y + 1 < h - 2 then
        drawIcon(x, y, app.glyph, app.name, selected == i)
        iconRects[i] = { x1 = x, y1 = y, x2 = x + 10, y2 = y + 1 }
      end
    end
    ui.fill(1, h - 1, w, 2, T.task, T.taskfg)
    local start = ui.button(1, h - 1, "Start", startOpen)
    ui.text(10, h - 1, "KL OS  |  Ready", T.taskfg, T.task)
    local tm = clock(); ui.text(math.max(1, w - #tm - 1), h - 1, tm, T.taskfg, T.task)
    ui.text(2, h, "Arrows: select  Enter: open  Click: launch  Esc: Start menu", T.taskfg, T.task)
    local menu, exitRect
    if startOpen then
      local mw, mh = math.min(25, w - 2), math.min(#APPS + 2, h - 3)
      local mx, my = 1, h - 2 - mh
      ui.fill(mx, my, mw, mh, T.bg, T.fg); ui.fill(mx, my, mw, 1, T.bar, T.barfg)
      ui.text(mx + 1, my, "KL OS Programs", T.barfg, T.bar)
      menu = {}
      for i, app in ipairs(APPS) do menu[i] = ui.button(mx + 1, my + i, app.glyph .. " " .. app.name, selected == i) end
      exitRect = ui.button(mx + 1, my + #APPS + 1, "Exit to CraftOS")
    end
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up or ev[2] == keys.left then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down or ev[2] == keys.right then selected = math.min(#APPS, selected + 1)
      elseif ev[2] == keys.enter then launch(APPS[selected].mod)
      elseif ev[2] == keys.escape then startOpen = not startOpen
      elseif ev[2] == keys.q then return end
    elseif ev[1] == "mouse_click" and ev[2] == 1 then
      local x, y = ev[3], ev[4]
      if ui.hit(start, x, y) then startOpen = not startOpen
      elseif startOpen then
        local done = false
        for i, rect in ipairs(menu or {}) do if ui.hit(rect, x, y) then selected = i; launch(APPS[i].mod); startOpen = false; done = true; break end end
        if not done and ui.hit(exitRect, x, y) then return end
      else
        for i, rect in ipairs(iconRects) do if ui.hit(rect, x, y) then selected = i; launch(APPS[i].mod); break end end
      end
    end
  end
end
return M
