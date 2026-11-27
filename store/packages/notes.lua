-- KL Store: Notes
local ui = require("os.ui")
local root = "/Documents/Notes"
fs.makeDir(root)
local function listNotes()
  local out = {}
  for _, name in ipairs(fs.list(root)) do
    local path = fs.combine(root, name)
    if not fs.isDir(path) then out[#out + 1] = path end
  end
  table.sort(out)
  return out
end
while true do
  local notes = listNotes()
  local w, h = ui.size(); local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header("Notes", "KL STORE APP")
  ui.text(2, 3, "Saved notes: " .. #notes, T.accent, T.bg)
  for i = 1, math.min(#notes, h - 8) do ui.text(2, 4 + i, tostring(i) .. ". " .. fs.getName(notes[i]), T.fg, T.bg) end
  local create = ui.button(2, h - 2, "New note")
  local open = ui.button(14, h - 2, "Open by number")
  local back = ui.button(w - 8, h - 2, "Close")
  local ev = { os.pullEvent() }
  local kind, x, y = ui.pointer(ev)
  if kind == "click" then
    if ui.hit(back, x, y) then return
    elseif ui.hit(create, x, y) then
      local title = ui.input("New note", "Note name:", "Note")
      if title and title ~= "" and not title:find("[/\\]", 1) then
        local safe = title:gsub("[^%w_%- ]", ""):gsub(" ", "_")
        if safe ~= "" then
          local path = fs.combine(root, safe .. ".txt")
          if fs.exists(path) then ui.message("Notes", "A note with that name already exists.")
          else local f = fs.open(path, "w"); if f then f.write(""); f.close(); shell.run("edit", path) end end
        end
      end
    elseif ui.hit(open, x, y) then
      local value = ui.input("Open note", "Enter note number:", "1")
      local idx = tonumber(value or "")
      if idx and notes[idx] then shell.run("edit", notes[idx]) end
    end
  elseif ev[1] == "key" then
    if ev[2] == keys.n then
      local title = ui.input("New note", "Note name:", "Note")
      if title and title ~= "" then
        local safe = title:gsub("[^%w_%- ]", ""):gsub(" ", "_")
        if safe ~= "" then local path = fs.combine(root, safe .. ".txt"); if not fs.exists(path) then local f = fs.open(path, "w"); if f then f.close(); shell.run("edit", path) end end end
      end
    elseif ev[2] == keys.escape then return end
  end
end
