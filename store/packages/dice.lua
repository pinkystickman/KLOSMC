-- KL Store: Dice Roller
local ui = require("os.ui")
local count, last = 1, nil
while true do
  local w, h = ui.size(); local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header("Dice Roller", "KL STORE APP")
  ui.text(2, 3, "Roll one or more six-sided dice.", T.fg, T.bg)
  ui.text(2, 5, "Number of dice: " .. count, T.accent, T.bg)
  ui.text(2, 7, "Last roll: " .. (last or "not rolled yet"), T.good, T.bg)
  local less = ui.button(2, h - 4, "- Dice")
  local more = ui.button(11, h - 4, "+ Dice")
  local roll = ui.button(21, h - 4, "ROLL", true)
  local close = ui.button(w - 8, h - 2, "Close")
  local ev = { os.pullEvent() }
  local kind, x, y = ui.pointer(ev)
  if kind == "click" then
    if ui.hit(close, x, y) then return
    elseif ui.hit(less, x, y) then count = math.max(1, count - 1)
    elseif ui.hit(more, x, y) then count = math.min(8, count + 1)
    elseif ui.hit(roll, x, y) then
      local values, sum = {}, 0
      for i = 1, count do local n = math.random(1, 6); values[#values + 1] = tostring(n); sum = sum + n end
      last = table.concat(values, ", ") .. "  |  total " .. sum
    end
  elseif ev[1] == "key" then
    if ev[2] == keys.left then count = math.max(1, count - 1)
    elseif ev[2] == keys.right then count = math.min(8, count + 1)
    elseif ev[2] == keys.enter or ev[2] == keys.space then
      local values, sum = {}, 0
      for i = 1, count do local n = math.random(1, 6); values[#values + 1] = tostring(n); sum = sum + n end
      last = table.concat(values, ", ") .. "  |  total " .. sum
    elseif ev[2] == keys.escape then return end
  end
end
