-- KL OS / HackOS recovery manager. System-file damage is deliberate and recoverable.
local R = {}
local INDEX = "/hackos/recovery/index.json"
local FAULT = "/hackos/recovery/fault.json"

local function clean(path)
  if type(path) ~= "string" then return nil end
  path = path:gsub("^/+", "")
  if path == "" or path:find("..", 1, true) or path:find("\\", 1, true) or path:find(":", 1, true) then return nil end
  return path
end

function R.isSystemPath(path)
  path = clean(path)
  if not path then return false end
  return path == "startup.lua" or path == "rescue.lua" or path == "remote-access.lua" or path == "security.lua"
    or path:match("^os/") ~= nil or path:match("^apps/") ~= nil or path:match("^server/") ~= nil
end

local function readIndex()
  if not fs.exists(INDEX) then return { paths = {} } end
  local f = fs.open(INDEX, "r"); if not f then return { paths = {} } end
  local raw = f.readAll(); f.close()
  local obj = textutils.unserializeJSON(raw)
  if type(obj) ~= "table" or type(obj.paths) ~= "table" then return { paths = {} } end
  return obj
end

local function writeFault(path, reason)
  fs.makeDir("/hackos/recovery")
  local f = fs.open(FAULT, "w")
  if f then f.write(textutils.serialiseJSON({ path = path, reason = reason or "System file removed", time = os.clock() })); f.close() end
end

function R.restoreMissing()
  local index = readIndex()
  local restored, failed = {}, {}
  for _, rawPath in ipairs(index.paths) do
    local path = clean(rawPath)
    local backup = path and fs.combine("/hackos/recovery/files", path) or nil
    if path and backup and not fs.exists(path) then
      if fs.exists(backup) and not fs.isDir(backup) then
        local dir = fs.getDir(path); if dir ~= "" then fs.makeDir(dir) end
        local ok = pcall(fs.copy, backup, path)
        if ok and fs.exists(path) then restored[#restored + 1] = path else failed[#failed + 1] = path end
      else
        failed[#failed + 1] = path
      end
    end
  end
  if #failed == 0 and fs.exists(FAULT) then fs.delete(FAULT) end
  return restored, failed
end

local function drawBSOD(path, reason)
  local w, h = term.getSize()
  term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); term.clear()
  term.setCursorPos(2, 2); write("KL OS  /  HACKOS  SYSTEM RECOVERY")
  term.setCursorPos(2, 4); write(":(  The system encountered a problem")
  term.setCursorPos(2, 6); write("A required system file was removed.")
  term.setCursorPos(2, 8); write("File: " .. tostring(path))
  term.setCursorPos(2, 9); write(tostring(reason or "System file deletion simulated."):sub(1, math.max(1, w - 4)))
  term.setCursorPos(2, h - 4); write("Press R to repair system files from the recovery image.")
  term.setCursorPos(2, h - 3); write("Press X to exit to CraftOS (repair later with rescue.lua).")
  term.setCursorPos(2, h - 1); write("SYSTEM HALTED  |  RECOVERY IMAGE AVAILABLE")
end

function R.damageAndCrash(path, reason)
  path = clean(path)
  if not R.isSystemPath(path) then return false, "That is not a system file." end
  if not fs.exists(path) or fs.isDir(path) then return false, "System file does not exist or is a directory." end
  fs.delete(path)
  writeFault(path, reason or "Deleted from File Explorer")
  drawBSOD(path, reason)
  while true do
    local event, key = os.pullEvent("key")
    if key == keys.r then
      local restored, failed = R.restoreMissing()
      term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); term.clear(); term.setCursorPos(2, 3)
      if #failed == 0 and #restored > 0 then
        print("Recovery successful.")
        print("Restored " .. #restored .. " system file(s).")
        print("Rebooting into KL OS / HackOS...")
        sleep(2); os.reboot()
      else
        print("Recovery could not restore all missing files.")
        print("Restored: " .. #restored .. "  Failed: " .. #failed)
        print("Run rescue.lua from CraftOS after checking the recovery folder.")
        print("Press any key to retry.")
        os.pullEvent("key")
        drawBSOD(path, reason)
      end
    elseif key == keys.x then
      term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1, 1)
      print("System stopped. Run rescue.lua to repair the installation.")
      sleep(1)
      os.shutdown()
      return true
    end
  end
end

-- Used by the in-game KL OS exploit lab. It intentionally bypasses local GUI settings,
-- but only accepts a system path and only runs on a KL OS installation.
function R.remoteDelete(path, senderID)
  path = clean(path)
  if not R.isSystemPath(path) or not fs.exists(path) or fs.isDir(path) then return false, "Invalid or unavailable system file." end
  fs.delete(path)
  writeFault(path, "Removed by HackOS Government exploit lab from computer #" .. tostring(senderID))
  return true
end

function R.fault()
  if not fs.exists(FAULT) then return nil end
  local f = fs.open(FAULT, "r"); if not f then return nil end
  local raw = f.readAll(); f.close()
  local obj = textutils.unserializeJSON(raw)
  return type(obj) == "table" and obj or nil
end

return R
