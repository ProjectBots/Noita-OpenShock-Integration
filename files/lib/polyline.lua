local utils = dofile_once("mods/openshock_integration/files/lib/utils.lua")

local polyline_mt = {}
polyline_mt.__index = polyline_mt

--- creates a new PolyLine object from a list of points. Each point should be a table with x and y fields.
---@param points table A list of points, where each point is a table with x and y fields.
---@return table
local function PolyLine(points)
	-- sort the points by x value for easier interpolation later
	table.sort(points, function(a, b) return a.x < b.x end)
	print("Created PolyLine with points:")
	for _, point in ipairs(points) do
		print("  (" .. point.x .. ", " .. point.y .. ")")
	end
	return setmetatable({ points = points }, polyline_mt)
end

--- Gets the y value of the polyline at a given x value. If x is outside the range of the points, it returns the y value of the closest point.
---@param x number The x value to get the y value for.
---@return number The y value of the polyline at the given x value.
function polyline_mt:get_y(x)
	if #self.points == 0 then
		return 0
	end

	if x <= self.points[1].x then
		return self.points[1].y
	end

	if x >= self.points[#self.points].x then
		return self.points[#self.points].y
	end

	for i = 1, #self.points - 1 do
		local p1 = self.points[i]
		local p2 = self.points[i + 1]
		if x >= p1.x and x <= p2.x then
			return utils.interpolate(p1.x, p1.y, p2.x, p2.y, x)
		end
	end

	error("polyline_mt:get_y reached an unexpected state; points may be invalid or unsorted")
end

return {
	PolyLine = PolyLine
}
