local store = require("store")

local M = {}

---@param carIndex integer
---@param zoneIdx integer
---@param time number
local function enforceDRS(carIndex, zoneIdx, time)
  if store.detectionTimes[zoneIdx] == nil then
    M.DisableDRSForCar(carIndex)
    store.detectionTimes[zoneIdx] = time
    return
  end
  local canUseDRS = (time - store.detectionTimes[zoneIdx]) <= 1000

  store.detectionTimes[zoneIdx] = time
  if canUseDRS then
    M.EnableDRSForCar(carIndex)
  else
    M.DisableDRSForCar(carIndex)
  end
end

---@param carIndex integer
---@param pos number
---@param time number
local function checkDetection(carIndex, pos, time)
  local distanceTolerance = 0.001
  for idx, zone in ipairs(store.zones) do
    if math.abs(pos - zone.detection) < distanceTolerance then
      store.lastTriggerTimes[carIndex] = store.lastTriggerTimes[carIndex] or {}

      local lastTime = store.lastTriggerTimes[carIndex][idx]

      local retriggerCooldown = 500
      if not lastTime or (time - lastTime) > retriggerCooldown then
        store.lastTriggerTimes[carIndex][idx] = time
        enforceDRS(carIndex, idx, time)
      end
    end
  end
end

function M.update()
  local sim = ac.getSim()

  for i = 0, sim.carsCount - 1 do
    local car = ac.getCar(i)
    if car and car.isActive and car.isConnected then
      local lap = car.lapCount or 0

      if lap == 0 then
        M.DisableDRSForCar(i)
      end

      checkDetection(i, car.splinePosition, sim.time)
    end
  end
end

---@param carIndex integer
function M.DisableDRSForCar(carIndex)
  physics.allowCarDRS(carIndex, true)
end

---@param carIndex integer
function M.EnableDRSForCar(carIndex)
  physics.allowCarDRS(carIndex, false)
end

return M
