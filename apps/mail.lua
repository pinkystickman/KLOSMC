-- HackOS Mail: local in-game email over CC:Tweaked rednet.
local ui = require("os.ui")
local net = require("os.network")
local mail = require("os.mail")
local A = {}

local function listMessages(title, messages)
  if #messages == 0 then ui.message(title, "No messages here yet."); return end
  local lines = {}
  for i, msg in ipairs(messages) do
    lines[#lines + 1] = string.format("%d. %s | %s", i, tostring(msg.from or "?"), tostring(msg.subject or "(no subject)"))
  end
  ui.message(title, table.concat(lines, "\n"))
  local index = tonumber(ui.input(title, "Enter message number to open (blank to return):", ""))
  if not index or index < 1 or index > #messages or index ~= math.floor(index) then return end
  local msg = messages[index]
  ui.message(tostring(msg.subject or "(no subject)"),
    "From: " .. tostring(msg.from) .. "\nTo: " .. tostring(msg.to) .. "\nTime: " .. tostring(msg.receivedAt or msg.sentAt or "") .. "\n\n" .. tostring(msg.body or ""))
end

local function compose()
  ui.message("Compose Email", "HackOS internal mail works between computers running HackOS/KL OS 2.4.0 on the same rednet network. Address format: user@hostname.")
  local to = ui.input("New Email", "To (example: admin@computer-2):", "")
  if not to or to == "" then return end
  local subject = ui.input("New Email", "Subject (maximum 100 characters):", "")
  if not subject then return end
  local lines = {}
  ui.message("Message Body", "Enter each line in the next prompt. Leave a line blank to finish. Maximum 3000 characters.")
  local total = 0
  for i = 1, 30 do
    local line = ui.input("Message Body", "Line " .. i .. " (blank = send):", "")
    if not line or line == "" then break end
    total = total + #line + 1
    if total > 3000 then ui.message("Message Body", "The body reached the 3000-character limit."); break end
    lines[#lines + 1] = line
  end
  local body = table.concat(lines, "\n")
  if body == "" then ui.message("Email", "Empty message cancelled."); return end
  local ok, result = mail.send(to, subject, body)
  ui.message(ok and "Email Sent" or "Email Not Sent", tostring(result))
end

local function settings()
  local current = mail.getAddress()
  local user = ui.input("Mailbox Settings", "Current address: " .. current .. "\nNew mailbox username:", "admin")
  if user and user ~= "" then
    local ok, err = mail.setUser(user)
    ui.message("Mailbox Settings", ok and ("Your new email address is " .. mail.getAddress()) or tostring(err))
  end
end

function A.run()
  local opened, err = net.open()
  if not opened then ui.message("HackOS Mail", err); return end
  while true do
    local w, h = ui.size(); local T = ui.theme()
    ui.clear(T.bg, T.fg); ui.header("HackOS Mail", "IN-GAME MESSAGING")
    ui.text(2, 3, "Mailbox: " .. mail.getAddress(), T.accent, T.bg)
    ui.text(2, 5, "Messages are delivered over your rednet network.", T.fg, T.bg)
    local inboxBtn = ui.button(2, 7, "Inbox")
    local composeBtn = ui.button(13, 7, "Compose")
    local sentBtn = ui.button(25, 7, "Sent")
    local settingsBtn = ui.button(2, 9, "Mailbox Settings")
    local scanBtn = ui.button(22, 9, "Network Scan")
    local backBtn = ui.button(w - 8, h - 2, "Back")
    ui.text(2, h - 1, "Internal HackOS mail only - not external SMTP email", T.fg, T.bg)
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.one then listMessages("Inbox", mail.getInbox())
      elseif ev[2] == keys.two then compose()
      elseif ev[2] == keys.three then listMessages("Sent", mail.getSent()) end
    end
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(inboxBtn, x, y) then listMessages("Inbox", mail.getInbox())
      elseif ui.hit(composeBtn, x, y) then compose()
      elseif ui.hit(sentBtn, x, y) then listMessages("Sent", mail.getSent())
      elseif ui.hit(settingsBtn, x, y) then settings()
      elseif ui.hit(scanBtn, x, y) then
        local peers = net.discover(1.8) or {}
        local lines = {}
        for _, peer in ipairs(peers) do
          local hasMail = false
          for _, service in ipairs(peer.services or {}) do if service == "MAIL" then hasMail = true end end
          if hasMail then lines[#lines + 1] = peer.hostname .. "  <" .. peer.ip .. ">  " .. tostring(peer.mailAddress or ("admin@" .. peer.hostname)) end
        end
        ui.message("Mail Directory", #lines > 0 and table.concat(lines, "\n") or "No mail-enabled computers found.")
      elseif ui.hit(backBtn, x, y) then return end
    end
  end
end

return A
