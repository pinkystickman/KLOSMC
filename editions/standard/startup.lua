-- KL OS / HackOS 2.3.0 dual-edition startup (Standard).
package.path = "/?.lua;/?/init.lua;" .. package.path

local function crash(err)
  local w, h = term.getSize()
  term.setBackgroundColor(term.isColor() and colors.red or colors.gray)
  term.setTextColor(colors.white)
  term.clear(); term.setCursorPos(1, 1)
  print("KL OS has crashed")
  print()
  local lines = require("cc.strings").wrap(tostring(err), w)
  for i = 1, math.min(#lines, h - 5) do print(lines[i]) end
  term.setCursorPos(1, h - 1); write("[R] Reboot")
  term.setCursorPos(1, h); write("[X] Exit to CraftOS")
  while true do
    local _, key = os.pullEventRaw("key")
    if key == keys.r then os.reboot()
    elseif key == keys.x then
      term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
      term.clear(); term.setCursorPos(1, 1)
      print("Exited to CraftOS.")
      return
    end
  end
end

-- Keep a readable terminal buffer so authenticated Remote Desktop sessions can stream it.
if window and window.create then
  local parent = term.current()
  local width, height = term.getSize()
  local mirror = window.create(parent, 1, 1, width, height, true)
  term.redirect(mirror)
end

local ok, err = xpcall(function()
  -- Remote administration remains opt-in. The separate legacy diagnostics
  -- endpoint is an intentional, read-only Minecraft exploit-lab feature.
  parallel.waitForAny(
    function() require("os.desktop").run() end,
    function() require("os.remote").run() end,
    function() require("os.mail").run() end,
    function() require("os.legacy").run() end
  )
end, function(e)
  if e == "Terminated" then return "KL OS was terminated." end
  return debug.traceback(tostring(e), 2)
end)

if not ok then
  crash(err)
else
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
  term.clear(); term.setCursorPos(1, 1)
  print("Exited KL OS. Type 'reboot' to return.")
end
