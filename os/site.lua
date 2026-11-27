-- Small HTML subset renderer shared by the website editor preview and rednet web server.
local Site = {}
local wrap = require("cc.strings").wrap

local function decode(s)
  return tostring(s or ""):gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
    :gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&#x27;", "'")
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function Site.render(source, path)
  source = tostring(source or "")
  local title = source:match("<title[^>]*>(.-)</title>") or (path or "Website")
  title = trim(decode(title:gsub("<[^>]+>", "")))
  local body = source:match("<body[^>]*>(.-)</body>") or source
  body = body:gsub("<script[^>]*>.-</script>", " "):gsub("<style[^>]*>.-</style>", " ")
  local lines, anchor, buffer = {}, nil, ""
  local function flush(color)
    local text = trim(decode(buffer:gsub("%s+", " ")))
    buffer = ""
    if text ~= "" then
      if anchor then anchor.text = anchor.text .. (anchor.text ~= "" and " " or "") .. text
      else
        for _, piece in ipairs(wrap(text, 46)) do lines[#lines + 1] = { text = piece, color = color } end
      end
    end
  end
  local function blank()
    flush()
    if #lines > 0 and lines[#lines].text ~= "" then lines[#lines + 1] = { text = "" } end
  end

  local function parseTag(token)
    local tag = token:lower()
    if tag:match("^<a[%s>]") then
      flush()
      local href = token:match("href%s*=%s*['\"](.-)['\"]") or "/"
      anchor = { to = href, text = "" }
    elseif tag:match("^</a") then
      flush()
      if anchor and anchor.text ~= "" then lines[#lines + 1] = { link = anchor.text, to = anchor.to } end
      anchor = nil
    elseif tag:match("^<h[1-6]") then
      blank()
    elseif tag:match("^</h[1-6]") then
      flush(colors.blue); blank()
    elseif tag:match("^<p[%s>]") or tag:match("^</p") or tag:match("^<div[%s>]") or tag:match("^</div") or
      tag:match("^<br") or tag:match("^<li[%s>]") or tag:match("^</li") or tag:match("^<hr") or
      tag:match("^<section[%s>]") or tag:match("^</section") then
      blank()
    end
  end

  local pos = 1
  while pos <= #body do
    local lt = body:find("<", pos, true)
    if not lt then
      buffer = buffer .. body:sub(pos)
      break
    end
    if lt > pos then buffer = buffer .. body:sub(pos, lt - 1) end
    local gt = body:find(">", lt + 1, true)
    if not gt then
      buffer = buffer .. body:sub(lt)
      break
    end
    parseTag(body:sub(lt, gt))
    pos = gt + 1
  end
  flush()
  if #lines == 0 then lines[1] = { text = "This page is empty. Edit /www/index.html to add content." } end
  return { title = title ~= "" and title or "Website", bg = colors.white, fg = colors.black, lines = lines }
end

function Site.safePagePath(path)
  path = tostring(path or "/"):gsub("%?.*$", ""):gsub("\\", "/")
  if path == "" or path == "/" then path = "/index.html" end
  if path:find("..", 1, true) then return nil end
  if path:sub(1, 1) ~= "/" then path = "/" .. path end
  if not path:match("%.[%w]+$") then path = path .. ".html" end
  if path:match("^/%.%.") then return nil end
  return path
end

function Site.readPage(path)
  local safe = Site.safePagePath(path)
  if not safe then return nil, "Invalid page path." end
  local file = fs.combine("/www", safe:sub(2))
  if not fs.exists(file) or fs.isDir(file) then return nil, "Page not found: " .. safe end
  local f, err = fs.open(file, "r")
  if not f then return nil, tostring(err) end
  local source = f.readAll(); f.close()
  if #source > 12000 then return nil, "Page is too large (maximum 12000 characters)." end
  return Site.render(source, safe)
end

function Site.ensureFiles()
  fs.makeDir("/www")
  if not fs.exists("/www/index.html") then
    local f = fs.open("/www/index.html", "w")
    if f then f.write([[<!doctype html>
<html>
<head><title>My CC Website</title></head>
<body>
<h1>Welcome to my website!</h1>
<p>This site is hosted by my own CC:Tweaked computer.</p>
<p><a href="/about.html">About this site</a></p>
</body>
</html>
]]); f.close() end
  end
  if not fs.exists("/www/about.html") then
    local f = fs.open("/www/about.html", "w")
    if f then f.write([[<!doctype html>
<html>
<head><title>About this site</title></head>
<body>
<h1>About</h1>
<p>I built this website with KL OS / HackOS Website Studio.</p>
<p><a href="/index.html">Back home</a></p>
</body>
</html>
]]); f.close() end
  end
end

return Site
