-- HackOS graphical interface helpers for CC: Tweaked.
local ui = {}
local wrap = require("cc.strings").wrap
local cur = { x = 2, y = 2 }
ui.cursor = cur
ui.wrap = wrap

local MOVE = {
  [keys.left] = { -1, 0 }, [keys.right] = { 1, 0 },
  [keys.up] = { 0, -1 }, [keys.down] = { 0, 1 },
}

function ui.size() return term.getSize() end
function ui.col(c, mono) if term.isColor() then return c end return mono or colors.white end

function ui.theme()
  local colour = term.isColor()
  return {
    desktop = colour and colors.blue or colors.black,
    bg = colour and colors.lightGray or colors.black,
    fg = colors.black,
    bar = colour and colors.gray or colors.gray,
    barfg = colors.white,
    task = colour and colors.black or colors.gray,
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
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(fg or colors.white)
  term.clear()
  term.setCursorPos(1, 1)
end

function ui.fill(x, y, w, h, bg, fg, ch)
  local tw, th = term.getSize()
  if w <= 0 or h <= 0 then return end
  ch = ch or " "
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(fg or colors.white)
  local line = ui.pad(ch, w)
  for row = y, math.min(y + h - 1, th) do
    if row >= 1 then term.setCursorPos(math.max(1, x), row); term.write(line:sub(1, math.max(0, tw - math.max(1, x) + 1))) end
  end
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
  local w = term.getSize()
  local T = ui.theme()
  ui.fill(1, 1, w, 1, T.bar, T.barfg)
  ui.text(2, 1, title or "HackOS", T.barfg, T.bar)
  if right then ui.text(math.max(2, w - #right - 1), 1, right, T.barfg, T.bar) end
end

function ui.window(x, y, w, h, title)
  local T = ui.theme()
  ui.fill(x, y, w, h, T.bg, T.fg)
  ui.fill(x, y, w, 1, T.bar, T.barfg)
  if title then ui.text(x + 1, y, title, T.barfg, T.bar) end
  if w > 2 and h > 1 then
    ui.text(x + w - 2, y, " X ", T.barfg, T.bar)
  end
end

-- Draw a button and return its hit rectangle.
function ui.button(x, y, label, selected)
  local T = ui.theme()
  local s = " " .. tostring(label) .. " "
  local over = cur.y == y and cur.x >= x and cur.x <= x + #s - 1
  local bg = (selected or over) and T.hot or T.btn
  ui.text(x, y, s, T.btnfg, bg)
  return { x1 = x, y1 = y, x2 = x + #s - 1, y2 = y }
end

function ui.hit(r, x, y)
  return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

function ui.pointer(ev)
  local e, a, b, c = ev[1], ev[2], ev[3], ev[4]
  local w, h = term.getSize()
  if e == "mouse_click" and a == 1 then
    cur.x, cur.y = b, c
    return "click", b, c
  elseif e == "mouse_drag" then
    cur.x, cur.y = b, c
    return "move", b, c
  elseif e == "key" then
    local d = MOVE[a]
    if d then
      cur.x = math.max(1, math.min(w, cur.x + d[1]))
      cur.y = math.max(1, math.min(h, cur.y + d[2]))
      return "move", cur.x, cur.y
    elseif a == keys.enter or a == keys.space then
      return "click", cur.x, cur.y
    end
  end
end

function ui.drawCursor()
  local _, h = term.getSize()
  if cur.y < 1 or cur.y > h then return end
  local bg = "f"
  local t = term.current()
  if t.getLine then
    local _, _, b = t.getLine(cur.y)
    if b and #b >= cur.x then bg = b:sub(cur.x, cur.x) end
  end
  term.setCursorPos(cur.x, cur.y)
  term.blit("+", bg == "0" and "f" or "0", bg)
end

function ui.message(title, message)
  local w, h = term.getSize()
  local T = ui.theme()
  ui.clear(T.bg, T.fg)
  ui.header(title)
  local lines = wrap(tostring(message or ""), math.max(8, w - 4))
  for i, line in ipairs(lines) do
    if i + 2 < h then ui.text(2, i + 2, line, T.fg, T.bg) end
  end
  ui.text(2, h, "Press any key or click to continue", T.accent, T.bg)
  repeat
    local e = { os.pullEvent() }
  until e[1] == "key" or e[1] == "mouse_click"
end

function ui.input(title, prompt, initial)
  local w, h = term.getSize()
  local T = ui.theme()
  ui.clear(T.bg, T.fg)
  ui.header(title)
  ui.text(2, 3, prompt, T.fg, T.bg)
  local y = math.min(h - 2, 5)
  ui.fill(2, y, w - 4, 1, colors.white, colors.black)
  term.setCursorPos(3, y)
  term.setTextColor(colors.black)
  term.setBackgroundColor(colors.white)
  local value = read(nil, nil, nil, initial or "")
  term.setCursorBlink(false)
  return value
end

return ui
