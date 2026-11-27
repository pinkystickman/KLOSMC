-- HackOS in-game browser. It resolves logical IPs or advertised hostnames.
local ui = require("os.ui")
local wrap = require("cc.strings").wrap
local net = require("os.network")
local WEB, LEGACY = net.WEB_PROTOCOL, net.LEGACY_WEB_PROTOCOL
local B = {}
local TIMEOUT = 3

local function errorPage(title, msg, hint)
  return { title = title, lines = {
    { text = "" }, { text = msg, color = colors.red }, { text = "" },
    { text = hint or "" }, { text = "" },
    { link = "Open network directory", to = "hack://directory" },
  } }
end

local home = { title = "HackOS Network", bg = colors.white, fg = colors.black, lines = {
  { text = "" },
  { text = "Welcome to the HackOS in-game network.", color = colors.blue },
  { text = "Enter a node IP address or advertised hostname." },
  { text = "Example: 10.0.0.25 or computer-2" },
  { text = "" },
  { link = "Scan network directory", to = "hack://directory" },
} }

local function request(id, protocol, req, timeout)
  local requestId = tostring(os.getComputerID()) .. "-" .. tostring(math.floor(os.clock() * 1000))
  req.requestId = requestId
  if not rednet.send(id, req, protocol) then return nil end
  local deadline = os.clock() + (timeout or TIMEOUT)
  while true do
    local left = deadline - os.clock()
    if left <= 0 then return nil end
    local from, msg = rednet.receive(protocol, left)
    if not from then return nil end
    if from == id and type(msg) == "table" then return msg end
  end
end

