-- KL Store: offline-ready application catalogue.
local ui = require("os.ui")
local Registry = require("os.appregistry")
local Store = {}

local CATALOG = {
  { id = "calculator", name = "Calculator", category = "Tools", version = "1.0.0", description = "A simple four-operation calculator.", source = "/store/packages/calculator.lua" },
  { id = "notes", name = "Notes", category = "Productivity", version = "1.0.0", description = "Create, browse and edit text notes in Documents.", source = "/store/packages/notes.lua" },
  { id = "monitor", name = "System Monitor", category = "System", version = "1.0.0", description = "View edition, version, memory, uptime and computer details.", source = "/store/packages/monitor.lua" },
  { id = "dice", name = "Dice Roller", category = "Games", version = "1.0.0", description = "Roll up to eight dice for games and roleplay.", source = "/store/packages/dice.lua" },
  { id = "diskmanager", name = "Floppy Disk Manager", category = "Storage", version = "1.0.0", description = "Browse multiple floppy drives and copy files between disks and your computer.", source = "/store/packages/diskmanager.lua" },
}

local function install(item)
  if not fs.exists(item.source) then return false, "Package source is missing: " .. item.source end
  fs.makeDir("/Applications")
  local target = "/Applications/" .. item.id .. ".lua"
  local staged = "/Applications/" .. item.id .. ".stage"
  if fs.exists(staged) then fs.delete(staged) end
  local copied, err = pcall(fs.copy, item.source, staged)
  if not copied then return false, tostring(err) end
  if fs.exists(target) then fs.delete(target) end
  local moved, moveErr = pcall(fs.move, staged, target)
  if not moved then
    if fs.exists(staged) then fs.copy(staged, target); fs.delete(staged) end
    if not fs.exists(target) then return false, tostring(moveErr) end
  end
  local registered, why = Registry.register(item.name, target, item.version)
  if not registered then fs.delete(target); return false, tostring(why) end
  return true
end

local function uninstall(item)
  local info = Registry.get(item.id)
  if info and info.path == "/Applications/" .. item.id .. ".lua" then fs.delete(info.path) end
  return Registry.unregister(item.id)
end

local function openInstalled(item)
  local info = Registry.get(item.id)
  if not info then ui.message("KL Store", "Install this app first."); return end
  local ok, result = pcall(dofile, info.path)
  if not ok then
    if result == "Terminated" or result == "__KL_WINDOW_CLOSE" or result == "__KL_WINDOW_MINIMIZE" then error(result, 0) end
    ui.message("App error", tostring(result))
  end
end

function Store.run()
  local selected = 1
  while true do
    local w, h = ui.size(); local T = ui.theme()
    selected = math.max(1, math.min(selected, #CATALOG))
    ui.clear(T.bg, T.fg); ui.header("KL Store", "APP CATALOGUE")
    ui.text(2, 2, "Discover and install apps for your computer.", T.fg, T.bg)
    ui.fill(2, 4, math.max(12, math.floor(w * 0.42)), h - 7, T.panel, T.panelfg)
    local listWidth = math.max(12, math.floor(w * 0.42))
    for i, item in ipairs(CATALOG) do
      local info = Registry.get(item.id)
      local mark = info and "[+] " or "[ ] "
      local label = mark .. item.name
      if i == selected then ui.text(3, 4 + i, ui.pad(label, listWidth - 2), T.selectedfg, T.selected)
      else ui.text(3, 4 + i, ui.pad(label, listWidth - 2), T.panelfg, T.panel) end
    end

    local item = CATALOG[selected]
    local dx = listWidth + 4
    local info = Registry.get(item.id)
    ui.text(dx, 5, item.name, T.accent, T.bg)
    ui.text(dx, 7, "Category: " .. item.category, T.fg, T.bg)
    ui.text(dx, 8, "Version:  " .. item.version, T.fg, T.bg)
    ui.text(dx, 10, item.description, T.fg, T.bg)
    ui.text(dx, 12, info and "Status: INSTALLED" or "Status: NOT INSTALLED", info and T.good or T.fg, T.bg)
    if info then ui.text(dx, 13, "Installed version: " .. tostring(info.version), T.fg, T.bg) end
    ui.text(2, h - 4, "Apps are bundled locally; no Internet is needed.", T.accent, T.bg)
    local main = ui.button(2, h - 2, info and "Open" or "Install", true)
    local remove = ui.button(13, h - 2, "Uninstall")
    local back = ui.button(w - 8, h - 2, "Back")

    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up then selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then selected = math.min(#CATALOG, selected + 1)
      elseif ev[2] == keys.enter then
        if info then openInstalled(item)
        else local ok, err = install(item); ui.message("KL Store", ok and (item.name .. " installed successfully. It is now available in Start.") or tostring(err)) end
      elseif ev[2] == keys.u and info then
        local ok, err = install(item); ui.message("KL Store", ok and "App updated." or tostring(err))
      elseif ev[2] == keys.delete and info then
        local answer = ui.input("Uninstall app", "Type REMOVE to uninstall " .. item.name .. ":", "")
        if answer == "REMOVE" then local ok, err = uninstall(item); ui.message("KL Store", ok and "App removed." or tostring(err)) end
      elseif ev[2] == keys.escape then return end
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        local idx = y - 4
        if x >= 2 and x <= listWidth + 1 and idx >= 1 and idx <= #CATALOG then selected = idx
        elseif ui.hit(main, x, y) then
          if info then openInstalled(item)
          else local ok, err = install(item); ui.message("KL Store", ok and (item.name .. " installed successfully. It is now available in Start.") or tostring(err)) end
        elseif ui.hit(remove, x, y) and info then
          local answer = ui.input("Uninstall app", "Type REMOVE to uninstall " .. item.name .. ":", "")
          if answer == "REMOVE" then local ok, err = uninstall(item); ui.message("KL Store", ok and "App removed." or tostring(err)) end
        elseif ui.hit(back, x, y) then return end
      end
    end
  end
end

return Store
