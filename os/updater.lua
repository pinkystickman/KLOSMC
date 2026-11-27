-- Transactional OS updater. Downloads the selected edition into staging before replacing system files.
local ui = require("os.ui")
local U = {}
local BASE_URL = "https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/"

local function safePath(path)
  return type(path) == "string" and path ~= "" and not path:match("^/") and
    not path:find("..", 1, true) and not path:find("\\", 1, true)
end

local function get(path)
  local response, err = http.get(BASE_URL .. path)
  if not response then return nil, err end
  local body = response.readAll()
  response.close()
  return body
end

local function readEdition()
  if fs.exists("/hackos/edition.cfg") then
    local f = fs.open("/hackos/edition.cfg", "r")
    if f then local value = f.readAll():gsub("%s+$", ""); f.close(); if value == "standard" or value == "government" then return value end end
  end
  return "standard"
end

local function versionCompare(a, b)
  local function parts(value)
    local out = {}
    for number in tostring(value or "0"):gmatch("%d+") do out[#out + 1] = tonumber(number) or 0 end
    while #out < 3 do out[#out + 1] = 0 end
    return out
  end
  local aa, bb = parts(a), parts(b)
  for i = 1, math.max(#aa, #bb) do
    local av, bv = aa[i] or 0, bb[i] or 0
    if av < bv then return -1 elseif av > bv then return 1 end
  end
  return 0
end

local function write(path, body)
  local dir = fs.getDir(path)
  if dir ~= "" then fs.makeDir(dir) end
  local f, err = fs.open(path, "w")
  if not f then return false, err end
  local ok, why = pcall(function() f.write(body); f.close() end)
  if not ok then pcall(function() f.close() end); return false, why end
  return true
end

local function drawProgress(title, detail, current, total)
  local w, h = ui.size()
  local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header(title)
  ui.text(2, 4, detail, T.fg, T.bg)
  local bw = math.max(8, w - 8)
  local n = math.floor(bw * current / math.max(1, total))
  ui.text(2, 6, "[" .. ("#"):rep(n) .. ("-"):rep(math.max(0, bw - n)) .. "]", T.accent, T.bg)
  ui.text(2, 7, tostring(current) .. " / " .. tostring(total), T.fg, T.bg)
end

function U.run()
  if not http then ui.message("OS Update", "HTTP API is disabled. Enable it in the CC:Tweaked server configuration, then try again."); return end
  local edition = readEdition()
  local w, h = ui.size(); local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header("OS Update")
  ui.text(2, 3, "Current edition: " .. edition:upper(), T.fg, T.bg)
  ui.text(2, 5, "Check GitHub for the newest KL OS / HackOS build?", T.fg, T.bg)
  ui.text(2, 7, "User files in /Documents and websites in /www are preserved.", T.accent, T.bg)
  ui.text(2, 8, "Protected /security.lua is excluded. Use Antivirus for security patches.", T.good, T.bg)
  local yes = ui.button(2, h - 2, "Check for updates", true)
  local no = ui.button(23, h - 2, "Back")
  while true do
    local ev = { os.pullEvent() }
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(no, x, y) then return end
      if ui.hit(yes, x, y) then break end
    elseif ev[1] == "key" and (ev[2] == keys.enter or ev[2] == keys.space) then break
    elseif ev[1] == "key" and ev[2] == keys.escape then return end
  end

  local manifestRaw, manifestErr = get("manifest.json")
  if not manifestRaw then ui.message("Update failed", "Could not download manifest.json: " .. tostring(manifestErr)); return end
  local manifest = textutils.unserializeJSON(manifestRaw)
  if type(manifest) ~= "table" or type(manifest.editions) ~= "table" then ui.message("Update failed", "The update manifest is invalid."); return end
  local selected = manifest.editions[edition]
  if type(selected) ~= "table" or type(selected.files) ~= "table" then ui.message("Update failed", "No files were found for edition " .. edition .. "."); return end
  local version = tostring(manifest.version or "unknown")
  local currentVersion = "unknown"
  if fs.exists("/hackos/version.cfg") then local f = fs.open("/hackos/version.cfg", "r"); if f then currentVersion = f.readAll():gsub("%s+$", ""); f.close() end end
  if currentVersion == version then ui.message("OS Update", "You are already running version " .. version .. "."); return end
  if currentVersion ~= "unknown" and versionCompare(version, currentVersion) < 0 then
    ui.message("Update unavailable", "The GitHub repository currently offers " .. version .. ", which is older than your installed " .. currentVersion .. ". Upload the newer release files to the repository first.")
    return
  end

  local files, protectedSecurityPreserved, securityBootstrapped = {}, false, false
  for _, item in ipairs(selected.files) do
    local source, target, channel
    if type(item) == "string" then source, target = item, item
    else source, target, channel = item.source, item.target, item.channel end
    if not safePath(source) or not safePath(target) then ui.message("Update failed", "Unsafe file path in update manifest."); return end
    if channel == "security" or target == "security.lua" then
      if fs.exists("/security.lua") then
        protectedSecurityPreserved = true
      else
        -- One-time bootstrap for upgrades from releases that did not have the protected core.
        files[#files + 1] = { source = source, target = target }
        securityBootstrapped = true
      end
    else
      files[#files + 1] = { source = source, target = target }
    end
  end
  files[#files + 1] = { source = "install.lua", target = "install.lua" }
  files[#files + 1] = { source = "manifest.json", target = "manifest.json" }

  local downloaded = {}
  fs.delete("/hackos/update-staging")
  fs.makeDir("/hackos/update-staging")
  for i, item in ipairs(files) do
    drawProgress("Downloading OS Update", item.source, i - 1, #files)
    local body, err = get(item.source)
    if not body then fs.delete("/hackos/update-staging"); ui.message("Update failed", "Download failed for " .. item.source .. ": " .. tostring(err)); return end
    downloaded[item.target] = body
    local stage = fs.combine("/hackos/update-staging", item.target)
    local ok, why = write(stage, body)
    if not ok then fs.delete("/hackos/update-staging"); ui.message("Update failed", "Could not stage " .. item.target .. ": " .. tostring(why)); return end
  end

  -- Keep rollback copies so a failed write cannot leave a half-updated OS.
  fs.delete("/hackos/update-backup")
  fs.makeDir("/hackos/update-backup")
  local paths = {}
  for path in pairs(downloaded) do paths[#paths + 1] = path end
  table.sort(paths)
  local existed = {}
  for _, path in ipairs(paths) do
    if fs.exists(path) then
      existed[path] = true
      local backup = fs.combine("/hackos/update-backup", path)
      local dir = fs.getDir(backup); if dir ~= "" then fs.makeDir(dir) end
      fs.copy(path, backup)
    end
  end

  local applied, failure = {}, nil
  for i, path in ipairs(paths) do
    drawProgress("Installing OS Update", "Writing " .. path, i - 1, #paths)
    applied[#applied + 1] = path
    local ok, err = write(path, downloaded[path])
    if not ok then failure = "Could not write " .. path .. ": " .. tostring(err); break end
  end

  if failure then
    for _, path in ipairs(applied) do
      if existed[path] then fs.copy(fs.combine("/hackos/update-backup", path), path) else fs.delete(path) end
    end
    fs.delete("/hackos/update-staging")
    ui.message("Update rolled back", failure .. "\nPrevious system files were restored.")
    return
  end

  fs.makeDir("/hackos")
  write("/hackos/version.cfg", version .. "\n")
  -- Refresh the recovery image to the new release, so future system-file repair restores this version.
  fs.makeDir("/hackos/recovery/files")
  local recoveryOK = true
  for _, path in ipairs(paths) do
    local backupPath = fs.combine("/hackos/recovery/files", path)
    local ok = write(backupPath, downloaded[path])
    if not ok then recoveryOK = false end
  end
  if fs.exists("/security.lua") then
    local securityBackup = "/hackos/recovery/files/security.lua"
    local copied, copyErr = pcall(fs.copy, "/security.lua", securityBackup)
    if copied then
      local found = false
      for _, existingPath in ipairs(paths) do if existingPath == "security.lua" then found = true; break end end
      if not found then paths[#paths + 1] = "security.lua" end
    else
      recoveryOK = false
    end
  end
  if recoveryOK then
    table.sort(paths)
    write("/hackos/recovery/index.json", textutils.serialiseJSON({ version = version, edition = edition, paths = paths }))
  end
  fs.delete("/hackos/update-staging")
  ui.message("Update complete", "Installed " .. version .. " for " .. edition:upper() .. ".\nYour documents, mail and website files were preserved." ..
    (protectedSecurityPreserved and "\nProtected /security.lua was NOT changed. Use Antivirus > Check for Security Updates." or "") ..
    (securityBootstrapped and "\nBaseline /security.lua was installed and is now protected." or "") ..
    (recoveryOK and "\nRecovery image refreshed." or "\nWarning: recovery image could not be refreshed.") .. "\nThe computer will reboot now.")
  os.reboot()
end

return U
