-- HackOS terminal: a direct CraftOS shell session.
local S = {}
function S.run()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.lime)
  term.clear(); term.setCursorPos(1, 1)
  print("HACKOS TERMINAL")
  term.setTextColor(colors.lightGray)
  print("Type 'exit' to return to the desktop.")
  print("HackOS files are stored under /hackos.")
  print()
  term.setTextColor(colors.white)
  shell.run("shell")
end
return S
