-- Antivirus application. Security-core updates are isolated from normal OS updates.
-- The installer here deliberately performs a safe replace itself so it can repair
-- older security.lua versions whose fs.copy-over-existing update routine was faulty.
local ui = require("os.ui")
local security = require("security")
local A = {}

local BASE_URL = "https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/"
local SECURITY_PATH = "/security.lua"
local VERSION_PATH = "/hackos/security-version.cfg"
local STAGE_DIR = "/hackos/security-staging"
local BACKUP_DIR = "/hackos/security-backup"

local function validSource(path)
  return type(path) == "string" and path:sub(1, 17) == "security/payload/" and
    not path:match("^/") and not path:find("..", 1, true) and not path:find("\\", 1, true)
end

local function get(path)
  if not http or not http.get then return nil, "HTTP API is disabled" end
  local response, err = http.get(BASE_URL .. path)
  if not response then return nil, err end
  local body = response.readAll()
  response.close()
  return body
end

local function writeFile(path, body)
  local dir = fs.getDir(path)
  if dir ~= "" then fs.makeDir(dir) end
  local handle, err = fs.open(path, "w")
  if not handle then return false, err end
  local ok, why = pcall(function() handle.write(body); handle.close() end)
  if not ok then pcall(function() handle.close() end); return false, why end
  return true
end

local function restorePrevious(hadOld, backupFile, previousVersion)
  if fs.exists(SECURITY_PATH) then fs.delete(SECURITY_PATH) end
  local restored = true
  local restoreError
  if hadOld then
    if fs.exists(backupFile) then
      local ok, err = pcall(fs.copy, backupFile, SECURITY_PATH)
      restored = ok and fs.exists(SECURITY_PATH)
      restoreError = err
    else
      restored = false
      restoreError = "The previous security backup is missing."
    end
  end
  writeFile(VERSION_PATH, tostring(previousVersion or "1.0.0") .. "\n")
  return restored, restoreError
end

