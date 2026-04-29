local function interpolate(x1, y1, x2, y2, x)
	return y1 + (y2 - y1) * ((x - x1) / (x2 - x1))
end

return {
	interpolate = interpolate
}
