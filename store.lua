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
