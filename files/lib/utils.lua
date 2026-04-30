--- Interpolates a value between two points.
---@param x1 number The x-coordinate of the first point.
---@param y1 number The y-coordinate of the first point.
---@param x2 number The x-coordinate of the second point.
---@param y2 number The y-coordinate of the second point.
---@param x number The x-coordinate of the point to interpolate.
---@return number The interpolated y-coordinate.
local function interpolate(x1, y1, x2, y2, x)
	return y1 + (y2 - y1) * ((x - x1) / (x2 - x1))
end

return {
	interpolate = interpolate
}
