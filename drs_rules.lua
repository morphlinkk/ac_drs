local store = require("store")
local zones = require("zones")
local drs = require("drs")

ac.console("DRS rules started")

function script.update(dt)
  local sim = ac.getSim()

  if not store.zonesLoaded then
    local z = zones.load()
    if z then
      store.zones = z
      store.zonesLoaded = true
    else
      return
    end
  end

  local session = ac.getSession(sim.currentSessionIndex)
  if session and session.type == ac.SessionType.Race then
    drs.update()
  end
end
