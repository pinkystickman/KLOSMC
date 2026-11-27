-- Local security controls for the intentionally exposed, read-only legacy diagnostics service.
local ui = require("os.ui")
local legacy = require("os.legacy")
local A = {}

function A.run()
  local status = "Ready"
  while true do
    local w, h = ui.size()
    local T = ui.theme()
    local exposed = legacy.getStatus()
    ui.clear(T.bg, T.fg)
    ui.header("Security Center", "LOCAL SETTINGS")
    ui.text(2, 3, "Legacy diagnostic service", T.accent, T.bg)
    ui.text(2, 5, "Status: " .. (exposed and "EXPOSED (unpatched lab mode)" or "PATCHED"), exposed and T.bad or T.good, T.bg)
    ui.text(2, 7, "Exposed mode allows unauthenticated, read-only guest diagnostics.", T.fg, T.bg)
    ui.text(2, 8, "Only system info and files placed in /public are accessible.", T.fg, T.bg)
    ui.text(2, 9, "It does NOT provide a remote shell or full computer control.", T.fg, T.bg)
    ui.text(2, h - 4, "Status: " .. status, T.fg, T.bg)
    local patch = ui.button(2, h - 2, exposed and "Apply patch" or "Re-open lab exposure")
    local back = ui.button(w - 8, h - 2, "Back")
    local ev = { os.pullEvent() }
    local kind, x, y = ui.pointer(ev)
    if kind == "click" then
      if ui.hit(patch, x, y) then
        local ok, err
        if exposed then ok, err = legacy.patch() else ok, err = legacy.unpatch() end
        status = ok and (exposed and "Patch applied. Guest exploit is blocked." or "Lab exposure restored.") or tostring(err)
      elseif ui.hit(back, x, y) then return end
    elseif ev[1] == "key" and ev[2] == keys.enter then
      local ok, err
      if exposed then ok, err = legacy.patch() else ok, err = legacy.unpatch() end
      status = ok and (exposed and "Patch applied. Guest exploit is blocked." or "Lab exposure restored.") or tostring(err)
    end
  end
end

return A
