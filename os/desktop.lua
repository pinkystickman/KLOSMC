-- HackOS Government desktop: Windows 11-inspired taskbar, Start menu and context menu.
local ui = require("os.ui")
local net = require("os.network")
local M = {}

local APPS = {
  { name="Files", mod="apps.files", glyph="F", desc="Browse, run and manage files" },
  { name="Browser", mod="apps.browser", glyph="B", desc="Browse websites on the in-game network" },
  { name="Terminal", mod="apps.shell", glyph="T", desc="Run CraftOS commands and Lua scripts" },
  { name="Website Studio", mod="apps.site", glyph="E", desc="Create, edit and publish your own website" },
  { name="Server", mod="apps.server", glyph="S", desc="Host your website on this computer" },
  { name="Network", mod="apps.network", glyph="N", desc="IP address and connected computers" },
  { name="Remote", mod="apps.remote", glyph="R", desc="Remote desktop and multi-PC administration" },
  { name="Mail", mod="apps.mail", glyph="M", desc="Internal network email" },
  { name="Hack", mod="apps.hack", glyph="H", desc="Minecraft-only KL OS exploit lab" },
  { name="Security", mod="apps.security", glyph="C", desc="Local security and diagnostic settings" },
  { name="OS Update", mod="apps.update", glyph="U", desc="Download and install OS updates" },
}

local function appError(err)
  return err == "Terminated" or err == "__KL_WINDOW_CLOSE" or err == "__KL_WINDOW_MINIMIZE"
end

local function launch(app)
  ui.setAppWindow(true, app.name)
  local ok, err = pcall(function() require(app.mod).run() end)
  ui.setAppWindow(false)
  if not ok and not appError(err) then ui.message("Application error", tostring(err)) end
end

local function clock()
  return textutils.formatTime(os.time(), true)
end

local function createFile(kind)
  fs.makeDir("/Documents")
  fs.makeDir("/www")
  if kind == "folder" then
    local name = ui.input("New folder", "Folder name in /Documents:", "New Folder")
    if not name or name == "" or name:find("[/\\]", 1) or name == ".." then return end
    local path = fs.combine("/Documents", name)
    if fs.exists(path) then ui.message("Create folder", "That name already exists."); return end
    fs.makeDir(path); ui.message("Folder created", path); return
  end

  local prompt = kind == "lua" and "Lua script name (without extension):" or
    kind == "html" and "Website page name (without extension):" or "Text document name (without extension):"
  local name = ui.input("Create file", prompt, kind == "html" and "new-page" or "New File")
  if not name or name == "" or name:find("[/\\]", 1) or name == ".." then return end
  local ext = kind == "lua" and ".lua" or kind == "html" and ".html" or ".txt"
  name = name:gsub("%.[%w]+$", "") .. ext
  local path = kind == "html" and fs.combine("/www", name) or fs.combine("/Documents", name)
  if fs.exists(path) then ui.message("Create file", "That file already exists: " .. path); return end
  local content = kind == "lua" and "-- New HackOS Lua script\nprint(\"Hello from HackOS!\")\n" or
    kind == "html" and "<!doctype html>\n<html>\n<head>\n  <title>My website</title>\n</head>\n<body>\n  <h1>Welcome!</h1>\n  <p>This page is hosted by my CC:Tweaked computer.</p>\n  <p><a href=\"/about.html\">About this site</a></p>\n</body>\n</html>\n" or "New text document\n"
  local f, err = fs.open(path, "w")
  if not f then ui.message("Create file failed", tostring(err)); return end
  f.write(content); f.close()
  ui.message("File created", "Created " .. path .. "\nOpen Files to edit or run it.")
end

