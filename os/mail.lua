-- HackOS internal mail service. This is an in-game mailbox over rednet, not SMTP/Internet email.
local M = {}
M.PROTOCOL = "hackos_mail_v1"
local CFG = "/hackos/mail.cfg"
local BOX = "/hackos/mailbox.json"
local net = require("os.network")
local requestID = 0

local function readConfig()
  fs.makeDir("/hackos")
  local cfg = { user = "admin" }
  if fs.exists(CFG) then
    local f = fs.open(CFG, "r")
    if f then
      local raw = f.readAll(); f.close()
      local saved = textutils.unserializeJSON(raw)
      if type(saved) == "table" and type(saved.user) == "string" and saved.user:match("^[%w%-_]+$") then cfg.user = saved.user end
    end
  end
  return cfg
end

local function readBox()
  fs.makeDir("/hackos")
  local box = { inbox = {}, sent = {} }
  if fs.exists(BOX) then
    local f = fs.open(BOX, "r")
    if f then
      local raw = f.readAll(); f.close()
      local saved = textutils.unserializeJSON(raw)
      if type(saved) == "table" then
        if type(saved.inbox) == "table" then box.inbox = saved.inbox end
        if type(saved.sent) == "table" then box.sent = saved.sent end
      end
    end
  end
  return box
end

local function writeBox(box)
  fs.makeDir("/hackos")
  local f, err = fs.open(BOX, "w")
  if not f then return false, err end
  f.write(textutils.serialiseJSON(box)); f.close()
  return true
end

function M.getAddress()
  return readConfig().user .. "@" .. net.getHostname()
end

function M.setUser(user)
  user = tostring(user or ""):lower()
  if #user < 1 or #user > 24 or not user:match("^[%w%-_]+$") then return false, "Mailbox name must contain 1-24 letters, numbers, hyphens or underscores." end
  local f, err = fs.open(CFG, "w")
  if not f then return false, err end
  f.write(textutils.serialiseJSON({ user = user })); f.close()
  return true
end

function M.getInbox() return readBox().inbox end
function M.getSent() return readBox().sent end

local function addMessage(folder, message)
  local box = readBox()
  box[folder][#box[folder] + 1] = message
  while #box[folder] > 100 do table.remove(box[folder], 1) end
  return writeBox(box)
end

local function validMessage(msg)
  if type(msg) ~= "table" then return false, "Invalid message." end
  if type(msg.from) ~= "string" or #msg.from > 80 then return false, "Invalid sender address." end
  if type(msg.to) ~= "string" or #msg.to > 80 or msg.to:lower() ~= M.getAddress():lower() then return false, "This message is addressed to a different mailbox." end
  if type(msg.subject) ~= "string" or #msg.subject > 100 then return false, "Subject is too long." end
  if type(msg.body) ~= "string" or #msg.body > 3000 then return false, "Message body exceeds 3000 characters." end
  return true
end

local function handle(id, msg)
  if type(msg) ~= "table" or msg.kind ~= "SEND" then return end
  local ok, why = validMessage(msg.message)
  if not ok then
    rednet.send(id, { kind = "ACK", ok = false, error = why, request = msg.request }, M.PROTOCOL)
    return
  end
  local item = msg.message
  item.receivedAt = textutils.formatTime(os.time(), true)
  item.fromComputer = id
  local saved, err = addMessage("inbox", item)
  rednet.send(id, { kind = "ACK", ok = saved, error = err, request = msg.request }, M.PROTOCOL)
end

local function splitAddress(address)
  if type(address) ~= "string" then return nil end
  local user, host = address:lower():match("^([%w%-_]+)@([%w%-%.]+)$")
  if not user or not host then return nil end
  return user, host
end

function M.send(to, subject, body)
  to = tostring(to or ""):lower()
  subject = tostring(subject or "")
  body = tostring(body or "")
  local recipient, host = splitAddress(to)
  if not recipient then return false, "Use an address like admin@computer-2." end
  if #subject > 100 then return false, "Subject must be 100 characters or fewer." end
  if #body > 3000 then return false, "Message must be 3000 characters or fewer." end
  local message = {
    from = M.getAddress(), to = to, subject = subject, body = body,
    sentAt = textutils.formatTime(os.time(), true), senderComputer = os.getComputerID(),
  }
  if host == net.getHostname():lower() then
    if to ~= M.getAddress():lower() then return false, "That mailbox does not exist on this computer." end
    local saved, err = addMessage("inbox", message)
    if saved then addMessage("sent", message) end
    return saved, err
  end
  local peers, err = net.discover(1.8)
  if not peers then return false, err or "Network discovery failed." end
  local target
  for _, peer in ipairs(peers) do if peer.hostname:lower() == host then target = peer; break end end
  if not target then return false, "Computer '" .. host .. "' was not found. Scan the network and check its hostname." end
  requestID = (requestID or 0) + 1
  local req = requestID
  rednet.send(target.id, { kind = "SEND", message = message, request = req }, M.PROTOCOL)
  local deadline = os.clock() + 5
  while os.clock() < deadline do
    local sender, response = rednet.receive(M.PROTOCOL, math.max(0.05, deadline - os.clock()))
    if not sender then break end
    if sender == target.id and type(response) == "table" and response.kind == "ACK" and response.request == req then
      if not response.ok then return false, response.error or "Message rejected." end
      local saved, saveErr = addMessage("sent", message)
      if not saved then return false, "Delivered, but could not save Sent folder: " .. tostring(saveErr) end
      return true, "Delivered to " .. to
    end
  end
  return false, "No delivery confirmation. The recipient may be offline or have an older OS."
end

function M.run()
  while true do
    local opened = net.open()
    if opened then
      while true do
        local event, a, b, c = os.pullEvent()
        if event == "rednet_message" then
          local id, msg, protocol = a, b, c
          if protocol == M.PROTOCOL and id ~= os.getComputerID() then handle(id, msg)
          elseif protocol == net.PROTOCOL and type(msg) == "table" and msg.kind == "DISCOVER" then
            rednet.send(id, { kind = "OFFER", version = 1, ip = net.getIP(), hostname = net.getHostname(), mailAddress = M.getAddress(), services = { "MAIL" } }, net.PROTOCOL)
          end
        end
      end
    else os.sleep(4) end
  end
end

return M
