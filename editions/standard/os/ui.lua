-- KL OS UI helpers
local ui = {}
local wrap = require("cc.strings").wrap
local cur = { x = 3, y = 5 }
ui.cursor = cur
ui.wrap = wrap

local MOVE = {
  [keys.left] = { -1, 0 }, [keys.right] = { 1, 0 },
  [keys.up] = { 0, -1 },   [keys.down] = { 0, 1 },
}

function ui.size() return term.getSize() end

-- Pick a colour on advanced computers, a fallback on basic ones
function ui.col(c, mono) if term.isColor() then return c end return mono or colors.white end

function ui.theme()
  local k = term.isColor()
  return {
    bg = colors.black, fg = colors.white,
    bar = k and colors.blue or colors.gray, barfg = colors.white,
    btn = k and colors.cyan or colors.lightGray, btnfg = colors.black,
    hot = k and colors.lime or colors.white,
    accent = k and colors.yellow or colors.white,
  }
end

function ui.pad(s, w) return (s .. (" "):rep(w)):sub(1, math.max(w, 0)) end

function ui.clear(bg)
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(colors.white)
  term.clear() term.setCursorPos(1, 1)
end

function ui.text(x, y, s, fg, bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(x, y) term.write(s)
end

function ui.header(title, right)
  local w = term.getSize()
  local T = ui.theme()
  ui.text(1, 1, (" "):rep(w), T.barfg, T.bar)
  ui.text(2, 1, title)
  if right then ui.text(w - #right, 1, right) end
end

-- Draws " label " and returns its hit rectangle; highlights when the cursor is over it
function ui.button(x, y, label)
  local T = ui.theme()
  local s = " " .. label .. " "
  local over = cur.y == y and cur.x >= x and cur.x <= x + #s - 1
  ui.text(x, y, s, T.btnfg, over and T.hot or T.btn)
  return { x1 = x, y1 = y, x2 = x + #s - 1, y2 = y }
end

function ui.hit(r, x, y)
  return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

-- Normalises input: returns "click"/"move", x, y. Arrows move '+', Enter/Space click.
function ui.pointer(ev)
  local e, a, b, c = ev[1], ev[2], ev[3], ev[4]
  local w, h = term.getSize()
  if e == "mouse_click" and a == 1 then
    cur.x, cur.y = b, c return "click", b, c
  elseif e == "mouse_drag" then
    cur.x, cur.y = b, c return "move", b, c
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

-- Draw the '+' cursor last, keeping the background colour underneath when possible
function ui.drawCursor()
  local bg = "f"
  local t = term.current()
  if t.getLine then
    local _, _, b = t.getLine(cur.y)
    if b and #b >= cur.x then bg = b:sub(cur.x, cur.x) end
  end
  term.setCursorPos(cur.x, cur.y)
  term.blit("+", bg == "0" and "f" or "0", bg)
end

function ui.message(title, text)
  local w, h = term.getSize()
  local T = ui.theme()
  ui.clear(T.bg) ui.header(title)
  for i, l in ipairs(wrap(text, w - 2)) do
    if i + 2 < h then ui.text(2, i + 2, l, T.fg, T.bg) end
  end
  ui.text(2, h, "Press any key or click", T.accent, T.bg)
  repeat local e = os.pullEvent() until e == "key" or e == "mouse_click"
end

return ui
