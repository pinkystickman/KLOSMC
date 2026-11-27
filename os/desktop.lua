-- HackOS desktop and application launcher.
local ui = require("os.ui")
local net = require("os.network")
local M = {}

local APPS = {
  { name = "Files",     mod = "apps.files",    glyph = "[F]", desc = "Browse and manage files" },
  { name = "Browser",   mod = "apps.browser",  glyph = "[W]", desc = "Browse the HackOS network" },
  { name = "Network",   mod = "apps.network",  glyph = "[N]", desc = "IP address and connected nodes" },
  { name = "Server",    mod = "apps.server",   glyph = "[S]", desc = "Host services on this computer" },
  { name = "Remote",    mod = "apps.remote",   glyph = "[R]", desc = "Remote desktop, shell, files and power management" },
  { name = "Mail",      mod = "apps.mail",      glyph = "[@]", desc = "Send and receive mail over the in-game network" },
  { name = "Hack",      mod = "apps.hack",     glyph = "[H]", desc = "Scan KL OS Standard and remove system files in the exploit lab" },
  { name = "Security",  mod = "apps.security", glyph = "[! ]", desc = "Patch this computer's legacy diagnostic exposure" },
  { name = "Terminal",  mod = "apps.shell",    glyph = "[>]", desc = "Run local CraftOS commands" },
}

local function launch(mod)
  local ok, err = pcall(function() require(mod).run() end)
  if not ok then
    if err == "Terminated" then error(err, 0) end
    ui.message("Application error", tostring(err))
  end
end

local function clock()
  return textutils.formatTime(os.time(), true)
end

local function drawIcon(x, y, icon, name, selected)
  local T = ui.theme()
  local fg = selected and T.selectedfg or colors.white
  local bg = selected and T.selected or T.desktop
  ui.text(x, y, "  " .. icon .. "  ", fg, bg)
  ui.text(x, y + 1, ui.pad(name, 10), fg, bg)
end

function M.run()
  net.open()
  local selected = 1
  local startOpen = false
  while true do
    local w, h = ui.size()
    local T = ui.theme()
    ui.clear(T.desktop, colors.white)

    -- Wallpaper grid and desktop heading.
    for y = 2, h - 2 do
      if y % 2 == 0 then ui.text(1, y, ui.pad(" ", w), colors.white, T.desktop) end
    end
    ui.text(3, 2, "HACKOS", colors.white, T.desktop)
    ui.text(3, 3, "GOVERNMENT EDITION  /  NETWORK DESKTOP", colors.lightGray, T.desktop)

    local cols = math.max(1, math.floor((w - 4) / 13))
    for i, app in ipairs(APPS) do
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local x = 3 + col * 13
      local y = 5 + row * 4
      if y + 1 < h - 2 then drawIcon(x, y, app.glyph, app.name, selected == i) end
    end

    -- Taskbar.
    ui.fill(1, h - 1, w, 2, T.task, T.taskfg)
    local start = ui.button(1, h - 1, "HACKOS")
    ui.text(11, h - 1, "Ready  |  " .. net.getIP(), T.taskfg, T.task)
    local time = clock()
    ui.text(math.max(1, w - #time - 1), h - 1, time, T.taskfg, T.task)
    ui.text(2, h, "Arrows: select  Enter: open  Click: launch  Esc: Start menu", T.taskfg, T.task)

    local menuRects = {}
    if startOpen then
      local mw, mh = math.min(24, w - 2), math.min(#APPS + 2, h - 3)
      local mx, my = 1, h - 2 - mh
      ui.fill(mx, my, mw, mh, colors.lightGray, colors.black)
      ui.fill(mx, my, mw, 1, colors.blue, colors.white)
      ui.text(mx + 1, my, "HackOS Menu", colors.white, colors.blue)
      for i, app in ipairs(APPS) do
        local label = app.glyph .. " " .. app.name
        menuRects[i] = ui.button(mx + 1, my + i, label, selected == i)
      end
      menuRects.exit = ui.button(mx + 1, my + #APPS + 1, "Exit HackOS")
    end

    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(#APPS, selected + 1)
      elseif ev[2] == keys.left then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.right then selected = math.min(#APPS, selected + 1)
      elseif ev[2] == keys.enter then launch(APPS[selected].mod)
      elseif ev[2] == keys.escape then startOpen = not startOpen end
    end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(start, x, y) then startOpen = not startOpen
      elseif startOpen then
        for i, rect in ipairs(menuRects) do
          if ui.hit(rect, x, y) then selected = i; launch(APPS[i].mod); startOpen = false end
        end
        if ui.hit(menuRects.exit, x, y) then return end
      else
        for i = 1, #APPS do
          local col = (i - 1) % math.max(1, math.floor((w - 4) / 13))
          local row = math.floor((i - 1) / math.max(1, math.floor((w - 4) / 13)))
          local ix, iy = 3 + col * 13, 5 + row * 4
          if x >= ix and x <= ix + 10 and y >= iy and y <= iy + 1 then selected = i; launch(APPS[i].mod) end
        end
      end
    end
  end
end

return M
