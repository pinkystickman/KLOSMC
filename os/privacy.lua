-- KL OS / HackOS Security & Privacy service.
-- Preferences and audit events are stored locally; this module sends no telemetry.
local P = {}
local CONFIG = "/hackos/privacy.json"
local AUDIT = "/hackos/security/audit.log"
local DEFAULTS = {
  network_discovery = true,
  mail_receive = true,
  mail_send = true,
  exploit_lab = true,
}
local VALID = { network_discovery = true, mail_receive = true, mail_send = true, exploit_lab = true }

local function readAll(path)
  if not fs.exists(path) or fs.isDir(path) then return nil end
  local f = fs.open(path, "r")
  if not f then return nil end
  local data = f.readAll(); f.close()
  return data
end

local function readConfig()
  fs.makeDir("/hackos")
  local cfg = {}
  for key, value in pairs(DEFAULTS) do cfg[key] = value end
  local raw = readAll(CONFIG)
  if raw then
    local ok, saved = pcall(textutils.unserializeJSON, raw)
    if ok and type(saved) == "table" then
      for key in pairs(VALID) do
        if type(saved[key]) == "boolean" then cfg[key] = saved[key] end
      end
    end
  end
  return cfg
end

local function writeConfig(cfg)
  fs.makeDir("/hackos")
  local f, err = fs.open(CONFIG, "w")
  if not f then return false, err end
  local ok, why = pcall(function() f.write(textutils.serialiseJSON(cfg)); f.close() end)
  if not ok then pcall(function() f.close() end); return false, why end
  return true
end

local function clean(value, maxLength)
  value = tostring(value or "")
  value = value:gsub("[\r\n\t]", " "):gsub("%s+", " ")
  return value:sub(1, maxLength or 100)
end

