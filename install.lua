-- KL OS installer
local BASE_URL = "https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/"

if not http then printError("The HTTP API is disabled on this server.") return end

local function get(path)
  local r, err = http.get(BASE_URL .. path)
  if not r then return nil, err end
  local body = r.readAll()
  r.close()
  return body
end

print("KL OS installer")
local raw, err = get("manifest.json")
if not raw then printError("manifest.json: " .. tostring(err)) return end
local m = textutils.unserialiseJSON(raw)
if type(m) ~= "table" or type(m.files) ~= "table" then printError("Invalid manifest.json") return end

print(("Installing %s v%s"):format(m.name or "KL OS", m.version or "?"))
print() print()
local w = term.getSize()
local _, y0 = term.getCursorPos()
y0 = y0 - 2

local function bar(i, n, label)
  local bw = w - 12
  local f = math.floor(bw * i / n)
  term.setCursorPos(1, y0) term.clearLine()
  write(("[%s%s] %d/%d"):format(("#"):rep(f), ("-"):rep(bw - f), i, n))
  term.setCursorPos(1, y0 + 1) term.clearLine()
  write(label:sub(1, w))
end

local data, n = {}, #m.files
for i, p in ipairs(m.files) do
  bar(i - 1, n, "Downloading " .. p)
  local body, e = get(p)
  if not body then
    term.setCursorPos(1, y0 + 2)
    printError(("Failed to download %s: %s"):format(p, tostring(e)))
    printError("Nothing was changed.")
    return
  end
  data[p] = body
end
bar(n, n, "Writing files...")

-- Back up a foreign startup.lua (skip if it is already KL OS)
if fs.exists("startup.lua") then
  local f = fs.open("startup.lua", "r")
  local head = f.readAll()
  f.close()
  if not head:find("KL OS", 1, true) then
    if fs.exists("startup.lua.bak") then fs.delete("startup.lua.bak") end
    fs.copy("startup.lua", "startup.lua.bak")
  end
end

for p, body in pairs(data) do
  local f = assert(fs.open(p, "w"))
  f.write(body)
  f.close()
end

term.setCursorPos(1, y0 + 2)
print("Done! Rebooting...")
sleep(1.5)
os.reboot()
