-- KL OS / HackOS standalone recovery utility. Run `rescue.lua` from CraftOS.
local indexPath = "/hackos/recovery/index.json"
term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); term.clear(); term.setCursorPos(2, 2)
print("KL OS / HACKOS RECOVERY TOOL")
print()
if not fs.exists(indexPath) then print("Recovery image not found at " .. indexPath); print("Reinstall from the GitHub installer to rebuild it."); return end
local f = fs.open(indexPath, "r"); local raw = f.readAll(); f.close()
local index = textutils.unserializeJSON(raw)
if type(index) ~= "table" or type(index.paths) ~= "table" then print("Recovery index is damaged."); return end
local restored, failed = 0, 0
for _, path in ipairs(index.paths) do
  if type(path) == "string" and not path:find("..", 1, true) and not path:find("\\", 1, true) and not path:match("^/") then
    local backup = fs.combine("/hackos/recovery/files", path)
    if not fs.exists(path) then
      if fs.exists(backup) and not fs.isDir(backup) then
        local dir = fs.getDir(path); if dir ~= "" then fs.makeDir(dir) end
        local ok = pcall(fs.copy, backup, path)
        if ok and fs.exists(path) then restored = restored + 1 else failed = failed + 1 end
      else
        failed = failed + 1
      end
    end
  end
end
if fs.exists("/hackos/recovery/fault.json") and failed == 0 then fs.delete("/hackos/recovery/fault.json") end
print("Restored files: " .. restored)
print("Failed files: " .. failed)
if failed == 0 then print("Recovery complete. Press Enter to reboot."); read(); os.reboot() else print("Some files could not be restored. Reinstall HackOS / KL OS.") end
