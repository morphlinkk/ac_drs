local M = {}

---@param path string
function M.fileExists(path)
  local f = io.open(path, "r")
  if f then
    io.close(f)
    return true
  end
  return false
end

return M
