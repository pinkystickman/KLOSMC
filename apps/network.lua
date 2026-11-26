-- HackOS network configuration and node discovery.
local ui = require("os.ui")
local net = require("os.network")
local A = {}

function A.run()
  net.open()
  local peers, status, scroll = {}, "Ready", 0
  while true do
    local w, h = ui.size()
    local T = ui.theme()
    ui.clear(T.bg, T.fg)
    ui.header("Network Center", "IP / REDNET")
    ui.text(2, 3, "This computer", T.accent, T.bg)
    ui.text(2, 4, "Hostname : " .. net.getHostname(), T.fg, T.bg)
    ui.text(2, 5, "IPv4     : " .. net.getIP(), T.fg, T.bg)
    ui.text(2, 6, "Computer : #" .. os.getComputerID(), T.fg, T.bg)
    ui.text(2, 7, "Transport: CC:Tweaked rednet over attached modems", T.fg, T.bg)
    ui.text(2, 9, "Nearby HackOS nodes", T.accent, T.bg)
    local visible = h - 13
    scroll = math.max(0, math.min(scroll, math.max(0, #peers - visible)))
    for i = 1, visible do
      local p = peers[scroll + i]
      if p then
        local line = string.format("%-15s  %-18s  #%d", p.ip, p.hostname, p.id)
        ui.text(2, 9 + i, line:sub(1, w - 2), T.fg, T.bg)
      end
    end
    ui.text(2, h - 3, "Status: " .. status, status:find("No ", 1, true) and T.bad or T.good, T.bg)
    local scan = ui.button(2, h - 1, "Scan network")
    local ipBtn = ui.button(18, h - 1, "Set IP")
    local hostBtn = ui.button(27, h - 1, "Set hostname")
    local back = ui.button(w - 8, h - 1, "Back")
    ui.drawCursor()
    local ev = { os.pullEvent() }
    if ev[1] == "mouse_scroll" then scroll = scroll + ev[2] * 2 end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(scan, x, y) then
        status = "Scanning..."
        ui.clear(T.bg, T.fg); ui.header("Network Center"); ui.text(2, 3, "Broadcasting discovery packet...", T.fg, T.bg)
        local result, err = net.discover(1.5)
        peers = result or {}
        status = err or ("Found " .. #peers .. " node(s)")
        scroll = 0
      elseif ui.hit(ipBtn, x, y) then
        local value = ui.input("Set IPv4 address", "New private IP (example: 10.0.0.25)", net.getIP())
        if value and value ~= "" then
          local ok, err = net.setConfig(value, net.getHostname())
          status = ok and "IP address saved" or tostring(err)
        end
      elseif ui.hit(hostBtn, x, y) then
        local value = ui.input("Set hostname", "Hostname (letters, numbers, dots, hyphens)", net.getHostname())
        if value and value ~= "" then
          local ok, err = net.setConfig(net.getIP(), value)
          status = ok and "Hostname saved" or tostring(err)
        end
      elseif ui.hit(back, x, y) then return end
    end
  end
end

return A
