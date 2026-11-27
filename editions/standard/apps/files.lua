-- KL OS file browser
local ui = require("os.ui")
local F = {}

local function list(cwd)
  local items = {}
  for _, name in ipairs(fs.list(cwd)) do
    local p = fs.combine(cwd, name)
    items[#items + 1] = { name = name, path = p, dir = fs.isDir(p) }
  end
  table.sort(items, function(a, b)
    if a.dir ~= b.dir then return a.dir end
    return a.name:lower() < b.name:lower()
  end)
  return items
end

local function external(...)
  local args = { ... }
  ui.clear()
  shell.run(table.unpack(args))
  print() print("Press any key...")
  os.pullEvent("key")
end

function F.run()
  local cwd, sel, scroll = "", nil, 0
  while true do
    local w, h = ui.size()
    local T = ui.theme()
    local items = list(cwd)
    local bh = h - 3
    scroll = math.max(0, math.min(scroll, #items - bh))
    ui.clear(T.bg)
    ui.header("Files", "/" .. cwd)
    for i = 1, bh do
      local it = items[scroll + i]
      if it then
        local s = ui.pad((it.dir and "/" or " ") .. it.name, w)
        if it.path == sel then ui.text(1, 2 + i, s, T.btnfg, T.hot)
        else ui.text(1, 2 + i, s, it.dir and T.accent or T.fg, T.bg) end
      end
    end
    local run  = ui.button(1, h, "Run")
    local edit = ui.button(7, h, "Edit")
    local up   = ui.button(14, h, "Up")
    local back = ui.button(19, h, "Exit")
    ui.drawCursor()

    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = scroll + ev[2] * 2 end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      local it = items[scroll + y - 2]
      if y >= 3 and y <= h - 1 and it then
        if it.dir then cwd, scroll, sel = it.path, 0, nil else sel = it.path end
      elseif ui.hit(run, x, y) and sel then external("/" .. sel)
      elseif ui.hit(edit, x, y) and sel then external("edit", sel)
      elseif ui.hit(up, x, y) and cwd ~= "" then cwd, scroll, sel = fs.getDir(cwd), 0, nil
      elseif ui.hit(back, x, y) then return end
    end
  end
end

return F
