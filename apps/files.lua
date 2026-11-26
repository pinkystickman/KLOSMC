-- HackOS file manager.
local ui = require("os.ui")
local F = {}

local function list(cwd)
  local items = {}
  for _, name in ipairs(fs.list(cwd)) do
    local path = fs.combine(cwd, name)
    items[#items + 1] = { name = name, path = path, dir = fs.isDir(path) }
  end
  table.sort(items, function(a, b)
    if a.dir ~= b.dir then return a.dir end
    return a.name:lower() < b.name:lower()
  end)
  return items
end

local function external(...)
  local args = { ... }
  ui.clear(colors.black, colors.white)
  shell.run(table.unpack(args))
  print(); print("Press any key to return to Files...")
  os.pullEvent("key")
end

function F.run()
  local cwd, selected, scroll = "", nil, 0
  while true do
    local w, h = ui.size()
    local T = ui.theme()
    local items = list(cwd)
    local body = math.max(1, h - 5)
    scroll = math.max(0, math.min(scroll, math.max(0, #items - body)))
    ui.clear(T.bg, T.fg)
    ui.header("File Explorer", "/" .. cwd)
    ui.text(2, 2, "Name", T.accent, T.bg)
    for i = 1, body do
      local it = items[scroll + i]
      if it then
        local label = (it.dir and "[+] " or "    ") .. it.name
        if it.path == selected then ui.text(2, 2 + i, ui.pad(label, w - 2), colors.white, T.selected)
        else ui.text(2, 2 + i, ui.pad(label, w - 2), it.dir and T.accent or T.fg, T.bg) end
      end
    end
    ui.text(2, h - 2, selected and ("Selected: " .. selected) or (#items .. " item(s)"), T.fg, T.bg)
    local open = ui.button(2, h, "Open / Run")
    local edit = ui.button(15, h, "Edit")
    local new = ui.button(23, h, "New folder")
    local up = ui.button(36, h, "Up")
    local back = ui.button(w - 7, h, "Back")
    ui.drawCursor()

    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = scroll + ev[2] * 2 end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      local idx = scroll + y - 3
      local item = items[idx]
      if y >= 3 and y <= 2 + body and item then
        if item.dir then cwd, scroll, selected = item.path, 0, nil else selected = item.path end
      elseif ui.hit(open, x, y) and selected then
        if fs.isDir(selected) then cwd, scroll, selected = selected, 0, nil else external("/" .. selected) end
      elseif ui.hit(edit, x, y) and selected and not fs.isDir(selected) then external("edit", selected)
      elseif ui.hit(new, x, y) then
        local name = ui.input("New folder", "Folder name:", "New Folder")
        if name and name ~= "" and not name:find("/", 1, true) and name ~= ".." then fs.makeDir(fs.combine(cwd, name)) end
      elseif ui.hit(up, x, y) and cwd ~= "" then cwd, scroll, selected = fs.getDir(cwd), 0, nil
      elseif ui.hit(back, x, y) then return end
    end
  end
end
return F
