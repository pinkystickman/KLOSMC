-- Registry for apps installed from KL Store or created with KL Maker.
local R = {}
local REGISTRY = "/Applications/installed.json"

local function validId(id)
  return type(id) == "string" and #id > 0 and #id <= 32 and id:match("^[%w_%-]+$") ~= nil
end

local function readAll()
  fs.makeDir("/Applications")
  if not fs.exists(REGISTRY) then return {} end
  local f = fs.open(REGISTRY, "r")
  if not f then return {} end
  local raw = f.readAll(); f.close()
  local ok, data = pcall(textutils.unserializeJSON, raw)
  if not ok or type(data) ~= "table" then return {} end
  local out = {}
  for _, item in ipairs(data) do
    if type(item) == "table" and validId(item.id) and type(item.name) == "string" then
      local expected = "/Applications/" .. item.id .. ".lua"
      if item.path == expected and fs.exists(expected) and not fs.isDir(expected) then
        out[#out + 1] = { id = item.id, name = item.name:sub(1, 32), path = expected, version = tostring(item.version or "1.0.0") }
      end
    end
  end
  return out
end

local function writeAll(items)
  fs.makeDir("/Applications")
  local f, err = fs.open(REGISTRY, "w")
  if not f then return false, err end
  f.write(textutils.serialiseJSON(items)); f.close()
  return true
end

function R.list()
  return readAll()
end

function R.get(id)
  for _, item in ipairs(readAll()) do if item.id == id then return item end end
  return nil
end

function R.register(name, path, version)
  if type(name) ~= "string" or name == "" then return false, "App name is required." end
  if type(path) ~= "string" then return false, "App path is invalid." end
  local id = fs.getName(path):gsub("%.lua$", "")
  if not validId(id) or path ~= "/Applications/" .. id .. ".lua" then
    return false, "Apps must be Lua files inside /Applications."
  end
  if not fs.exists(path) or fs.isDir(path) then return false, "The application file does not exist." end
  local items, found = readAll(), false
  for i, item in ipairs(items) do
    if item.id == id then
      items[i] = { id = id, name = name:sub(1, 32), path = path, version = tostring(version or "1.0.0") }
      found = true
    end
  end
  if not found then items[#items + 1] = { id = id, name = name:sub(1, 32), path = path, version = tostring(version or "1.0.0") } end
  table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)
  return writeAll(items)
end

function R.unregister(id)
  if not validId(id) then return false, "Invalid app ID." end
  local old, items = readAll(), {}
  for _, item in ipairs(old) do if item.id ~= id then items[#items + 1] = item end end
  return writeAll(items)
end

return R
