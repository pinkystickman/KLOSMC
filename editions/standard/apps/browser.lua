-- KL OS web browser
local ui = require("os.ui")
local wrap = require("cc.strings").wrap
local PROTO, TIMEOUT = "ccweb", 3
local B = {}

local function errorPage(title, msg, hint)
  return { title = title, lines = {
    { text = "" },
    { text = msg, color = colors.red },
    { text = "" },
    { text = hint or "" },
    { text = "" },
    { link = "Open directory", to = "kl://directory" },
  } }
end

local home = { title = "KL Browser", lines = {
  { text = "" },
  { text = "Welcome to the KL OS web.", color = colors.yellow },
  { text = "Click the address bar and type a domain like home.cc, or press Dir to list sites." },
  { text = "" },
  { link = "Try home.cc", to = "home.cc" },
} }

-- Send a request and wait for the reply from that computer only
local function request(id, req, timeout)
  rednet.send(id, req, PROTO)
  local deadline = os.epoch("utc") + (timeout or TIMEOUT) * 1000
  while true do
    local left = (deadline - os.epoch("utc")) / 1000
    if left <= 0 then return nil end
    local from, msg = rednet.receive(PROTO, left)
    if not from then return nil end
    if from == id and type(msg) == "table" then return msg end
  end
end

local function noModem()
  return errorPage("No Modem", "No modem is open on this computer.",
    "Attach a wireless or ender modem and reopen the browser.")
end

-- rednet.lookup(proto) only returns IDs, so ask each server for its domain
local function directory()
  if not rednet.isOpen() then return noModem() end
  local lines = { { text = "" }, { text = "Active websites:", color = colors.yellow }, { text = "" } }
  local ids, found = { rednet.lookup(PROTO) }, 0
  for _, id in ipairs(ids) do
    local r = request(id, { method = "INFO" }, 1)
    if r and r.domain then
      found = found + 1
      lines[#lines + 1] = { link = r.domain, to = r.domain }
    end
  end
  if found == 0 then lines[#lines + 1] = { text = "No websites found in range." } end
  return { title = "Directory", lines = lines }
end

local function load(url)
  if url == "kl://directory" then return directory(), url end
  url = (url:gsub("^%a+://", ""))
  local domain, path = url:match("^([^/]+)(.*)$")
  if not domain then
    return errorPage("400 Bad Request", "Enter an address like home.cc"), url
  end
  domain = domain:lower()
  if path == "" then path = "/" end
  if not rednet.isOpen() then return noModem(), url end
  local id = rednet.lookup(PROTO, domain)
  if not id then
    return errorPage("404 Not Found", "No server hosts '" .. domain .. "'.",
      "Check the spelling or open the directory."), url
  end
  local resp = request(id, { method = "GET", path = path })
  if not resp then
    return errorPage("504 Timeout", domain .. " did not answer within " .. TIMEOUT .. "s.",
      "The server may be offline or out of range."), url
  end
  if type(resp.page) ~= "table" then
    return errorPage("502 Bad Response", domain .. " sent an invalid page."), url
  end
  return resp.page, domain .. path
end

local function go(st, url, isBack)
  local w = ui.size()
  ui.text(1, 3, ui.pad(" Loading " .. url .. "...", w), colors.white, colors.black)
  local page, shown = load(url)
  if not isBack and st.url ~= "" then st.hist[#st.hist + 1] = st.url end
  st.page, st.url, st.scroll = page, shown, 0
end

local function draw(st)
  local w, h = ui.size()
  local pg = st.page
  local bg = ui.col(pg.bg or colors.black, colors.black)
  local fg = ui.col(pg.fg or colors.white, colors.white)
  ui.clear(bg)
  ui.header("KL Browser")
  st.back = ui.button(1, 2, "<")
  ui.text(5, 2, ui.pad(st.url, w - 14), colors.black, colors.white)
  st.dir = ui.button(w - 8, 2, "Dir")
  st.exit = ui.button(w - 2, 2, "X")
  ui.text(1, 3, ui.pad(" " .. (pg.title or ""), w), ui.col(colors.yellow, fg), bg)

  local rows = {}
  for _, ln in ipairs(pg.lines or {}) do
    if ln.link then
      rows[#rows + 1] = { s = ("[%s]"):format(ln.link):sub(1, w), to = ln.to }
    else
      local parts = wrap(ln.text or "", w)
      if #parts == 0 then parts = { "" } end
      for _, s in ipairs(parts) do rows[#rows + 1] = { s = s, c = ln.color } end
    end
  end

  local bh = h - 3
  st.bh = bh
  st.scroll = math.max(0, math.min(st.scroll, #rows - bh))
  st.links = {}
  for i = 1, bh do
    local r = rows[st.scroll + i]
    if r then
      local y = 3 + i
      local c = r.to and ui.col(colors.lightBlue, fg) or ui.col(r.c or fg, fg)
      ui.text(1, y, r.s, c, bg)
      if r.to then st.links[#st.links + 1] = { y = y, x2 = #r.s, to = r.to } end
    end
  end
end

local function resolve(st, to)
  if to:sub(1, 1) == "/" then return (st.url:match("^[^/]+") or "") .. to end
  return to
end

local function edit(st)
  local w = ui.size()
  ui.text(5, 2, ui.pad("", w - 14), colors.black, colors.white)
  term.setCursorPos(5, 2)
  local s = read(nil, nil, nil, st.url)
  term.setCursorBlink(false)
  if s and s ~= "" then go(st, s) end
end

function B.run()
  peripheral.find("modem", rednet.open)
  local st = { hist = {}, scroll = 0, url = "", page = home }
  while true do
    draw(st)
    local w = ui.size()
    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then
      st.scroll = st.scroll + ev[2] * 2
    elseif ev[1] == "key" and ev[2] == keys.pageDown then
      st.scroll = st.scroll + st.bh - 1
    elseif ev[1] == "key" and ev[2] == keys.pageUp then
      st.scroll = st.scroll - st.bh + 1
    else
      local kind, x, y = ui.pointer(ev)
      if kind == "click" then
        if ui.hit(st.exit, x, y) then return
        elseif ui.hit(st.back, x, y) then
          local u = table.remove(st.hist)
          if u then go(st, u, true) end
        elseif ui.hit(st.dir, x, y) then go(st, "kl://directory")
        elseif y == 2 and x >= 5 and x <= w - 10 then edit(st)
        else
          for _, l in ipairs(st.links) do
            if y == l.y and x <= l.x2 then go(st, resolve(st, l.to)) break end
          end
        end
      end
    end
  end
end

return B
