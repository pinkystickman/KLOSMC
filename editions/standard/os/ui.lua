-- KL OS Standard UI helpers (Windows-inspired theme, no custom mouse cursor).
local ui = {}
local wrap = require("cc.strings").wrap
ui.wrap = wrap

function ui.size() return term.getSize() end
function ui.col(c, mono) if term.isColor() then return c end return mono or colors.white end
function ui.theme()
  local colour = term.isColor()
  return {
    desktop = colour and colors.blue or colors.black,
    bg = colour and colors.lightGray or colors.black,
    fg = colour and colors.black or colors.white,
    bar = colour and colors.blue or colors.gray,
    barfg = colors.white,
    task = colour and colors.gray or colors.gray,
    taskfg = colors.white,
    btn = colour and colors.lightGray or colors.gray,
    btnfg = colors.black,
    hot = colour and colors.cyan or colors.white,
    accent = colour and colors.blue or colors.white,
    selected = colour and colors.blue or colors.gray,
    selectedfg = colors.white,
    good = colour and colors.lime or colors.white,
    bad = colour and colors.red or colors.white,
  }
end
function ui.pad(s, w)
  s = tostring(s or "")
  if w <= 0 then return "" end
  return (s .. (" "):rep(w)):sub(1, w)
end
function ui.clear(bg, fg)
  term.setBackgroundColor(bg or colors.black); term.setTextColor(fg or colors.white)
  term.clear(); term.setCursorPos(1, 1)
end
function ui.fill(x, y, w, h, bg, fg, ch)
  local tw, th = term.getSize()
  if w <= 0 or h <= 0 then return end
  local left = math.max(1, x); local width = math.max(0, math.min(w, tw - left + 1))
  local line = ui.pad(ch or " ", width)
  term.setBackgroundColor(bg or colors.black); term.setTextColor(fg or colors.white)
  for row = y, math.min(y + h - 1, th) do if row >= 1 then term.setCursorPos(left, row); term.write(line) end end
end
function ui.text(x, y, s, fg, bg)
  local w, h = term.getSize()
  if y < 1 or y > h or x > w then return end
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(math.max(1, x), y)
  term.write(tostring(s or ""):sub(1, math.max(0, w - math.max(1, x) + 1)))
end
function ui.header(title, right)
  local w = term.getSize(); local T = ui.theme()
  ui.fill(1, 1, w, 1, T.bar, T.barfg)
  ui.text(2, 1, title or "KL OS", T.barfg, T.bar)
  if right then ui.text(math.max(2, w - #right - 1), 1, right, T.barfg, T.bar) end
end
function ui.window(x, y, w, h, title)
  local T = ui.theme(); ui.fill(x, y, w, h, T.bg, T.fg); ui.fill(x, y, w, 1, T.bar, T.barfg)
  if title then ui.text(x + 1, y, title, T.barfg, T.bar) end
  if w > 2 then ui.text(x + w - 2, y, " X ", T.barfg, T.bar) end
end
function ui.button(x, y, label, selected)
  local T = ui.theme(); local s = " " .. tostring(label) .. " "
  ui.text(x, y, s, selected and T.selectedfg or T.btnfg, selected and T.selected or T.btn)
  return { x1 = x, y1 = y, x2 = x + #s - 1, y2 = y }
end
function ui.hit(r, x, y) return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 end
function ui.pointer(ev)
  if ev[1] == "mouse_click" and ev[2] == 1 then return "click", ev[3], ev[4] end
  return nil
end
function ui.message(title, message)
  local w, h = term.getSize(); local T = ui.theme(); ui.clear(T.bg, T.fg); ui.header(title)
  for i, line in ipairs(wrap(tostring(message or ""), math.max(8, w - 4))) do if i + 2 < h then ui.text(2, i + 2, line, T.fg, T.bg) end end
  ui.text(2, h, "Press any key or click", T.accent, T.bg)
  repeat local e = { os.pullEvent() } until e[1] == "key" or e[1] == "mouse_click"
end
function ui.input(title, prompt, initial)
  local w, h = term.getSize(); local T = ui.theme(); ui.clear(T.bg, T.fg); ui.header(title or "Input")
  local lines = wrap(tostring(prompt or ""), math.max(8, w - 4))
  for i = 1, math.min(#lines, math.max(1, h - 6)) do ui.text(2, i + 2, lines[i], T.fg, T.bg) end
  local y = math.min(h - 2, math.max(5, #lines + 3))
  ui.fill(2, y, w - 4, 1, colors.white, colors.black)
  term.setCursorPos(3, y); term.setTextColor(colors.black); term.setBackgroundColor(colors.white)
  if term.setCursorBlink then term.setCursorBlink(true) end
  local value = read(nil, nil, nil, initial or "")
  if term.setCursorBlink then term.setCursorBlink(false) end
  term.setTextColor(T.fg); term.setBackgroundColor(T.bg)
  return value
end
return ui
