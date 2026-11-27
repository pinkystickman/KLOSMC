-- Security & Privacy Center for KL OS / HackOS.
-- All preferences and audit events are local to this computer; no telemetry is sent.
local ui = require("os.ui")
local privacy = require("os.privacy")
local remote = require("os.remote")
local legacy = require("os.legacy")
local web = require("server.webserver")
local A = {}

local function safeStatus(value) return value and "ON" or "OFF" end

local function toggleSetting(key, label)
  local nextValue = not privacy.get(key)
  local ok, err = privacy.set(key, nextValue)
  return ok, ok and (label .. " is now " .. safeStatus(nextValue) .. ".") or tostring(err)
end

local function drawHome(status)
  local w, h = ui.size(); local T = ui.theme()
  ui.clear(T.bg, T.fg); ui.header("Security & Privacy", "LOCAL")
  local securityOK, core = pcall(require, "security")
  local securityVersion = securityOK and core and core.getVersion and core.getVersion() or "missing"
  ui.text(2, 3, "Security core " .. tostring(securityVersion) .. " | Settings and logs are local-only", T.accent, T.bg)
  local discovery = privacy.get("network_discovery")
  local receive = privacy.get("mail_receive")
  local sendMail = privacy.get("mail_send")
  local exploitLab = privacy.get("exploit_lab")
  local remoteOn = remote.getStatus()
  local guest = legacy.getStatus()
  local host = web.getConfig()
  local rows = {
    { key="network_discovery", label="Network discovery", value=discovery, action=function() return toggleSetting("network_discovery", "Network discovery") end },
    { key="remote", label="Incoming remote admin", value=remoteOn, action=function()
      if remoteOn then
        local ok, err = remote.disable(); if ok then privacy.log("REMOTE_ACCESS_DISABLED", "Disabled in Security & Privacy") end
        return ok, ok and "Incoming remote administration disabled." or tostring(err)
      end
      local ok, pin = remote.enable()
      if ok then privacy.log("REMOTE_ACCESS_ENABLED", "Enabled in Security & Privacy"); return true, "Remote access enabled. Code: " .. tostring(pin) .. "  Share only with trusted players." end
      return false, tostring(pin)
    end },
    { key="mail_receive", label="Incoming mail", value=receive, action=function() return toggleSetting("mail_receive", "Incoming mail") end },
    { key="mail_send", label="Outgoing mail", value=sendMail, action=function() return toggleSetting("mail_send", "Outgoing mail") end },
    { key="exploit_lab", label="KL OS system exploit lab", value=exploitLab, danger=true, action=function() return toggleSetting("exploit_lab", "KL OS exploit lab") end },
    { key="guest", label="Guest diagnostics lab", value=guest, danger=true, action=function()
      local ok, err
      if guest then ok, err = legacy.patch() else ok, err = legacy.unpatch() end
      if ok then privacy.log("GUEST_DIAGNOSTICS", guest and "patched / disabled" or "exposed / enabled") end
      return ok, ok and (guest and "Guest diagnostics patched and disabled." or "Guest diagnostics exposed for the Minecraft lab.") or tostring(err)
    end },
    { key="hosting", label="Website hosting", value=host, action=function()
      local ok, err = web.setEnabled(not host)
      if ok then privacy.log("WEBSITE_HOSTING", not host and "enabled" or "disabled") end
      return ok, ok and (not host and "Website hosting enabled." or "Website hosting disabled.") or tostring(err)
    end },
  }
  local rects = {}
  local maxRows = math.min(#rows, math.max(1, h - 10))
  for i = 1, maxRows do
    local row = rows[i]
    local label = row.label .. "  [" .. safeStatus(row.value) .. "]"
    rects[i] = ui.button(2, 4 + i, label, false)
  end
  local rotate = ui.button(2, h - 5, "Rotate Remote Code")
  ui.text(21, h - 5, remoteOn and "Invalidates the previous code." or "Enable Remote first.", T.fg, T.bg)
  local statusY = h - 4
  ui.text(2, statusY, (status or "Ready"):sub(1, math.max(1, w - 3)), T.fg, T.bg)
  local scan = ui.button(2, h - 2, "Integrity Scan")
  local audit = ui.button(19, h - 2, "Audit Log")
  local lockdown = ui.button(31, h - 2, "Lockdown")
  local back = ui.button(math.max(2, w - 7), h - 1, "Back")
  return rows, rects, rotate, scan, audit, lockdown, back
end

local function showScan(report)
  local w, h = ui.size(); local T = ui.theme()
  while true do
    ui.clear(T.bg, T.fg); ui.header("System Integrity", "BASELINE")
    ui.text(2, 3, "Compared installed system files with recovery copies.", T.fg, T.bg)
    ui.text(2, 4, "Checked: " .. tostring(report.checked) .. "   Clean: " .. tostring(report.clean), T.good, T.bg)
    if #report.findings == 0 then
      ui.text(2, 6, "No integrity findings were detected.", T.good, T.bg)
    else
      ui.text(2, 6, "Findings: " .. tostring(#report.findings), T.accent, T.bg)
      local visible = math.min(#report.findings, math.max(1, math.floor((h - 12) / 2)))
      for i = 1, visible do
        local item = report.findings[i]
        local color = item.level == "HIGH" and T.bad or (item.level == "WARN" and T.accent or T.fg)
        ui.text(2, 7 + (i - 1) * 2, "[" .. item.level .. "] " .. item.path, color, T.bg)
        ui.text(4, 8 + (i - 1) * 2, item.detail, T.fg, T.bg)
      end
      if #report.findings > visible then ui.text(2, h - 4, "...and " .. tostring(#report.findings - visible) .. " more finding(s).", T.accent, T.bg) end
    end
    ui.text(2, h - 3, "This checks against a local baseline; it is not malware detection.", T.fg, T.bg)
    local back = ui.button(math.max(2, w - 8), h - 1, "Back")
    local ev = { os.pullEvent() }; local kind, x, y = ui.pointer(ev)
    if kind == "click" and ui.hit(back, x, y) then return end
    if ev[1] == "key" and ev[2] == keys.escape then return end
  end
end

local function showAudit()
  local w, h = ui.size(); local T = ui.theme()
  while true do
    local entries = privacy.getAudit(math.max(6, h - 8))
    ui.clear(T.bg, T.fg); ui.header("Security Audit Log", "LOCAL ONLY")
    ui.text(2, 3, "Recent security and privacy events (newest first)", T.accent, T.bg)
    if #entries == 0 then ui.text(2, 5, "No audit events have been recorded.", T.fg, T.bg) end
    for i, line in ipairs(entries) do ui.text(2, 4 + i, line, T.fg, T.bg) end
    ui.text(2, h - 2, "Log is stored locally in /hackos/security/audit.log", T.fg, T.bg)
    local clear = ui.button(2, h - 1, "Clear Log")
    local back = ui.button(math.max(2, w - 8), h - 1, "Back")
    local ev = { os.pullEvent() }; local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(back, x, y) then return
      elseif ui.hit(clear, x, y) then
        local answer = ui.input("Clear audit log", "Type CLEAR to delete local audit history:", "")
        if tostring(answer or ""):upper() == "CLEAR" then privacy.clearAudit() end
      end
    elseif ev[1] == "key" and ev[2] == keys.escape then return end
  end
end

function A.run()
  local status = "Ready. Settings and audit logs stay on this computer."
  while true do
    local rows, rects, rotate, scan, audit, lockdown, back = drawHome(status)
    local ev = { os.pullEvent() }; local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(back, x, y) then return
      elseif ui.hit(rotate, x, y) then
        local enabled = remote.getStatus()
        if not enabled then
          status = "Enable incoming Remote Access before rotating its code."
        else
          local answer = ui.input("Rotate Remote Access Code", "Generate a new code and invalidate the old one? Type ROTATE:", "")
          if tostring(answer or ""):upper() == "ROTATE" then
            local ok, value = remote.rotatePin()
            status = ok and "New remote access code: " .. tostring(value) .. "  Share only with trusted players." or tostring(value)
            if ok then ui.message("Remote Access Code", status) end
          else status = "Code rotation cancelled." end
        end
      elseif ui.hit(scan, x, y) then showScan(privacy.scanIntegrity())
      elseif ui.hit(audit, x, y) then showAudit()
      elseif ui.hit(lockdown, x, y) then
        local answer = ui.input("Emergency Privacy Lockdown", "Disable discovery, mail, remote access, the KL OS exploit lab, guest diagnostics and website hosting? Type LOCKDOWN:", "")
        if tostring(answer or ""):upper() == "LOCKDOWN" then
          local results = privacy.lockdown()
          status = "Lockdown applied: " .. table.concat(results, "; ")
        else status = "Lockdown cancelled." end
      else
        for i, rect in ipairs(rects) do
          if ui.hit(rect, x, y) then
            local ok, message = rows[i].action()
            status = message
            if not ok then ui.message("Setting failed", message) end
            break
          end
        end
      end
    elseif ev[1] == "key" then
      if ev[2] == keys.escape then return
      elseif ev[2] == keys.s then showScan(privacy.scanIntegrity())
      elseif ev[2] == keys.l then showAudit() end
    end
  end
end

return A
