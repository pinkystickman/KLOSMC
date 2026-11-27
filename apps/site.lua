-- Website Studio: create/edit local HTML pages and control the built-in rednet web host.
local ui = require("os.ui")
local Site = require("os.site")
local Server = require("server.webserver")
local A = {}

local function pages()
  Site.ensureFiles()
  local out = {}
  for _, name in ipairs(fs.list("/www")) do
    local path = fs.combine("/www", name)
    if not fs.isDir(path) and (name:lower():match("%.html?$") or name:lower():match("%.htm$")) then out[#out + 1] = path end
  end
  table.sort(out)
  return out
end

local function createPage()
  local name = ui.input("New website page", "Page name (letters, numbers, - and _):", "page")
  if not name or name == "" or not name:match("^[%w_%-]+$") then return end
  local path = "/www/" .. name .. ".html"
  if fs.exists(path) then ui.message("Website Studio", "That page already exists."); return end
  local title = ui.input("Page title", "Title shown in the browser:", name)
  local f, err = fs.open(path, "w")
  if not f then ui.message("Create page failed", tostring(err)); return end
  f.write("<!doctype html>\n<html>\n<head>\n  <title>" .. (title or name) .. "</title>\n</head>\n<body>\n  <h1>" .. (title or name) .. "</h1>\n  <p>Write your website here.</p>\n  <p><a href=\"/index.html\">Back home</a></p>\n</body>\n</html>\n")
  f.close()
  return path
end

local function editPage(path)
  if not path then return end
  ui.clear(colors.black, colors.white)
  shell.run("edit", path)
end

local function preview(path)
  local page, err = Site.readPage("/" .. fs.getName(path))
  if not page then ui.message("Preview failed", err); return end
  local w, h = ui.size(); local T = ui.theme()
  local scroll = 0
  while true do
    ui.clear(colors.white, colors.black); ui.header("Preview: " .. page.title)
    ui.text(2, 3, page.title, colors.blue, colors.white)
    local lines = page.lines or {}
    local visible = math.max(1, h - 5)
    scroll = math.max(0, math.min(scroll, math.max(0, #lines - visible)))
    for i = 1, visible do
      local line = lines[scroll + i]
      if line then ui.text(2, 3 + i, line.link and ("[ " .. line.link .. " ]") or (line.text or ""), line.link and colors.blue or (line.color or colors.black), colors.white) end
    end
    local back = ui.button(2, h - 1, "Back")
    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = math.max(0, scroll + ev[2] * 2)
    elseif ev[1] == "key" and (ev[2] == keys.escape or ev[2] == keys.enter) then return
    else local kind, x, y = ui.pointer(ev); if kind == "click" and ui.hit(back, x, y) then return end end
  end
end

function A.run()
  Site.ensureFiles()
  local selected = 1
  while true do
    local list = pages()
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.bg, T.fg); ui.header("Website Studio", "HTML / HOSTING")
    ui.text(2, 3, "Your website folder: /www", T.accent, T.bg)
    ui.text(2, 4, "Create pages, edit HTML, then turn hosting on.", T.fg, T.bg)
    for i, path in ipairs(list) do
      local y = 6 + i
      if y < h - 5 then
        local mark = i == selected and "> " or "  "
        ui.text(2, y, ui.pad(mark .. fs.getName(path), w - 4), i == selected and T.selectedfg or T.fg, i == selected and T.selected or T.bg)
      end
    end
    local enabled, domain = Server.getConfig()
    ui.text(2, h - 5, "Hosting: " .. (enabled and "ON" or "OFF") .. "   Domain: " .. domain, enabled and T.good or T.fg, T.bg)
    local new = ui.button(2, h - 3, "New page")
    local edit = ui.button(13, h - 3, "Edit HTML")
    local prev = ui.button(25, h - 3, "Preview")
    local host = ui.button(2, h - 1, enabled and "Stop hosting" or "Start hosting")
    local back = ui.button(w - 8, h - 1, "Back")

    local function chooseEdit()
      local path = list[selected]
      if path then editPage(path) else ui.message("Website Studio", "Create a page first.") end
    end
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(math.max(1, #list), selected + 1)
      elseif ev[2] == keys.enter then chooseEdit()
      elseif ev[2] == keys.n then local p = createPage(); if p then selected = #pages() end
      elseif ev[2] == keys.escape then return end
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        local idx = y - 6
        if idx >= 1 and idx <= #list then selected = idx
        elseif ui.hit(new, x, y) then local p = createPage(); if p then selected = #pages() end
        elseif ui.hit(edit, x, y) then chooseEdit()
        elseif ui.hit(prev, x, y) then if list[selected] then preview(list[selected]) end
        elseif ui.hit(host, x, y) then
          local current = Server.getConfig()
          local ok, err = Server.setEnabled(not current)
          ui.message("Website Hosting", ok and (not current and "Your website is now hosted on the network." or "Website hosting stopped.") or tostring(err))
        elseif ui.hit(back, x, y) then return end
      end
    end
  end
end
return A
