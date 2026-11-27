-- Configure the optional remote-access companion on KL OS Standard.
package.path = "/?.lua;/?/init.lua;" .. package.path
local remote = require("os.remote")

local function clear()
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
  term.clear(); term.setCursorPos(1, 1)
end

while true do
  local enabled, pin = remote.getStatus()
  clear()
  print("KL OS - REMOTE ACCESS SETTINGS")
  print(string.rep("-", 32))
  print("Incoming access: " .. (enabled and "ENABLED" or "DISABLED"))
  if enabled then print("Access code: " .. pin) end
  print()
  print("1. Enable remote access / show code")
  print("2. Generate a new access code")
  print("3. Disable remote access")
  print("4. Exit")
  write("Choose: ")
  local choice = read()
  if choice == "1" then
    local ok, value = remote.enable()
    if ok then print("\nRemote access enabled. Code: " .. value) else printError(tostring(value)) end
    print("Run 'reboot' to restart KL OS and activate the agent.")
    print("Press any key..."); os.pullEvent("key")
  elseif choice == "2" then
    local ok, value = remote.rotatePin()
    if ok then print("\nNew access code: " .. value) else printError(tostring(value)) end
    print("Press any key..."); os.pullEvent("key")
  elseif choice == "3" then
    local ok, err = remote.disable()
    print(ok and "\nRemote access disabled." or ("\nError: " .. tostring(err)))
    print("Press any key..."); os.pullEvent("key")
  elseif choice == "4" then
    clear(); print("Remote access settings closed."); break
  end
end
