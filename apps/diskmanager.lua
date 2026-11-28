-- KL Disk Manager: manage every discoverable CC:Tweaked disk-drive peripheral.
-- Floppy media remains mounted by CC:Tweaked at /disk, /disk2, ... and is not copied into OS storage.
local ui = require("os.ui")
local D = {}

local function containsType(value, wanted)
  if value == wanted then return true end
  if type(value) == "table" then
    for _, item in ipairs(value) do if item == wanted then return true end end
  end
  return false
end

local function getDrives()
  local result = {}
  if not peripheral or not peripheral.getNames then return result end
  for _, name in ipairs(peripheral.getNames()) do
    local kind = peripheral.getType(name)
    local isDrive = containsType(kind, "drive")
    if not isDrive and peripheral.hasType then
      local ok, yes = pcall(peripheral.hasType, name, "drive")
      isDrive = ok and yes == true
    end
    if not isDrive then
      local ok, wrapped = pcall(peripheral.wrap, name)
      isDrive = ok and type(wrapped) == "table" and type(wrapped.isDiskPresent) == "function" and type(wrapped.getMountPath) == "function"
    end
    if isDrive then
      local present, hasData, mount, label, id = false, false, nil, nil, nil
      pcall(function() present = disk.isPresent(name) end)
      pcall(function() hasData = disk.hasData(name) end)
      if hasData then pcall(function() mount = disk.getMountPath(name) end) end
      if present then pcall(function() label = disk.getLabel(name) end); pcall(function() id = disk.getID(name) end) end
      if mount then mount = fs.combine("/", mount) end
      result[#result + 1] = { name=name, present=present, hasData=hasData, mount=mount, label=label, id=id }
    end
  end
  table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
  return result
end

local function safeRelative(path)
  if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or path:find("\\", 1, true) then return nil end
  for part in path:gmatch("[^/]+") do if part == ".." or part == "." then return nil end end
  return path:gsub("^%./", "")
end

local function pathExists(path)
  local ok, exists = pcall(fs.exists, path)
  return ok and exists
end

local function ensureDir(path)
  local parent = fs.getDir(path)
  if parent and parent ~= "" then fs.makeDir(parent) end
end

local function copyPath(source, destination, overwrite)
  if not pathExists(source) then return false, "Source does not exist." end
  if pathExists(destination) then
    if not overwrite then return false, "Destination already exists." end
    local ok, err = pcall(fs.delete, destination)
    if not ok then return false, tostring(err) end
  end
  ensureDir(destination)
  local ok, err = pcall(fs.copy, source, destination)
  if not ok then return false, tostring(err) end
  if not pathExists(destination) then return false, "Copy did not create the destination." end
  return true
end

local function diskListing(drive)
  if not drive or not drive.mount or not pathExists(drive.mount) then return {} end
  local ok, names = pcall(fs.list, drive.mount)
  if not ok or type(names) ~= "table" then return {} end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  local out = {}
  for _, name in ipairs(names) do
    local full = fs.combine(drive.mount, name)
    out[#out + 1] = (fs.isDir(full) and "[DIR] " or "[FILE]") .. name
  end
  return out
end

local function freeSpace(path)
  if not path then return "n/a" end
  local ok, free = pcall(fs.getFreeSpace, path)
  if not ok or type(free) ~= "number" then return "unknown" end
  if free == math.huge then return "unlimited" end
  return tostring(math.floor(free)) .. " bytes free"
end

local function copyFromDisk(drive)
  if not drive or not drive.mount then ui.message("Disk Manager", "Select a drive with a data floppy inserted first."); return end
  local relative = ui.input("Copy from floppy", "Path relative to disk root (example: notes.txt):", "")
  if not relative or relative == "" then return end
  relative = safeRelative(relative)
  if not relative then ui.message("Copy blocked", "Use a relative path. Parent folders and absolute paths are not allowed."); return end
  local source = fs.combine(drive.mount, relative)
  if not pathExists(source) then ui.message("Copy failed", "The selected path is not on this disk."); return end
  local defaultName = fs.getName(relative)
  local targetInput = ui.input("Save to computer", "Destination under /Documents or /HackOS-Lab:", "/Documents/" .. defaultName)
  if not targetInput or targetInput == "" or targetInput:find("\\", 1, true) or targetInput:find("..", 1, true) then return end
  local destination = fs.combine("/", targetInput)
  local allowed = destination:match("^/Documents/.+") or destination:match("^/HackOS%-Lab/.+")
  if not allowed or destination == "/Documents" or destination == "/HackOS-Lab" then
    ui.message("Copy blocked", "Choose a destination inside /Documents or /HackOS-Lab."); return
  end
  local overwrite = false
  if pathExists(destination) then
    overwrite = ui.input("Confirm overwrite", "Type OVERWRITE to replace " .. destination .. ":", "") == "OVERWRITE"
    if not overwrite then return end
  end
  fs.makeDir("/Documents"); fs.makeDir("/HackOS-Lab")
  local ok, err = copyPath(source, destination, overwrite)
  ui.message("Copy from floppy", ok and ("Copied to " .. destination) or tostring(err))
end

local function copyToDisk(drive)
  if not drive or not drive.mount then ui.message("Disk Manager", "Select a drive with a data floppy inserted first."); return end
  local sourceInput = ui.input("Copy to floppy", "Path under Documents, www, Applications or HackOS-Lab:", "/Documents/")
  if not sourceInput or sourceInput == "" then return end
  if sourceInput:find("\\", 1, true) or sourceInput:find("..", 1, true) then ui.message("Copy blocked", "Invalid source path."); return end
  local source = fs.combine("/", sourceInput)
  local allowed = source:match("^/Documents/.+") or source:match("^/www/.+") or source:match("^/Applications/.+") or source:match("^/HackOS%-Lab/.+")
  if not allowed or source == "/Documents" or source == "/www" or source == "/Applications" or source == "/HackOS-Lab" then
    ui.message("Copy blocked", "Only user data under /Documents, /www, /Applications or /HackOS-Lab can be copied to removable media."); return
  end
  if not pathExists(source) then ui.message("Copy failed", "The source file or folder does not exist."); return end
  local relative = ui.input("Save on floppy", "Destination path relative to disk root:", fs.getName(source))
  if not relative or relative == "" then return end
  relative = safeRelative(relative)
  if not relative then ui.message("Copy blocked", "Use a relative path. Parent folders and absolute paths are not allowed."); return end
  local destination = fs.combine(drive.mount, relative)
  local overwrite = false
  if pathExists(destination) then
    overwrite = ui.input("Confirm overwrite", "Type OVERWRITE to replace the disk item:", "") == "OVERWRITE"
    if not overwrite then return end
  end
  local ok, err = copyPath(source, destination, overwrite)
  ui.message("Copy to floppy", ok and ("Copied " .. source .. " to " .. destination) or tostring(err))
end

local function labelDisk(drive)
  if not drive or not drive.present then ui.message("Disk label", "Insert a floppy first."); return end
  local current = drive.label or ""
  local label = ui.input("Disk label", "Enter a new label (leave blank to clear):", current)
  if label == nil then return end
  local newLabel = label
  if label == "" then newLabel = nil end
  local ok, err = pcall(disk.setLabel, drive.name, newLabel)
  ui.message("Disk label", ok and "Disk label updated." or tostring(err))
end

local function ejectDisk(drive)
  if not drive or not drive.present then ui.message("Eject disk", "No media is inserted in this drive."); return end
  local answer = ui.input("Eject disk", "Type EJECT to eject media from " .. drive.name .. ":", "")
  if answer ~= "EJECT" then return end
  local ok, err = pcall(disk.eject, drive.name)
  ui.message("Eject disk", ok and "Eject request sent." or tostring(err))
end

function D.run()
  local drives, selected, status = getDrives(), 1, "Ready"
  while true do
    local w, h = ui.size(); local T = ui.theme()
    drives = drives or getDrives()
    if selected > #drives then selected = math.max(1, #drives) end
    ui.clear(T.bg, T.fg); ui.header("KL Disk Manager", "REMOVABLE STORAGE")
    ui.text(2, 3, "Detected disk drives: " .. #drives .. "  |  Each inserted floppy is a separate volume.", T.fg, T.bg)
    local leftW = math.max(15, math.floor(w * 0.42))
    ui.fill(2, 5, leftW, math.max(2, h - 9), T.panel, T.panelfg)
    ui.text(3, 5, "DRIVES", T.accent, T.panel)
    local visibleDrives = math.min(#drives, math.max(1, h - 13))
    for i, drive in ipairs(drives) do
      if i > visibleDrives then break end
      local marker = i == selected and ">" or " "
      local media = drive.mount and "MOUNTED" or (drive.present and "MEDIA" or "EMPTY")
      local label = drive.label or drive.name
      local line = marker .. " " .. drive.name .. " " .. media
      if i == selected then ui.text(3, 6 + i, ui.pad(line, leftW - 2), T.selectedfg, T.selected)
      else ui.text(3, 6 + i, ui.pad(line, leftW - 2), T.panelfg, T.panel) end
    end
    local drive = drives[selected]
    local dx = leftW + 4
    ui.text(dx, 5, drive and (drive.label or drive.name) or "No drive selected", T.accent, T.bg)
    if drive then
      ui.text(dx, 7, "Peripheral: " .. drive.name, T.fg, T.bg)
      ui.text(dx, 8, "Disk ID: " .. tostring(drive.id or "--"), T.fg, T.bg)
      ui.text(dx, 9, "Mount: " .. tostring(drive.mount or "not mounted"), T.fg, T.bg)
      ui.text(dx, 10, "Storage: " .. freeSpace(drive.mount), T.fg, T.bg)
      ui.text(dx, 12, "FILES ON DISK", T.accent, T.bg)
      local entries = diskListing(drive)
      if #entries == 0 then ui.text(dx, 13, drive.mount and "(empty disk)" or "Insert a data floppy", T.fg, T.bg)
      else
        for i = 1, math.min(#entries, math.max(1, h - 17)) do ui.text(dx, 12 + i, entries[i], T.fg, T.bg) end
      end
    else
      ui.text(dx, 7, "No disk drives detected.", T.fg, T.bg)
      ui.text(dx, 9, "Place a Disk Drive next to this computer,", T.fg, T.bg)
      ui.text(dx, 10, "or expose it through a wired modem.", T.fg, T.bg)
      ui.text(dx, 12, "Insert a floppy and press R to refresh.", T.accent, T.bg)
    end
    ui.text(2, h - 4, "R Scan  I Copy from disk  O Copy to disk  L Label  E Eject", T.accent, T.bg)
    ui.text(2, h - 3, "Click a drive to select it  |  Esc: back", T.fg, T.bg)
    ui.text(2, h - 2, status, T.fg, T.bg)
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.escape then return
      elseif ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(math.max(1, #drives), selected + 1)
      elseif ev[2] == keys.r then drives = getDrives(); selected = math.min(selected, math.max(1, #drives)); status = "Refreshed: " .. #drives .. " drive(s)"
      elseif ev[2] == keys.i then copyFromDisk(drives[selected])
      elseif ev[2] == keys.o then copyToDisk(drives[selected])
      elseif ev[2] == keys.l then labelDisk(drives[selected])
      elseif ev[2] == keys.e then ejectDisk(drives[selected]) end
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        if x >= 3 and x <= leftW + 2 and y >= 7 and y <= 6 + math.min(#drives, math.max(1, h - 13)) then
          local index = y - 6
          if drives[index] then selected = index end
        elseif y == h - 4 then
          if x < 11 then drives = getDrives(); status = "Refreshed"
          elseif x < 25 then copyFromDisk(drives[selected])
          elseif x < 39 then copyToDisk(drives[selected])
          elseif x < 48 then labelDisk(drives[selected])
          else ejectDisk(drives[selected]) end
        end
      end
    end
  end
end

return D
