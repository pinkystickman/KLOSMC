local S = {}

function S.run()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear() term.setCursorPos(1, 1)
  print("KL OS shell - type 'exit' to return.")
  shell.run("shell")
end

return S