function P.log(action, details)
  fs.makeDir("/hackos/security")
  local f = fs.open(AUDIT, "a")
  if not f then return false, "Could not open local audit log." end
  local stamp = "uptime " .. tostring(math.floor(os.clock()))
  if textutils and textutils.formatTime and os.time then
    local ok, value = pcall(textutils.formatTime, os.time(), true)
    if ok and value then stamp = value end
  end
  f.write(stamp .. " | PC #" .. tostring(os.getComputerID()) .. " | " .. clean(action, 40) .. " | " .. clean(details, 100) .. "\n")
  f.close()
  -- Keep the local audit log bounded to the newest 160 entries.
  local raw = readAll(AUDIT) or ""
  local lines = {}
  for line in raw:gmatch("([^\n]+)") do lines[#lines + 1] = line end
  if #lines > 160 then
    local out = {}
    for i = #lines - 159, #lines do out[#out + 1] = lines[i] end
    local trimmed = fs.open(AUDIT, "w")
    if trimmed then trimmed.write(table.concat(out, "\n") .. "\n"); trimmed.close() end
  end
  return true
end

function P.get(key)
  if not VALID[key] then return nil end
  return readConfig()[key]
end

function P.set(key, value)
  if not VALID[key] or type(value) ~= "boolean" then return false, "Unknown privacy setting." end
  local cfg = readConfig()
  if cfg[key] == value then return true end
  cfg[key] = value
  local ok, err = writeConfig(cfg)
  if ok then
    P.log("PRIVACY_SETTING", key .. "=" .. tostring(value))
    if key == "exploit_lab" and value == false then
      local loaded, legacy = pcall(require, "os.legacy")
      if loaded and legacy and legacy.revokeLabSessions then legacy.revokeLabSessions() end
    end
  end
  return ok, err
end

function P.getSettings()
  return readConfig()
end

function P.getAudit(limit)
  local raw = readAll(AUDIT) or ""
  local rows = {}
  for line in raw:gmatch("([^\n]+)") do rows[#rows + 1] = line end
  local out = {}
  local first = math.max(1, #rows - (tonumber(limit) or 20) + 1)
  for i = #rows, first, -1 do out[#out + 1] = rows[i] end
  return out
end

function P.clearAudit()
  if fs.exists(AUDIT) then fs.delete(AUDIT) end
  P.log("AUDIT_CLEARED", "Local audit history was cleared by the user")
  return true
end

local function safeRelative(path)
  return type(path) == "string" and path ~= "" and not path:match("^/") and
    not path:find("..", 1, true) and not path:find("\\", 1, true)
end

function P.scanIntegrity()
  local report = { checked = 0, clean = 0, findings = {} }
  local raw = readAll("/hackos/recovery/index.json")
  local index
  if raw then
    local ok, value = pcall(textutils.unserializeJSON, raw)
    if ok and type(value) == "table" and type(value.paths) == "table" then index = value end
  end
  if not index then
    report.findings[#report.findings + 1] = { level = "WARN", path = "Recovery image", detail = "No valid recovery index is installed. Reinstall or repair the OS to create a baseline." }
  else
    for _, path in ipairs(index.paths) do
      if safeRelative(path) then
        local livePath = fs.combine("/", path)
        local backup = fs.combine("/hackos/recovery/files", path)
        report.checked = report.checked + 1
        if not fs.exists(livePath) or fs.isDir(livePath) then
          report.findings[#report.findings + 1] = { level = "HIGH", path = path, detail = "System file is missing." }
        elseif not fs.exists(backup) or fs.isDir(backup) then
          report.findings[#report.findings + 1] = { level = "WARN", path = path, detail = "Recovery baseline is missing; this file could not be verified." }
        else
          local current, baseline = readAll(livePath), readAll(backup)
          if current ~= nil and baseline ~= nil and current == baseline then
            report.clean = report.clean + 1
          else
            report.findings[#report.findings + 1] = { level = "WARN", path = path, detail = "File differs from the local recovery baseline. This may be an intentional customization." }
          end
        end
      end
    end
  end

  local securityPath = "/security.lua"
  if not fs.exists(securityPath) then
    report.findings[#report.findings + 1] = { level = "HIGH", path = securityPath, detail = "Protected security core is missing." }
  else
    local ok, core = pcall(require, "security")
    if not ok or type(core) ~= "table" or type(core.getVersion) ~= "function" then
      report.findings[#report.findings + 1] = { level = "HIGH", path = securityPath, detail = "Security core could not be loaded." }
    end
  end

  local legacyOK, legacy = pcall(require, "os.legacy")
  if legacyOK and legacy and legacy.getStatus and legacy.getStatus() then
    report.findings[#report.findings + 1] = { level = "HIGH", path = "Guest diagnostics", detail = "The intentionally vulnerable read-only diagnostics lab is exposed." }
  end
  local remoteOK, remote = pcall(require, "os.remote")
  if remoteOK and remote and remote.getStatus then
    local enabled = remote.getStatus()
    if enabled then report.findings[#report.findings + 1] = { level = "INFO", path = "Remote access", detail = "Incoming remote administration is enabled. Keep the access code private." } end
  end
  if P.get("network_discovery") then
    report.findings[#report.findings + 1] = { level = "INFO", path = "Network discovery", detail = "This computer responds to nearby rednet discovery requests." }
  end
  if P.get("exploit_lab") then
    report.findings[#report.findings + 1] = { level = "WARN", path = "KL OS exploit lab", detail = "The intentional Government-to-Standard system-file attack is enabled for Minecraft lab use." }
  end
  local registryOK, registry = pcall(require, "os.appregistry")
  if registryOK and registry and registry.list then
    local apps = registry.list()
    if #apps > 0 then
      report.findings[#report.findings + 1] = { level = "INFO", path = "Installed apps", detail = tostring(#apps) .. " user-installed Lua app(s) can run with normal CraftOS permissions. Install only trusted code." }
    end
  end
  report.ok = #report.findings == 0
  P.log("INTEGRITY_SCAN", tostring(report.checked) .. " system files checked; " .. tostring(#report.findings) .. " finding(s)")
  return report
end

function P.lockdown()
  local results = {}
  local function record(label, ok, err) results[#results + 1] = label .. ": " .. (ok and "OFF" or tostring(err or "failed")) end
  local ok, err = P.set("network_discovery", false); record("Network discovery", ok, err)
  ok, err = P.set("mail_receive", false); record("Incoming mail", ok, err)
  ok, err = P.set("mail_send", false); record("Outgoing mail", ok, err)
  ok, err = P.set("exploit_lab", false); record("KL OS exploit lab", ok, err)
  local remoteOK, remote = pcall(require, "os.remote")
  if remoteOK then ok, err = remote.disable(); record("Remote access", ok, err) end
  local legacyOK, legacy = pcall(require, "os.legacy")
  if legacyOK then ok, err = legacy.patch(); record("Guest diagnostics", ok, err) end
  local webOK, web = pcall(require, "server.webserver")
  if webOK then ok, err = web.setEnabled(false); record("Website hosting", ok, err) end
  P.log("PRIVACY_LOCKDOWN", "Emergency privacy lockdown activated")
  return results
end

return P
