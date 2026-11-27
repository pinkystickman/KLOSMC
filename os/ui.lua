-- Shared Windows-inspired UI helpers for KL OS / HackOS.
local ui = {}
local wrap = require("cc.strings").wrap
ui.wrap = wrap
ui.appWindow = false
ui.appTitle = "Application"

function ui.size()
  local w, h = term.getSize()
  if ui.appWindow then h = math.max(4, h - 1) end -- reserve the last row for the taskbar
  return w, h
end
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
    accent = colour and colors.lightBlue or colors.white,
    selected = colour and colors.blue or colors.gray,
    selectedfg = colors.white,
    good = colour and colors.lime or colors.white,
    bad = colour and colors.red or colors.white,
    panel = colour and colors.lightGray or colors.black,
    panelfg = colour and colors.black or colors.white,
    dark = colour and colors.black or colors.black,
  }
end

function ui.setAppWindow(enabled, title)
  ui.appWindow = not not enabled
  ui.appTitle = title or ui.appTitle or "Application"
end

function ui.pad(s, w)
  s = tostring(s or "")
  if w <= 0 then return "" end
  return (s .. (" "):rep(w)):sub(1, w)
end

local function rawText(x, y, s, fg, bg)
  local w, h = term.getSize()
  if y < 1 or y > h or x > w then return end
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(math.max(1, x), y)
  term.write(tostring(s or ""):sub(1, math.max(0, w - math.max(1, x) + 1)))
end

function ui.clear(bg, fg)
  local T = ui.theme()
  term.setBackgroundColor(bg or T.bg)
  term.setTextColor(fg or T.fg)
  term.clear(); term.setCursorPos(1, 1)
  if ui.appWindow then
    local w, h = term.getSize()
    term.setBackgroundColor(T.task); term.setTextColor(T.taskfg)
    term.setCursorPos(1, h); term.write(ui.pad(" Start   " .. tostring(ui.appTitle) .. "   |   Click Start to return", w))
  end
end

function ui.fill(x, y, w, h, bg, fg, ch)
  local tw, th = term.getSize()
  local _, contentH = ui.size()
  if w <= 0 or h <= 0 then return end
  ch = ch or " "
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(fg or colors.white)
  local left = math.max(1, x)
  local line = ui.pad(ch, math.max(0, math.min(w, tw - left + 1)))
  for row = y, math.min(y + h - 1, contentH) do
    if row >= 1 then term.setCursorPos(left, row); term.write(line) end
  end
end

function ui.text(x, y, s, fg, bg)
  local w, h = ui.size()
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
  local shown = ui.appWindow and ui.appTitle or (title or "KL OS")
  ui.text(2, 1, shown, T.barfg, T.bar)
  if right then ui.text(math.max(2, w - #right - 13), 1, right, T.barfg, T.bar) end
  if ui.appWindow and w >= 22 then
    rawText(w - 12, 1, " _ ", T.barfg, T.bar)
    rawText(w - 8, 1, "[] ", T.barfg, T.bar)
    rawText(w - 4, 1, " X ", T.barfg, T.bar)
  end
end

function ui.window(x, y, w, h, title)
  local T = ui.theme()
  ui.fill(x, y, w, h, T.bg, T.fg)
  ui.fill(x, y, w, 1, T.bar, T.barfg)
  if title then ui.text(x + 1, y, title, T.barfg, T.bar) end
  if w > 2 then ui.text(x + w - 2, y, " X ", T.barfg, T.bar) end
end

function ui.button(x, y, label, selected)
  local T = ui.theme()
  local s = " " .. tostring(label) .. " "
  local bg = selected and T.selected or T.btn
  local fg = selected and T.selectedfg or T.btnfg
  ui.text(x, y, s, fg, bg)
  return { x1 = x, y1 = y, x2 = x + #s - 1, y2 = y }
end

function ui.hit(r, x, y)
  return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

-- No custom cursor. App windows expose close/minimise controls and a persistent taskbar.
function ui.pointer(ev)
  if ev[1] == "mouse_click" then
    local button, x, y = ev[2], ev[3], ev[4]
    if ui.appWindow and button == 1 then
      local w, h = term.getSize()
      if y == 1 and x >= w - 3 then error("__KL_WINDOW_CLOSE", 0) end
      if y == 1 and x >= w - 12 and x < w - 8 then error("__KL_WINDOW_MINIMIZE", 0) end
      if y == h then error("__KL_WINDOW_MINIMIZE", 0) end
    end
    if button == 1 then return "click", x, y end
    if button == 2 then return "right", x, y end
  end
  return nil
end

function ui.message(title, message)
  local w, h = ui.size()
  local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header(title)
  local lines = wrap(tostring(message or ""), math.max(8, w - 4))
  for i, line in ipairs(lines) do if i + 2 < h then ui.text(2, i + 2, line, T.fg, T.bg) end end
  ui.text(2, h, "Press any key or click to continue", T.accent, T.bg)
  repeat local e = { os.pullEvent() } until e[1] == "key" or e[1] == "mouse_click"
end

function ui.input(title, prompt, initial)
  local w, h = ui.size()
  local T = ui.theme()
  local mw = math.max(12, math.min(40, w - 2))
  local mh = math.max(7, math.min(9, h - 2))
  local mx = math.max(1, math.floor((w - mw) / 2) + 1)
  local my = math.max(1, math.floor((h - mh) / 2) + 1)
  -- Draw a modal dialog over the current desktop/app instead of replacing the whole screen.
  ui.fill(mx, my, mw, mh, T.panel, T.panelfg)
  ui.fill(mx, my, mw, 1, colors.blue, colors.white)
  ui.text(mx + 2, my, title or "Input", colors.white, colors.blue)
  ui.text(mx + mw - 4, my, " X ", colors.white, colors.blue)
  local lines = wrap(tostring(prompt or ""), math.max(8, mw - 4))
  for i = 1, math.min(#lines, mh - 4) do ui.text(mx + 2, my + i + 1, lines[i], T.panelfg, T.panel) end
  local y = my + mh - 2
  ui.fill(mx + 1, y, mw - 2, 1, colors.white, colors.black)
  term.setCursorPos(mx + 2, y); term.setTextColor(colors.black); term.setBackgroundColor(colors.white)
  if term.setCursorBlink then term.setCursorBlink(true) end
  local value = read(nil, nil, nil, initial or "")
  if term.setCursorBlink then term.setCursorBlink(false) end
  term.setTextColor(T.fg); term.setBackgroundColor(T.bg)
  return value
end

return ui
