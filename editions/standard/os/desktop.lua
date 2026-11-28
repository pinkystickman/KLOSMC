-- KL OS Standard desktop with KL Store, KL Maker and installed-app shortcuts.
local ui = require("os.ui")
local Registry = require("os.appregistry")
local M = {}

local BUILT_IN = {
  { name="Files", mod="apps.files", glyph="F" },
  { name="Browser", mod="apps.browser", glyph="B" },
  { name="Terminal", mod="apps.shell", glyph="T" },
  { name="KL Store", mod="apps.store", glyph="S" },
  { name="KL Maker", mod="apps.maker", glyph="M" },
  { name="Disk Manager", mod="apps.diskmanager", glyph="D" },
  { name="Website Studio", mod="apps.site", glyph="W" },
  { name="Server", mod="apps.server", glyph="V" },
  { name="Network", mod="apps.network", glyph="N" },
  { name="Remote", mod="apps.remote", glyph="R" },
  { name="Mail", mod="apps.mail", glyph="E" },
  { name="Antivirus", mod="apps.antivirus", glyph="A" },
  { name="Security & Privacy", mod="apps.privacy", glyph="P" },
  { name="OS Update", mod="apps.update", glyph="U" },
}

local function appList()
  local apps = {}
  for _, app in ipairs(BUILT_IN) do apps[#apps + 1] = app end
  for _, app in ipairs(Registry.list()) do apps[#apps + 1] = { name=app.name, path=app.path, id=app.id, glyph="A" } end
  return apps
end

local function launch(app)
  ui.setAppWindow(true, app.name)
  local ok, result
  if app.mod then ok, result = pcall(function() return require(app.mod).run() end)
  else ok, result = pcall(dofile, app.path) end
  ui.setAppWindow(false)
  if not ok and result ~= "Terminated" and result ~= "__KL_WINDOW_CLOSE" and result ~= "__KL_WINDOW_MINIMIZE" then
    ui.message("Application error", tostring(result))
  elseif ok and result == false then ui.message("Application error", "Could not start " .. app.name .. ".") end
end

local function createFile(kind)
  fs.makeDir("/Documents"); fs.makeDir("/www")
  if kind == "folder" then
    local name = ui.input("New folder", "Folder name in /Documents:", "New Folder")
    if name and name ~= "" and not name:find("[/\\]", 1) and name ~= ".." then
      local path = fs.combine("/Documents", name)
      if not fs.exists(path) then fs.makeDir(path) else ui.message("Create folder", "That name already exists.") end
    end
    return
  end
  local prompt = kind == "lua" and "Lua script name (without extension):" or kind == "html" and "Website page name (without extension):" or "Text document name (without extension):"
  local name = ui.input("Create file", prompt, kind == "html" and "new-page" or "New File")
  if not name or name == "" or name:find("[/\\]", 1) or name == ".." then return end
  local ext = kind == "lua" and ".lua" or kind == "html" and ".html" or ".txt"
  name = name:gsub("%.[%w]+$", "") .. ext
  local path = kind == "html" and fs.combine("/www", name) or fs.combine("/Documents", name)
  if fs.exists(path) then ui.message("Create file", "That file already exists: " .. path); return end
  local content = kind == "lua" and "-- New KL OS Lua script\nprint(\"Hello from KL OS!\")\n" or
    kind == "html" and "<!doctype html>\n<html>\n<head>\n  <title>My website</title>\n</head>\n<body>\n  <h1>Welcome!</h1>\n  <p>This page is hosted by my CC:Tweaked computer.</p>\n  <p><a href=\"/about.html\">About this site</a></p>\n</body>\n</html>\n" or "New text document\n"
  local f, err = fs.open(path, "w")
  if not f then ui.message("Create file failed", tostring(err)); return end
  f.write(content); f.close(); ui.message("File created", path)
end

local function taskbarPins(apps)
  local indices, used = {}, {}
  for _, name in ipairs({ "Files", "Browser", "Terminal", "KL Store", "KL Maker", "Disk Manager" }) do
    for i, app in ipairs(apps) do
      if app.name == name and not used[i] then indices[#indices + 1] = i; used[i] = true; break end
    end
  end
  for i, app in ipairs(apps) do
    if app.path and not used[i] then indices[#indices + 1] = i; used[i] = true end
  end
  return indices
end

local function draw(apps, startOpen, context, selected)
  local w, h = ui.size(); local T = ui.theme()
  ui.clear(T.desktop, colors.white); ui.fill(1, 1, w, h - 1, T.desktop, colors.white)
  ui.fill(1, 1, w, 4, colors.blue, colors.white)
  ui.text(3, 2, "KL OS 11", colors.white, colors.blue)
  ui.text(3, 3, "STANDARD EDITION", colors.lightBlue, colors.blue)
  ui.text(3, 5, "A calm place to work.", colors.white, T.desktop)
  ui.text(3, 7, "Right-click to create files and folders.", colors.lightGray, T.desktop)
  ui.text(3, 8, "Open KL Store for apps or KL Maker to create your own.", colors.lightGray, T.desktop)
  ui.fill(1, h, w, 1, T.task, T.taskfg)
  local start = ui.button(1, h, "Start", startOpen)
  local x, pins = 9, {}
  local pinIndices = taskbarPins(apps)
  local count = math.min(#pinIndices, math.max(0, math.floor((w - 16) / 3)))
  for i = 1, count do
    local appIndex = pinIndices[i]
    pins[i] = { app=appIndex, rect=ui.button(x, h, apps[appIndex].glyph, selected == appIndex) }
    x = x + 3
  end
  ui.text(math.max(x + 1, w - 8), h, textutils.formatTime(os.time(), true), T.taskfg, T.task)

  local menu = {}
  if startOpen then
    local visible = math.max(1, math.min(#apps, h - 7))
    local first = math.max(1, math.min(selected, math.max(1, #apps - visible + 1)))
    local mh = visible + 3
    local mx, my = 2, h - mh - 1
    ui.fill(mx, my, math.min(30, w - 2), mh, T.panel, T.panelfg)
    ui.fill(mx, my, math.min(30, w - 2), 1, colors.blue, colors.white)
    ui.text(mx + 1, my, "KL OS  |  Start", colors.white, colors.blue)
    for row = 1, visible do
      local i = first + row - 1
      menu[#menu + 1] = { index=i, rect=ui.button(mx + 1, my + row, apps[i].glyph .. "  " .. apps[i].name, selected == i) }
    end
    ui.text(mx + 1, math.min(h - 1, my + visible + 1), "v3.0.0  |  Esc: close", T.fg, T.panel)
  end

  local contextRects = {}
  if context then
    local labels = { "New folder", "Text document", "Lua script", "Website page", "Open Files", "Refresh" }
    local mw, mh = 22, #labels
    local mx = math.max(1, math.min(context.x, w - mw + 1)); local my = math.max(1, math.min(context.y, h - mh - 1))
    ui.fill(mx, my, mw, mh, T.panel, T.panelfg)
    for i, label in ipairs(labels) do contextRects[i] = ui.button(mx + 1, my + i - 1, label, false) end
  end
  return { start=start, pins=pins, menu=menu, context=contextRects }
end

function M.run()
  fs.makeDir("/Documents"); fs.makeDir("/www"); fs.makeDir("/Applications")
  local selected, startOpen, context = 1, false, nil
  while true do
    local apps = appList(); selected = math.max(1, math.min(selected, #apps))
    local r = draw(apps, startOpen, context, selected)
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up and startOpen then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down and startOpen then selected = math.min(#apps, selected + 1)
      elseif ev[2] == keys.enter and startOpen then launch(apps[selected]); startOpen = false; context = nil
      elseif ev[2] == keys.escape then if context then context = nil else startOpen = not startOpen end
      elseif ev[2] == keys.q then return
      elseif ev[2] == keys.n then context = { x=3, y=4 } end
    elseif ev[1] == "mouse_click" then
      local b, x, y = ev[2], ev[3], ev[4]
      if b == 2 then context = { x=x, y=y }; startOpen = false
      elseif b == 1 then
        if context then
          local action; for i, rect in ipairs(r.context) do if ui.hit(rect, x, y) then action=i; break end end
          context = nil
          if action==1 then createFile("folder") elseif action==2 then createFile("text") elseif action==3 then createFile("lua") elseif action==4 then createFile("html") elseif action==5 then launch(apps[1]) end
        elseif ui.hit(r.start,x,y) then startOpen = not startOpen
        elseif startOpen then
          local chosen; for _, entry in ipairs(r.menu) do if ui.hit(entry.rect,x,y) then chosen=entry.index; break end end
          if chosen then selected=chosen; launch(apps[chosen]); startOpen=false else startOpen=false end
        else
          for _, entry in ipairs(r.pins) do if ui.hit(entry.rect,x,y) then selected=entry.app; launch(apps[entry.app]); break end end
        end
      end
    end
  end
end
return M
