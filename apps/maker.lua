-- KL Maker: a point-and-click visual builder for small websites and CC:Tweaked apps.
local ui = require("os.ui")
local Registry = require("os.appregistry")
local Maker = {}
local PROJECTS = "/Documents/KLMaker"

local function slugify(value)
  local slug = tostring(value or "project"):lower():gsub("[^%w_%-]+", "-"):gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
  if slug == "" then slug = "project" end
  return slug:sub(1, 28)
end

local function htmlEscape(value)
  return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function luaQuote(value)
  return string.format("%q", tostring(value or ""))
end

local function saveProject(project)
  fs.makeDir(PROJECTS)
  local path = fs.combine(PROJECTS, slugify(project.name) .. ".json")
  local f, err = fs.open(path, "w")
  if not f then return false, tostring(err) end
  f.write(textutils.serialiseJSON(project)); f.close()
  project.path = path
  return true, path
end

local function loadProject(path)
  local f, err = fs.open(path, "r")
  if not f then return nil, tostring(err) end
  local raw = f.readAll(); f.close()
  local ok, data = pcall(textutils.unserializeJSON, raw)
  if not ok or type(data) ~= "table" or type(data.name) ~= "string" or (data.kind ~= "website" and data.kind ~= "app") or type(data.components) ~= "table" then
    return nil, "This KL Maker project file is invalid."
  end
  data.name = data.name:sub(1, 32)
  local valid, cleaned = { heading=true, text=true, link=true, divider=true, list=true, button=true }, {}
  for _, component in ipairs(data.components) do
    if type(component) == "table" and valid[component.kind] and type(component.text or "") == "string" then
      cleaned[#cleaned + 1] = { kind = component.kind, text = tostring(component.text or ""):sub(1, 160), target = tostring(component.target or ""):sub(1, 100) }
      if #cleaned >= 30 then break end
    end
  end
  if data.kind == "app" then
    while #cleaned > 12 do table.remove(cleaned) end
  end
  data.components = cleaned
  return data
end

local function projectFiles()
  fs.makeDir(PROJECTS)
  local list = {}
  for _, name in ipairs(fs.list(PROJECTS)) do
    local path = fs.combine(PROJECTS, name)
    if not fs.isDir(path) and name:match("%.json$") then list[#list + 1] = path end
  end
  table.sort(list)
  return list
end

local function chooseProject()
  local files = projectFiles()
  if #files == 0 then ui.message("KL Maker", "No saved projects yet."); return nil end
  local selected = 1
  while true do
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.bg, T.fg); ui.header("Open KL Maker Project")
    ui.text(2, 3, "Choose a saved project:", T.fg, T.bg)
    local visible = math.min(#files, h - 7)
    for i = 1, visible do
      local path = files[i]
      local label = fs.getName(path):gsub("%.json$", "")
      ui.text(3, 4 + i, ui.pad((i == selected and "> " or "  ") .. label, w - 5), i == selected and T.selectedfg or T.fg, i == selected and T.selected or T.bg)
    end
    local open = ui.button(2, h - 2, "Open")
    local back = ui.button(w - 8, h - 2, "Back")
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(visible, selected + 1)
      elseif ev[2] == keys.enter then return files[selected]
      elseif ev[2] == keys.escape then return nil end
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        local idx = y - 4
        if idx >= 1 and idx <= visible then selected = idx
        elseif ui.hit(open, x, y) then return files[selected]
        elseif ui.hit(back, x, y) then return nil end
      end
    end
  end
end

local function newProject(kind)
  local name = ui.input("New project", "Give your project a name:", kind == "website" and "My Website" or "My App")
  if not name or name == "" then return nil end
  local project = { name = name:sub(1, 32), kind = kind, components = {} }
  local path = fs.combine(PROJECTS, slugify(project.name) .. ".json")
  if fs.exists(path) then
    local answer = ui.input("Project exists", "Type OVERWRITE to replace this project:", "")
    if answer ~= "OVERWRITE" then return nil end
  end
  project.path = path
  return project
end

local function addComponent(project, existing)
  local available = project.kind == "website" and "heading, text, link, divider, list" or "heading, text, button, divider"
  local default = existing and existing.kind or (project.kind == "website" and "heading" or "text")
  local kind = ui.input("Component type", "Choose: " .. available, default)
  if not kind then return nil end
  kind = kind:lower():gsub("%s+", "")
  local allowed = project.kind == "website" and { heading=true, text=true, link=true, divider=true, list=true } or { heading=true, text=true, button=true, divider=true }
  if not allowed[kind] then ui.message("KL Maker", "That component is not available for this project type."); return nil end
  local value = existing and existing.text or ""
  if kind ~= "divider" then
    value = ui.input("Component content", "Enter the text shown in your design:", value ~= "" and value or (kind == "button" and "Click me" or "Your text here"))
    if value == nil then return nil end
  else value = "" end
  local target = ""
  if kind == "link" then
    target = ui.input("Link destination", "Website path, e.g. /about.html:", existing and existing.target or "/index.html") or ""
    if target:find("..", 1, true) or not target:match("^/[%w%._/%-]+$") then ui.message("KL Maker", "Use a local website path such as /about.html."); return nil end
  end
  return { kind = kind, text = tostring(value):sub(1, 160), target = target }
end

local function htmlFor(project)
  local out = { "<!doctype html>", "<html>", "<head><title>" .. htmlEscape(project.name) .. "</title></head>", "<body>", "<h1>" .. htmlEscape(project.name) .. "</h1>" }
  for _, c in ipairs(project.components) do
    if c.kind == "heading" then out[#out + 1] = "<h2>" .. htmlEscape(c.text) .. "</h2>"
    elseif c.kind == "text" then out[#out + 1] = "<p>" .. htmlEscape(c.text) .. "</p>"
    elseif c.kind == "link" then out[#out + 1] = '<p><a href="' .. htmlEscape(c.target) .. '">' .. htmlEscape(c.text) .. "</a></p>"
    elseif c.kind == "list" then out[#out + 1] = "<ul><li>" .. htmlEscape(c.text) .. "</li></ul>"
    elseif c.kind == "divider" then out[#out + 1] = "<hr>" end
  end
  out[#out + 1] = "</body>"
  out[#out + 1] = "</html>"
  return table.concat(out, "\n") .. "\n"
end

local function luaFor(project)
  local out = {
    "-- Created visually with KL Maker.",
    "local ui = require(\"os.ui\")",
    "local clicks = 0",
    "while true do",
    "  local w, h = ui.size()",
    "  local T = ui.theme()",
    "  ui.clear(T.bg, T.fg)",
    "  ui.header(" .. luaQuote(project.name) .. ")",
    "  local buttons = {}",
    "  local y = 3",
  }
  for _, c in ipairs(project.components) do
    if c.kind == "heading" then
      out[#out + 1] = "  if y < h - 3 then ui.text(2, y, " .. luaQuote(c.text) .. ", T.accent, T.bg); y = y + 1 end"
    elseif c.kind == "text" then
      out[#out + 1] = "  if y < h - 3 then ui.text(2, y, " .. luaQuote(c.text) .. ", T.fg, T.bg); y = y + 1 end"
    elseif c.kind == "divider" then
      out[#out + 1] = "  if y < h - 3 then ui.text(2, y, string.rep(\"-\", math.max(1, w - 4)), T.fg, T.bg); y = y + 1 end"
    elseif c.kind == "button" then
      out[#out + 1] = "  if y < h - 3 then buttons[#buttons + 1] = ui.button(2, y, " .. luaQuote(c.text) .. ", false); y = y + 1 end"
    end
  end
  out[#out + 1] = "  ui.text(2, h - 2, \"Button clicks: \" .. tostring(clicks), T.good, T.bg)"
  out[#out + 1] = "  ui.text(2, h - 1, \"Press Esc to close this app.\", T.fg, T.bg)"
  out[#out + 1] = "  local ev = { os.pullEvent() }"
  out[#out + 1] = "  local kind, x, y = ui.pointer(ev)"
  out[#out + 1] = "  if kind == \"click\" then for _, r in ipairs(buttons) do if ui.hit(r, x, y) then clicks = clicks + 1 end end"
  out[#out + 1] = "  elseif ev[1] == \"key\" and ev[2] == keys.escape then return end"
  out[#out + 1] = "end"
  return table.concat(out, "\n") .. "\n"
end

local function writeFile(path, content)
  local dir = fs.getDir(path)
  if dir ~= "" then fs.makeDir(dir) end
  local f, err = fs.open(path, "w")
  if not f then return false, tostring(err) end
  f.write(content); f.close()
  return true
end

local function exportProject(project)
  local ok, saveErr = saveProject(project)
  if not ok then ui.message("KL Maker", "Could not save project: " .. tostring(saveErr)); return end
  local slug = slugify(project.name)
  if project.kind == "website" then
    local path = "/www/" .. slug .. ".html"
    if fs.exists(path) then
      local answer = ui.input("Export website", "Type OVERWRITE to replace " .. path .. ":", "")
      if answer ~= "OVERWRITE" then return end
    end
    local wrote, err = writeFile(path, htmlFor(project))
    ui.message("Website exported", wrote and ("Saved " .. path .. "\nOpen Website Server and choose Start hosting.") or tostring(err))
  else
    local path = "/Applications/" .. slug .. ".lua"
    if fs.exists(path) then
      local answer = ui.input("Export app", "Type OVERWRITE to replace " .. path .. ":", "")
      if answer ~= "OVERWRITE" then return end
    end
    local wrote, err = writeFile(path, luaFor(project))
    if not wrote then ui.message("App export failed", tostring(err)); return end
    local registered, why = Registry.register(project.name, path, "1.0.0")
    ui.message("App exported", registered and ("Saved " .. path .. "\n" .. project.name .. " is now available in Start.") or tostring(why))
  end
end

local function preview(project)
  local selected = 1
  while true do
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(project.kind == "website" and colors.white or T.bg, project.kind == "website" and colors.black or T.fg)
    ui.header("Preview: " .. project.name)
    ui.text(2, 3, project.name, T.accent, project.kind == "website" and colors.white or T.bg)
    local shown = math.min(#project.components, h - 7)
    for i = 1, shown do
      local c = project.components[i]
      local label
      if c.kind == "divider" then label = string.rep("-", math.max(1, w - 4))
      elseif c.kind == "button" then label = "[ " .. c.text .. " ]"
      elseif c.kind == "link" then label = "[ " .. c.text .. " -> " .. c.target .. " ]"
      else label = c.text end
      ui.text(2, 3 + i, ui.pad(label, w - 4), c.kind == "heading" and colors.blue or (project.kind == "website" and colors.black or T.fg), project.kind == "website" and colors.white or T.bg)
    end
    if #project.components == 0 then ui.text(2, 5, "Your design is empty. Add a component.", T.fg, project.kind == "website" and colors.white or T.bg) end
    local back = ui.button(2, h - 1, "Back to Maker")
    local ev = { os.pullEvent() }
    local kind, x, y = ui.pointer(ev)
    if (kind == "click" and ui.hit(back, x, y)) or (ev[1] == "key" and ev[2] == keys.escape) then return end
  end
end

local function drawBuilder(project, selected, scroll)
  local w, h = ui.size(); local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header("KL Maker", project.kind:upper() .. " BUILDER")
  ui.text(2, 2, project.name, T.accent, T.bg)
  local maxComponents = project.kind == "app" and 12 or 30
  ui.text(2, 3, "Components: " .. #project.components .. " / " .. maxComponents, T.fg, T.bg)
  local split = math.max(20, math.floor(w * 0.52))
  ui.fill(2, 5, split - 2, math.max(1, h - 10), T.panel, T.panelfg)
  ui.fill(split, 5, w - split - 1, math.max(1, h - 10), T.bg, T.fg)
  ui.text(3, 5, "DESIGN", T.accent, T.panel)
  ui.text(split + 1, 5, "LIVE PREVIEW", T.accent, T.bg)
  local body = math.max(1, h - 11)
  for row = 1, body do
    local idx = scroll + row
    local c = project.components[idx]
    if c then
      local line = string.format("%02d  %-7s %s", idx, c.kind, c.text)
      line = line:sub(1, split - 5)
      ui.text(3, 5 + row, ui.pad(line, split - 4), idx == selected and T.selectedfg or T.panelfg, idx == selected and T.selected or T.panel)
    end
  end
  local previewY = 6
  ui.text(split + 1, previewY, project.name:sub(1, math.max(1, w - split - 3)), T.accent, T.bg)
  previewY = previewY + 2
  for i = 1, math.min(#project.components, math.max(0, body - 2)) do
    local c = project.components[i]
    local label = c.kind == "divider" and "----------------" or (c.kind == "button" and ("[ " .. c.text .. " ]") or (c.kind == "link" and ("< " .. c.text .. " >") or c.text))
    ui.text(split + 1, previewY, label:sub(1, math.max(1, w - split - 2)), c.kind == "heading" and T.accent or T.fg, T.bg)
    previewY = previewY + 1
  end
  local add = ui.button(2, h - 4, "Add")
  local edit = ui.button(9, h - 4, "Edit")
  local delete = ui.button(17, h - 4, "Delete")
  local up = ui.button(27, h - 4, "Up")
  local down = ui.button(33, h - 4, "Down")
  local prev = ui.button(2, h - 2, "Preview")
  local save = ui.button(13, h - 2, "Save")
  local export = ui.button(22, h - 2, "Export")
  local back = ui.button(w - 8, h - 2, "Back")
  return { add=add, edit=edit, delete=delete, up=up, down=down, preview=prev, save=save, export=export, back=back, listTop=6, listBottom=5+body, visible=body }
end

local function build(project)
  local selected, scroll = 1, 0
  while true do
    selected = math.max(1, math.min(selected, math.max(1, #project.components)))
    local _, screenH = ui.size()
    local visibleRows = math.max(1, screenH - 11)
    scroll = math.max(0, math.min(scroll, math.max(0, #project.components - visibleRows)))
    local r = drawBuilder(project, selected, scroll)
    local maxComponents = project.kind == "app" and 12 or 30
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1); if selected <= scroll then scroll = math.max(0, scroll - 1) end
      elseif ev[2] == keys.down then selected = math.min(math.max(1, #project.components), selected + 1); if selected > scroll + r.visible then scroll = scroll + 1 end
      elseif ev[2] == keys.a and #project.components < maxComponents then local c = addComponent(project); if c then project.components[#project.components + 1] = c; selected = #project.components end
      elseif ev[2] == keys.e and project.components[selected] then local c = addComponent(project, project.components[selected]); if c then project.components[selected] = c end
      elseif ev[2] == keys.d and project.components[selected] then table.remove(project.components, selected); selected = math.max(1, selected - 1)
      elseif ev[2] == keys.p then preview(project)
      elseif ev[2] == keys.s then local ok, err = saveProject(project); ui.message("Save project", ok and ("Saved " .. err) or tostring(err))
      elseif ev[2] == keys.x then exportProject(project)
      elseif ev[2] == keys.escape then return end
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        if y >= r.listTop and y <= r.listBottom and x < math.floor((select(1, ui.size())) * 0.52) then
          local idx = scroll + y - r.listTop + 1
          if project.components[idx] then selected = idx end
        elseif ui.hit(r.add, x, y) and #project.components < maxComponents then
          local c = addComponent(project); if c then project.components[#project.components + 1] = c; selected = #project.components; if selected > scroll + r.visible then scroll = selected - r.visible end end
        elseif ui.hit(r.edit, x, y) and project.components[selected] then
          local c = addComponent(project, project.components[selected]); if c then project.components[selected] = c end
        elseif ui.hit(r.delete, x, y) and project.components[selected] then table.remove(project.components, selected); selected = math.max(1, selected - 1)
        elseif ui.hit(r.up, x, y) and selected > 1 then project.components[selected], project.components[selected - 1] = project.components[selected - 1], project.components[selected]; selected = selected - 1
        elseif ui.hit(r.down, x, y) and selected < #project.components then project.components[selected], project.components[selected + 1] = project.components[selected + 1], project.components[selected]; selected = selected + 1
        elseif ui.hit(r.preview, x, y) then preview(project)
        elseif ui.hit(r.save, x, y) then local ok, err = saveProject(project); ui.message("Save project", ok and ("Saved " .. err) or tostring(err))
        elseif ui.hit(r.export, x, y) then exportProject(project)
        elseif ui.hit(r.back, x, y) then return end
      end
    end
  end
end

function Maker.run()
  fs.makeDir(PROJECTS); fs.makeDir("/www"); fs.makeDir("/Applications")
  while true do
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.bg, T.fg); ui.header("KL Maker", "VISUAL CREATOR")
    ui.text(2, 3, "Create websites and CC:Tweaked apps without writing code.", T.fg, T.bg)
    ui.text(2, 5, "WEBSITE", T.accent, T.bg)
    ui.text(2, 6, "Design a page, export HTML, then host it from Website Server.", T.fg, T.bg)
    local website = ui.button(2, 8, "New website project", true)
    ui.text(2, 10, "APP", T.accent, T.bg)
    ui.text(2, 11, "Build a small interactive terminal app and add it to Start.", T.fg, T.bg)
    local app = ui.button(2, 13, "New app project", true)
    local open = ui.button(2, h - 2, "Open saved project")
    local close = ui.button(w - 8, h - 2, "Back")
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.one then local p = newProject("website"); if p then build(p) end
      elseif ev[2] == keys.two then local p = newProject("app"); if p then build(p) end
      elseif ev[2] == keys.o then local path = chooseProject(); if path then local p, err = loadProject(path); if p then p.path = path; build(p) else ui.message("Open project", tostring(err)) end end
      elseif ev[2] == keys.escape then return end
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        if ui.hit(website, x, y) then local p = newProject("website"); if p then build(p) end
        elseif ui.hit(app, x, y) then local p = newProject("app"); if p then build(p) end
        elseif ui.hit(open, x, y) then local path = chooseProject(); if path then local p, err = loadProject(path); if p then p.path = path; build(p) else ui.message("Open project", tostring(err)) end end
        elseif ui.hit(close, x, y) then return end
      end
    end
  end
end

return Maker
