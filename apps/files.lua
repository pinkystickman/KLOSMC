-- HackOS file manager.
local ui = require("os.ui")
local recovery = require("os.recovery")
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
  local cwd, selected, scroll, selectedIndex = "", nil, 0, 1
  while true do
    local w, h = ui.size(); local T = ui.theme()
    local items = list(cwd)
    local body = math.max(1, h - 6)
    selectedIndex = math.max(1, math.min(selectedIndex, math.max(1, #items)))
    scroll = math.max(0, math.min(scroll, math.max(0, #items - body)))
    if selectedIndex <= scroll then scroll = selectedIndex - 1 end
    if selectedIndex > scroll + body then scroll = selectedIndex - body end
    ui.clear(T.bg, T.fg); ui.header("File Explorer", "/" .. cwd)
    ui.text(2, 2, "Name", T.accent, T.bg)
    for i = 1, body do
      local itemIndex = scroll + i; local it = items[itemIndex]
      if it then
        local label = (it.dir and "[+] " or "    ") .. it.name
        local active = it.path == selected or itemIndex == selectedIndex
        if active then ui.text(2, 2 + i, ui.pad(label, w - 2), T.selectedfg, T.selected)
        else ui.text(2, 2 + i, ui.pad(label, w - 2), it.dir and T.accent or T.fg, T.bg) end
      end
    end
    ui.text(2, h - 3, selected and ("Selected: " .. selected) or (#items .. " item(s)"), T.fg, T.bg)
    local open = ui.button(2, h - 1, "Open")
    local edit = ui.button(11, h - 1, "Edit")
    local del = ui.button(19, h - 1, "Delete")
    local up = ui.button(29, h - 1, "Up")
    local back = ui.button(w - 8, h - 1, "Back")
    local new = ui.button(2, h, "New folder")
    ui.text(16, h, "Enter: open   D: delete", T.fg, T.bg)

    local function deleteSelected()
      if not selected or not fs.exists(selected) then ui.message("Delete", "Select an existing file first."); return end
      if fs.isDir(selected) then ui.message("Delete", "Folder deletion is disabled. Delete individual files instead."); return end
      local normalized = tostring(selected):gsub("^/+", "")
      if normalized == "hackos/recovery" or normalized:match("^hackos/recovery/") then
        ui.message("Recovery Image", "Recovery backups are protected so the system can be repaired after a blue screen.")
        return
      end
      local systemFile = recovery.isSystemPath(selected)
      local prompt = systemFile and "SYSTEM FILE: type DELETE to remove it and trigger a recoverable blue screen:" or ("Type DELETE to remove " .. selected .. ":")
      local confirm = ui.input("Confirm deletion", prompt, "")
      if confirm ~= "DELETE" then return end
      if systemFile then recovery.damageAndCrash(selected, "System file deleted from File Explorer")
      else fs.delete(selected); selected = nil; selectedIndex = math.max(1, selectedIndex - 1) end
    end

    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = math.max(0, scroll + ev[2] * 2)
    elseif ev[1] == "key" then
      if ev[2] == keys.up then selectedIndex = math.max(1, selectedIndex - 1); selected = items[selectedIndex] and items[selectedIndex].path
      elseif ev[2] == keys.down then selectedIndex = math.min(math.max(1, #items), selectedIndex + 1); selected = items[selectedIndex] and items[selectedIndex].path
      elseif ev[2] == keys.enter and selected then
        if fs.isDir(selected) then cwd, scroll, selected, selectedIndex = selected, 0, nil, 1 else external("/" .. selected) end
      elseif ev[2] == keys.d then deleteSelected()
      elseif ev[2] == keys.backspace and cwd ~= "" then cwd, scroll, selected, selectedIndex = fs.getDir(cwd), 0, nil, 1
      elseif ev[2] == keys.n then
        local name = ui.input("New folder", "Folder name:", "New Folder")
        if name and name ~= "" and not name:find("/", 1, true) and name ~= ".." then fs.makeDir(fs.combine(cwd, name)) end
      end
    end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      local idx = scroll + y - 3; local item = items[idx]
      if y >= 3 and y <= 2 + body and item then
        selectedIndex = idx
        if item.dir then cwd, scroll, selected, selectedIndex = item.path, 0, nil, 1 else selected = item.path end
      elseif ui.hit(open, x, y) and selected then
        if fs.isDir(selected) then cwd, scroll, selected, selectedIndex = selected, 0, nil, 1 else external("/" .. selected) end
      elseif ui.hit(edit, x, y) and selected and not fs.isDir(selected) then external("edit", selected)
      elseif ui.hit(del, x, y) then deleteSelected()
      elseif ui.hit(new, x, y) then
        local name = ui.input("New folder", "Folder name:", "New Folder")
        if name and name ~= "" and not name:find("/", 1, true) and name ~= ".." then fs.makeDir(fs.combine(cwd, name)) end
      elseif ui.hit(up, x, y) and cwd ~= "" then cwd, scroll, selected, selectedIndex = fs.getDir(cwd), 0, nil, 1
      elseif ui.hit(back, x, y) then return end
    end
  end
end
return F
