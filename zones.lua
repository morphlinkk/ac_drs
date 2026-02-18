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