local function installPatch(state)
  if type(state) ~= "table" or not validSource(state.source) then
    return false, "The security update source is invalid."
  end
  local body, err = get(state.source)
  if not body then return false, "Could not download security patch: " .. tostring(err) end
  if #body == 0 or #body > 65536 then return false, "Security patch size is invalid." end
  local chunk, compileError = load(body, "@security.lua")
  if not chunk then return false, "Security patch failed Lua validation: " .. tostring(compileError) end

  fs.delete(STAGE_DIR)
  fs.makeDir(STAGE_DIR)
  local staged = STAGE_DIR .. "/security.lua"
  local stagedOK, stagedErr = writeFile(staged, body)
  if not stagedOK then fs.delete(STAGE_DIR); return false, "Could not stage patch: " .. tostring(stagedErr) end

  fs.delete(BACKUP_DIR)
  fs.makeDir(BACKUP_DIR)
  local backupFile = BACKUP_DIR .. "/security.lua"
  local hadOld = fs.exists(SECURITY_PATH)
  local previousVersion = security.getVersion()
  if hadOld then
    local backupOK, backupErr = pcall(fs.copy, SECURITY_PATH, backupFile)
    if not backupOK or not fs.exists(backupFile) then
      fs.delete(STAGE_DIR)
      return false, "Could not back up the installed security core: " .. tostring(backupErr)
    end
  end

  -- Never fs.copy onto an existing path: CC:Tweaked reports "File exists".
  if fs.exists(SECURITY_PATH) then fs.delete(SECURITY_PATH) end
  local moved, moveErr = pcall(fs.move, staged, SECURITY_PATH)
  if not moved or not fs.exists(SECURITY_PATH) then
    local restored, restoreErr = restorePrevious(hadOld, backupFile, previousVersion)
    fs.delete(STAGE_DIR)
    return false, "Could not install security patch: " .. tostring(moveErr) ..
      (restored and " Previous security core restored." or " " .. tostring(restoreErr))
  end

  local versionOK, versionErr = writeFile(VERSION_PATH, tostring(state.latest) .. "\n")
  if not versionOK then
    local restored, restoreErr = restorePrevious(hadOld, backupFile, previousVersion)
    fs.delete(STAGE_DIR)
    return false, "Could not save security version: " .. tostring(versionErr) ..
      (restored and " Previous security core restored." or " " .. tostring(restoreErr))
  end

  -- Update the recovery image using overwrite-capable file writes.
  local recoveryFile = "/hackos/recovery/files/security.lua"
  local recoveryOK = writeFile(recoveryFile, body)
  local indexPath = "/hackos/recovery/index.json"
  local index = { paths = {} }
  if fs.exists(indexPath) then
    local f = fs.open(indexPath, "r")
    if f then
      local parsed = textutils.unserializeJSON(f.readAll()); f.close()
      if type(parsed) == "table" and type(parsed.paths) == "table" then index = parsed end
    end
  end
  local found = false
  for _, path in ipairs(index.paths) do if path == "security.lua" then found = true; break end end
  if not found then index.paths[#index.paths + 1] = "security.lua" end
  if recoveryOK then writeFile(indexPath, textutils.serialiseJSON(index)) end

  fs.delete(STAGE_DIR)
  return true, tostring(state.latest)
end

local function draw(state, status)
  local w, h = ui.size()
  local T = ui.theme()
  ui.clear(T.bg, T.fg)
  ui.header("Antivirus", "PROTECTED SECURITY CHANNEL")
  ui.text(2, 3, "KL OS / HackOS Antivirus", T.accent, T.bg)
  ui.text(2, 5, "Protected file: /security.lua", T.fg, T.bg)
  ui.text(2, 6, "Installed security version: " .. security.getVersion(), T.fg, T.bg)
  ui.text(2, 8, "NORMAL OS UPDATES CANNOT REPLACE THIS FILE.", T.good, T.bg)
  ui.text(2, 9, "Security core patches are installed only here.", T.fg, T.bg)
  ui.text(2, 11, "Update status:", T.accent, T.bg)
  ui.text(2, 12, status or "Choose Check for Security Updates.", T.fg, T.bg)
  if state and state.ok then
    ui.text(2, 13, "Latest security version: " .. tostring(state.latest), T.fg, T.bg)
    if state.available then
      ui.text(2, 14, "A security patch is available.", T.good, T.bg)
      local note = tostring(state.notes or "")
      ui.text(2, 15, note:sub(1, math.max(0, w - 3)), T.fg, T.bg)
    else
      ui.text(2, 14, "Your security core is up to date.", T.good, T.bg)
    end
  elseif state and not state.ok then
    ui.text(2, 13, tostring(state.error or "Unknown update error"):sub(1, math.max(0, w - 3)), T.bad, T.bg)
  end
  local check = ui.button(2, h - 4, "Check for Security Updates")
  local install = ui.button(2, h - 3, "Install Available Patch")
  local back = ui.button(math.max(2, w - 8), h - 2, "Back")
  return check, install, back
end

function A.run()
  local state, status = nil, "Security core is protected from normal OS updates."
  while true do
    local check, install, back = draw(state, status)
    local ev = { os.pullEvent() }
    local kind, x, y = ui.pointer(ev)
    local doCheck = false
    local doInstall = false
    if kind == "click" then
      if ui.hit(back, x, y) then return
      elseif ui.hit(check, x, y) then doCheck = true
      elseif ui.hit(install, x, y) then doInstall = true end
    elseif ev[1] == "key" then
      if ev[2] == keys.escape then return
      elseif ev[2] == keys.c then doCheck = true
      elseif ev[2] == keys.i then doInstall = true end
    end

    if doCheck then
      status = "Checking the dedicated security update channel..."
      draw(state, status)
      state = security.checkForUpdates()
      if state.ok then
        status = state.available and "Security patch available. Review the release note before installing." or "No security patch is available."
      else
        status = "Security update check failed."
      end
    elseif doInstall then
      if not state or not state.ok or not state.available then
        status = "Check for security updates first."
      else
        local answer = ui.input("Install Security Patch", "Type UPDATE to install security version " .. state.latest .. ". The current security.lua will be backed up.", "")
        if tostring(answer or ""):upper() == "UPDATE" then
          status = "Downloading and validating the security patch..."
          draw(state, status)
          local ok, result = installPatch(state)
          if ok then
            ui.message("Security Update Installed", "Security core " .. tostring(result) .. " was installed. Your previous security.lua is backed up. The computer must reboot to activate the patch.")
            os.reboot()
            return
          else
            status = "Update failed: " .. tostring(result)
            state = security.checkForUpdates()
          end
        else
          status = "Security update cancelled."
        end
      end
    end
  end
end

return A