local function drawDesktop(startOpen, context, selected, status)
  local w, h = ui.size()
  local T = ui.theme()
  ui.clear(T.desktop, colors.white)
  ui.fill(1, 1, w, h - 1, T.desktop, colors.white, " ")
  -- Soft Windows-like bands, made from the terminal palette.
  ui.fill(1, 1, w, 4, colors.blue, colors.white, " ")
  ui.text(3, 2, "HACKOS", colors.white, colors.blue)
  ui.text(3, 3, "GOVERNMENT EDITION", colors.lightBlue, colors.blue)
  ui.text(3, 5, "Your computer. Your network. Your workspace.", colors.white, T.desktop)
  ui.text(3, 7, "Right-click anywhere to create a file or folder.", colors.lightGray, T.desktop)
  ui.text(3, 8, "Open apps from the taskbar or Start menu.", colors.lightGray, T.desktop)
  if status and status ~= "" then ui.text(3, h - 2, status, colors.white, T.desktop) end

  -- Taskbar: all app shortcuts live here, never on the desktop.
  ui.fill(1, h, w, 1, T.task, T.taskfg)
  local start = ui.button(1, h, "Start", startOpen)
  local x = 9
  local maxPins = math.max(0, math.floor((w - 16) / 3))
  local pins = {}
  for i = 1, math.min(#APPS, maxPins) do
    pins[i] = ui.button(x, h, APPS[i].glyph, selected == i)
    x = x + 3
  end
  ui.text(math.max(x + 1, w - 9), h, clock(), T.taskfg, T.task)

  local menu = {}
  if startOpen then
    local mw = math.min(30, w - 2)
    local mh = math.min(#APPS + 3, h - 3)
    local mx, my = 2, h - mh - 1
    ui.fill(mx, my, mw, mh, T.panel, T.panelfg)
    ui.fill(mx, my, mw, 1, colors.blue, colors.white)
    ui.text(mx + 1, my, "HackOS  |  Start", colors.white, colors.blue)
    for i, app in ipairs(APPS) do
      local y = my + i
      if y < h then
        local label = app.glyph .. "  " .. app.name
        menu[i] = ui.button(mx + 1, y, label, selected == i)
      end
    end
    ui.text(mx + 1, math.min(h - 1, my + #APPS + 1), "v2.5.0  |  Power: Q", T.fg, T.panel)
  end

  local contextRects = {}
  if context then
    local labels = { "New folder", "Text document", "Lua script", "Website page", "Open Files", "Refresh" }
    local mw, mh = 22, #labels
    local mx = math.max(1, math.min(context.x, w - mw + 1))
    local my = math.max(1, math.min(context.y, h - mh - 1))
    ui.fill(mx, my, mw, mh, T.panel, T.panelfg)
    for i, label in ipairs(labels) do contextRects[i] = ui.button(mx + 1, my + i - 1, label, false) end
  end
  return { start = start, pins = pins, menu = menu, context = contextRects }
end

function M.run()
  net.open()
  fs.makeDir("/Documents"); fs.makeDir("/www")
  local selected, startOpen, context = 1, false, nil
  local status = "Ready  |  " .. net.getIP()
  while true do
    local rects = drawDesktop(startOpen, context, selected, status)
    local _, h = ui.size()
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(#APPS, selected + 1)
      elseif ev[2] == keys.enter then launch(APPS[selected]); startOpen = false; context = nil
      elseif ev[2] == keys.escape then startOpen = not startOpen; context = nil
      elseif ev[2] == keys.q then return
      elseif ev[2] == keys.n then context = { x = 3, y = 4 } end
    elseif ev[1] == "mouse_click" then
      local button, x, y = ev[2], ev[3], ev[4]
      if button == 2 then context = { x = x, y = y }; startOpen = false
      elseif button == 1 then
        if context then
          local actions = rects.context
          local action
          for i, r in ipairs(actions) do if ui.hit(r, x, y) then action = i; break end end
          context = nil
          if action == 1 then createFile("folder")
          elseif action == 2 then createFile("text")
          elseif action == 3 then createFile("lua")
          elseif action == 4 then createFile("html")
          elseif action == 5 then launch(APPS[1])
          elseif action == 6 then status = "Desktop refreshed at " .. clock() end
        elseif ui.hit(rects.start, x, y) then startOpen = not startOpen
        elseif startOpen then
          local chosen
          for i, r in ipairs(rects.menu) do if ui.hit(r, x, y) then chosen = i; break end end
          if chosen then selected = chosen; launch(APPS[chosen]); startOpen = false
          elseif y < h - 1 then startOpen = false end
        else
          for i, r in ipairs(rects.pins) do
            if ui.hit(r, x, y) then selected = i; launch(APPS[i]); break end
          end
        end
      end
    end
  end
end

return M
