package.preload["utils"] = function()
  local M = {}

  function M.fileExists(path)
    local f = io.open(path, "r")
    if f then
      io.close(f)
      return true
    end
    return false
  end

  return M
end

package.preload["store"] = function()
  ---@class DetectionTimes
  ---@field lap integer
  ---@field zones table<integer, number>

  ---@class DRSZone
  ---@field detection number
  ---@field start number
  ---@field ["end"] number

  ---@class Store
  ---@field zones DRSZone[]
  ---@field zonesLoaded boolean
  ---@field detectionTimes table<integer, number>
  ---@field lastTriggerTimes table<integer, number>

  ---@type Store
  local store = {
    zones = {},
    zonesLoaded = false,
    detectionTimes = {},
    lastTriggerTimes = {},
  }

  return store
end

package.preload["zones"] = function()
  local utils = require("utils")

  local APP_NAME = "DRS"
  local M = {}

  function M.load()
    local zones = {}

    local ok, err = pcall(function()
      local track_id = ac.getTrackID()
      local track_layout = ac.getTrackLayout()

      local drsIni
      if track_layout then
        drsIni = string.format(
          "content/tracks/%s/%s/data/drs_zones.ini",
          track_id, track_layout)
      else
        drsIni = string.format(
          "content/tracks/%s/data/drs_zones.ini",
          track_id)
      end

      if not utils.fileExists(drsIni) then
        ac.debug(APP_NAME .. ": drs_zones.ini missing")
        return
      end

      local file = io.open(drsIni, "r")
      if not file then
        ac.debug(APP_NAME .. ": could not open drs_zones.ini")
        return
      end

      local currentZone
      for line in file:lines() do
        line = line:gsub("^%s*(.-)%s*$", "%1")

        if line:match("^%[.-%]$") then
          if currentZone and next(currentZone) then
            table.insert(zones, currentZone)
          end
          currentZone = {}
        elseif currentZone and line:match("=") then
          local key, value = line:match("^(.-)%s*=%s*(.-)$")
          key = key:upper()
          value = tonumber(value)

          if key == "DETECTION" then
            currentZone.detection = value
          elseif key == "START" then
            currentZone.start = value
          elseif key == "END" then
            currentZone["end"] = value
          end
        end
      end

      if currentZone and next(currentZone) then
        table.insert(zones, currentZone)
      end

      file:close()
    end)

    if not ok then
      ac.debug(APP_NAME .. ": loadDRSZones error " .. tostring(err))
      return nil
    end

    return zones
  end

  return M
end

package.preload["drs"] = function()
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
end

local store = require("store")
local zones = require("zones")
local drs = require("drs")

ac.console("DRS rules are applied")

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