local function directory()
  local peers, err = net.discover(1.5)
  if not peers then return errorPage("Network unavailable", err or "No network.", "Connect a modem and try again.") end
  local lines = { { text = "" }, { text = "DISCOVERED NODES", color = colors.blue }, { text = "" } }
  for _, p in ipairs(peers) do
    lines[#lines + 1] = { link = p.ip .. "  /  " .. p.hostname, to = p.ip }
  end
  if #peers == 0 then lines[#lines + 1] = { text = "No HackOS nodes answered discovery." } end
  return { title = "Network Directory", bg = colors.white, fg = colors.black, lines = lines }
end

local function resolve(address)
  local peers, err
  if net.isIP(address) then
    peers, err = net.discover(1.2)
    if not peers then return nil, nil, err end
    local peer = net.findPeer(address, peers)
    if peer then return peer.id, WEB end
    return nil, nil, "No discovered node has IP address " .. address .. "."
  end
  local id = rednet.lookup(WEB, address, 1)
  if id then return id, WEB end
  id = rednet.lookup(LEGACY, address, 1)
  if id then return id, LEGACY end
  -- A fallback discovery scan also resolves hostnames advertised by HackOS nodes.
  peers, err = net.discover(1.2)
  if peers then
    local peer = net.findPeer(address, peers)
    if peer then return peer.id, WEB end
  end
  return nil, nil, "No server advertises '" .. address .. "'."
end

local function load(url)
  if url == "hack://directory" then return directory(), url end
  url = tostring(url or ""):gsub("^%a+://", "")
  local host, path = url:match("^([^/]+)(.*)$")
  if not host then return errorPage("400 Bad Request", "Enter an address like 10.0.0.25/ or node-3."), url end
  host = host:lower()
  if path == "" then path = "/" end
  local ok, err = net.open()
  if not ok then return errorPage("No modem", err), url end
  local id, protocol, why = resolve(host)
  if not id then return errorPage("Host not found", why or "No host found.", "Check the IP / hostname and make sure the server app is running."), url end
  local resp = request(id, protocol, { method = "GET", path = path })
  if not resp then return errorPage("504 Timeout", host .. " did not answer within " .. TIMEOUT .. " seconds.", "The host may have stopped or the modem link may be down."), url end
  if type(resp.page) ~= "table" then return errorPage("502 Bad Response", host .. " sent an invalid page."), url end
  local shownHost = resp.ip or resp.domain or host
  return resp.page, shownHost .. path
end

local function go(st, url, isBack)
  local w = ui.size()
  ui.text(1, 3, ui.pad(" Contacting " .. url .. " ...", w), colors.white, colors.blue)
  local page, shown = load(url)
  if not isBack and st.url ~= "" then st.hist[#st.hist + 1] = st.url end
  st.page, st.url, st.scroll = page, shown or url, 0
end

local function draw(st)
  local w, h = ui.size()
  local pg = st.page
  local bg = ui.col(pg.bg or colors.white, colors.black)
  local fg = ui.col(pg.fg or colors.black, colors.white)
  ui.clear(bg, fg)
  ui.header("HackOS Browser", "NETWORK")
  st.back = ui.button(1, 2, "<")
  ui.text(5, 2, ui.pad(st.url, math.max(1, w - 15)), colors.black, colors.white)
  st.dir = ui.button(w - 7, 2, "Dir")
  st.exit = ui.button(w - 2, 2, "X")
  ui.text(2, 3, ui.pad(" " .. (pg.title or "Untitled page"), w - 2), ui.col(colors.blue, fg), bg)
  local rows = {}
  for _, line in ipairs(pg.lines or {}) do
    if line.link then
      rows[#rows + 1] = { s = ("[ %s ]"):format(line.link):sub(1, w), to = line.to }
    else
      local parts = wrap(line.text or "", math.max(1, w - 2))
      if #parts == 0 then parts = { "" } end
      for _, s in ipairs(parts) do rows[#rows + 1] = { s = s, c = line.color } end
    end
  end
  local bh = math.max(1, h - 4)
  st.bh = bh
  st.scroll = math.max(0, math.min(st.scroll, math.max(0, #rows - bh)))
  st.links = {}
  for i = 1, bh do
    local r = rows[st.scroll + i]
    if r then
      local y = 3 + i
      local c = r.to and ui.col(colors.blue, fg) or ui.col(r.c or fg, fg)
      ui.text(2, y, r.s, c, bg)
      if r.to then st.links[#st.links + 1] = { y = y, x2 = math.min(w, #r.s + 1), to = r.to } end
    end
  end
end

local function resolveLink(st, to)
  if tostring(to):sub(1, 1) == "/" then return (st.url:match("^[^/]+") or "") .. to end
  return to
end

local function edit(st)
  local w = ui.size()
  ui.text(5, 2, ui.pad("", math.max(1, w - 15)), colors.black, colors.white)
  term.setCursorPos(5, 2)
  term.setTextColor(colors.black); term.setBackgroundColor(colors.white)
  local value = read(nil, nil, nil, st.url)
  term.setCursorBlink(false)
  if value and value ~= "" then go(st, value) end
end

function B.run()
  local ok, err = net.open()
  local st = { hist = {}, scroll = 0, url = "", page = home }
  if not ok then st.page = errorPage("No modem", err) end
  while true do
    draw(st)
    local w = ui.size()
    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then st.scroll = st.scroll + ev[2] * 2
    elseif ev[1] == "key" and ev[2] == keys.pageDown then st.scroll = st.scroll + st.bh - 1
    elseif ev[1] == "key" and ev[2] == keys.pageUp then st.scroll = st.scroll - st.bh + 1
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        if ui.hit(st.exit, x, y) then return
        elseif ui.hit(st.back, x, y) then
          local u = table.remove(st.hist)
          if u then go(st, u, true) end
        elseif ui.hit(st.dir, x, y) then go(st, "hack://directory")
        elseif y == 2 and x >= 5 and x <= w - 10 then edit(st)
        else
          for _, link in ipairs(st.links) do
            if y == link.y and x >= 2 and x <= link.x2 then go(st, resolveLink(st, link.to)); break end
          end
        end
      end
    end
  end
end

return B
