-- KL OS web server: run on a dedicated computer with a modem
local PROTO, DOMAIN = "ccweb", "home.cc"
local C = colors

-- Page format: { title, bg, fg, lines = { {text=, color=} | {link=, to=} } }
-- `to` is "domain/route" or "/route" (same domain)
local pages = {
  ["/"] = { title = "Welcome to home.cc", bg = C.black, fg = C.white, lines = {
    { text = "" },
    { text = "Hello from the KL OS web!", color = C.yellow },
    { text = "This page is served over rednet by another computer." },
    { text = "" },
    { link = "Latest news", to = "/news" },
    { link = "About this site", to = "/about" },
  } },
  ["/news"] = { title = "home.cc - News", bg = C.black, fg = C.white, lines = {
    { text = "" },
    { text = "KL OS 1.0 released", color = C.lime },
    { text = "The in-game internet is now online. Browse sites with the KL Browser." },
    { text = "" },
    { text = "Server uptime: all systems nominal.", color = C.lightGray },
    { text = "" },
    { link = "Back home", to = "/" },
  } },
  ["/about"] = { title = "home.cc - About", bg = C.black, fg = C.white, lines = {
    { text = "" },
    { text = "About", color = C.yellow },
    { text = "Built with CC: Tweaked rednet and a wireless or ender modem." },
    { text = "" },
    { link = "Back home", to = "/" },
    { link = "Dead link (404 demo)", to = "example.cc" },
  } },
}

local function notFound(path)
  return { title = "404 Not Found", bg = C.black, fg = C.white, lines = {
    { text = "" },
    { text = "404 - Page not found", color = C.red },
    { text = "'" .. path .. "' does not exist on " .. DOMAIN .. "." },
    { text = "" },
    { link = "Back home", to = "/" },
  } }
end

peripheral.find("modem", rednet.open) -- opens every attached modem
if not rednet.isOpen() then error("No modem attached. Attach a wireless/ender modem.", 0) end

rednet.host(PROTO, DOMAIN)
print(("KL web server: %s (computer #%d)"):format(DOMAIN, os.getComputerID()))

local ok, err = pcall(function()
  while true do
    local id, req = rednet.receive(PROTO)
    if type(req) == "table" then
      if req.method == "GET" then
        local path = tostring(req.path or "/"):gsub("%?.*$", "")
        if #path > 1 then path = (path:gsub("/+$", "")) end
        if path == "" then path = "/" end
        local page = pages[path]
        rednet.send(id, { status = page and 200 or 404, page = page or notFound(path) }, PROTO)
        print(("#%d GET %s -> %d"):format(id, path, page and 200 or 404))
      elseif req.method == "INFO" then
        rednet.send(id, { domain = DOMAIN }, PROTO)
      end
    end
  end
end)

rednet.unhost(PROTO, DOMAIN)
if not ok and err ~= "Terminated" then printError(err) end
