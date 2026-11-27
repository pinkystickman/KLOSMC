-- KL OS / HackOS dual-edition startup (2.8.0).
package.path = "/?.lua;/?/init.lua;" .. package.path

local function repairMissing()
  local indexPath = "/hackos/recovery/index.json"
  if not fs.exists(indexPath) then return 0, { "Recovery image not found. Run install.lua again." } end
  local f = fs.open(indexPath, "r")
  if not f then return 0, { "Cannot read recovery index." } end
  local raw = f.readAll(); f.close()
  local index = textutils.unserializeJSON(raw)
  if type(index) ~= "table" or type(index.paths) ~= "table" then return 0, { "Recovery index is invalid." } end
  local count, failed = 0, {}
  for _, path in ipairs(index.paths) do
    if type(path) == "string" and not path:find("..", 1, true) and not path:find("\\", 1, true) and not path:match("^/") then
      local backup = fs.combine("/hackos/recovery/files", path)
      if not fs.exists(path) then
        if fs.exists(backup) and not fs.isDir(backup) then
          local dir = fs.getDir(path); if dir ~= "" then fs.makeDir(dir) end
          local ok = pcall(fs.copy, backup, path)
          if ok and fs.exists(path) then count = count + 1 else failed[#failed + 1] = path end
        else
          failed[#failed + 1] = path
        end
      end
    end
  end
  if #failed == 0 and fs.exists("/hackos/recovery/fault.json") then fs.delete("/hackos/recovery/fault.json") end
  return count, failed
end

local function crash(err)
  local w, h = term.getSize()
  term.setBackgroundColor(colors.blue); term.setTextColor(colors.white)
  term.clear(); term.setCursorPos(2, 2)
  print("KL OS / HACKOS  |  SYSTEM RECOVERY")
  term.setCursorPos(2, 4); print(":(  The operating system stopped unexpectedly.")
  term.setCursorPos(2, 6); print("A system component may be missing or damaged.")
  local lines = require("cc.strings").wrap(tostring(err), math.max(10, w - 4))
  for i = 1, math.min(#lines, math.max(1, h - 11)) do term.setCursorPos(2, 7 + i); print(lines[i]) end
  term.setCursorPos(2, h - 3); write("[R] Repair missing system files and reboot")
  term.setCursorPos(2, h - 2); write("[X] Exit to CraftOS (run rescue.lua to repair later)")
  while true do
    local _, key = os.pullEventRaw("key")
    if key == keys.r then
      local restored, failed = repairMissing()
      term.setCursorPos(2, h - 1)
      if #failed == 0 then
        term.setTextColor(colors.lime); write("Restored " .. restored .. " file(s). Rebooting...")
        sleep(2); os.reboot()
      else
        term.setTextColor(colors.white); write("Repair incomplete: " .. #failed .. " file(s) failed. Use rescue.lua.")
      end
    elseif key == keys.x then
      term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
      term.clear(); term.setCursorPos(1, 1)
      print("Exited to CraftOS. Run rescue.lua to repair the OS.")
      return
    end
  end
end

-- Keep a readable terminal buffer so Remote Desktop can mirror the CC terminal.
if window and window.create then
  local parent = term.current()
  local width, height = term.getSize()
  local mirror = window.create(parent, 1, 1, width, height, true)
  term.redirect(mirror)
end

local ok, err = xpcall(function()
  parallel.waitForAny(
    function() require("os.desktop").run() end,
    function() require("os.remote").run() end,
    function() require("os.mail").run() end,
    function() require("os.legacy").run() end,
    function() require("server.webserver").service() end
  )
end, function(e)
  return debug.traceback(tostring(e), 2)
end)

if not ok then crash(err) end
term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
term.clear(); term.setCursorPos(1, 1)
print("Exited HackOS. Type 'reboot' to return.")
