-- Antivirus application. Security-core updates are isolated from normal OS updates.
local ui = require("os.ui")
local security = require("security")
local A = {}

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
          local ok, result = security.installLatest()
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
