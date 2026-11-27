-- KL Store: Calculator
local ui = require("os.ui")
local function numberPrompt(label)
  while true do
    local value = ui.input("Calculator", label, "0")
    if value == nil then return nil end
    local number = tonumber(value)
    if number then return number end
    ui.message("Calculator", "Please enter a valid number.")
  end
end

local a = numberPrompt("First number:")
if a == nil then return end
local b = numberPrompt("Second number:")
if b == nil then return end
local op = ui.input("Calculator", "Operation: +  -  *  /", "+")
if not op then return end
local result
if op == "+" then result = a + b
elseif op == "-" then result = a - b
elseif op == "*" or op == "x" then result = a * b
elseif op == "/" then
  if b == 0 then ui.message("Calculator", "Cannot divide by zero."); return end
  result = a / b
else ui.message("Calculator", "Unknown operation."); return end
ui.message("Calculator result", tostring(a) .. " " .. op .. " " .. tostring(b) .. " = " .. tostring(result))
