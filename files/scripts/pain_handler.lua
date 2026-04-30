if (_G.pain_handler) then
	return _G.pain_handler
end

--local utils = dofile_once("mods/openshock_integration/files/lib/utils.lua")
local polylinelib = dofile_once("mods/openshock_integration/files/lib/polyline.lua")

local shock_cooldown_frames = 30 -- just to avoid spamming the API

--- enables or disables the pain handler
--- @param enabled boolean
local function set_enabled(enabled)
	pain_handler.enabled = enabled
end

--- resizes the pain window to the new size, preserving existing values as much as possible
---@param size number The new size of the pain window
local function set_pain_window_size(size)
	local window = pain_handler.pain_window or {}
	local delta = size - #window
	if delta == 0 then
		return
	end
	-- move existing values to the end of the new window
	if delta > 0 then
		for i = #window, 1, -1 do
			window[i + delta] = window[i] or 0.0
		end
		-- fill the new slots with zeros
		for i = 1, delta do
			window[i] = 0.0
		end
	else
		for i = 1, #window + delta do
			window[i] = window[i - delta] or 0.0
		end
	end
	pain_handler.pain_window = window
end

--- sets the effect intensity curve to the given polyline
---@param points table A table of {x, y} points defining the curve, where x is the pain and y is the intensity
local function set_effect_intensity_curve(points)
	pain_handler.effect_intensity_curve = polylinelib.PolyLine(points)
end

--- shifts the pain window to the left by the given number of frames, filling new slots with zeros
--- @param delta number The number of frames to shift the window by
local function shift_pain_window(delta)
	if delta <= 0 then
		return
	end

	local window_size = #pain_handler.pain_window

	if delta >= window_size then
		delta = window_size
	end

	for i = 1, window_size - delta do
		pain_handler.pain_window[i] = pain_handler.pain_window[i + delta] or 0.0
	end
	for i = window_size - delta + 1, window_size do
		pain_handler.pain_window[i] = 0.0
	end
end

--- retrieves the player's current HP and max HP, returns nil if it fails to get them
---@return number|nil hp The player's current HP, or nil if it couldn't be retrieved
---@return number|nil max_hp The player's max HP, or nil if it couldn't be retrieved
local function get_player_hp_and_max_hp()
	local player_id = EntityGetWithTag("player_unit")[1]
	if not player_id then
		return nil, nil
	end

	local comp = EntityGetFirstComponentIncludingDisabled(player_id, "DamageModelComponent")

	if not comp then
		return 0.0, 1.0
	end

	local hp = ComponentGetValue2(comp, "hp")
	local max_hp = ComponentGetValue2(comp, "max_hp")
	return hp, max_hp
end

--- calculates and stores the pain from this frame into the pain window, and updates the last_hp and last_frame values
--- @param current_frame number The current frame number, used to calculate how much to shift the pain window and to store the last_frame value
local function store_current_pain(current_frame)
	local hp, max_hp = get_player_hp_and_max_hp()

	if max_hp ~= nil and max_hp > 0 and hp ~= nil and pain_handler.last_hp ~= nil then
		local hp_lost = pain_handler.last_hp - hp
		if hp_lost > 0 then
			local pain = hp_lost / max_hp
			pain_handler.pain_window[#pain_handler.pain_window] = (pain_handler.pain_window[#pain_handler.pain_window] or 0.0) +
				pain
		end
	end

	pain_handler.last_hp = hp
	pain_handler.last_frame = current_frame
end

--- calculates the intensity of the effect based on the current pain using the effect intensity curve, returns 0 if there is no curve or if pain is negligible
--- @param pain number The current pain value (0-1)
--- @return number The intensity of the effect (0-100)
local function calc_intensity(pain)
	if pain <= 0.01 then
		return 0.0
	end

	if not pain_handler.effect_intensity_curve then
		return 0.0
	end

	return pain_handler.effect_intensity_curve:get_y(pain * 100)
end

--- processes the current pain in the pain window, calculates the intensity, and sends a shock signal if the intensity is above a certain threshold, also updates the last_shock_frame if a shock is sent
---@param current_frame any
function process_pain(current_frame)
	local total_pain = 0.0
	for i = 1, #pain_handler.pain_window do
		total_pain = total_pain + (tonumber(pain_handler.pain_window[i]) or 0.0)
	end

	local intensity = calc_intensity(total_pain)
	if intensity > 0.001 then
		openshock.send_shock(intensity)
		pain_handler.last_shock_frame = current_frame
	end
end

--- the main update function to be called every frame, it checks if the handler is enabled, shifts the pain window, stores the current pain, and processes it
local function update_pain_handler()
	if not pain_handler.enabled then
		return
	end

	local current_frame = GameGetFrameNum()
	if current_frame - pain_handler.last_shock_frame < shock_cooldown_frames then
		return
	end

	shift_pain_window(current_frame - pain_handler.last_frame)
	store_current_pain(current_frame)
	process_pain(current_frame)
end

--- handles the player's death by sending a shock/vibrate signal with the configured intensity and duration
local function handle_death()
	local death_effect_intensity = tonumber(ModSettingGet("openshock_integration.death_effect_intensity")) or 100
	local death_effect_duration = tonumber(ModSettingGet("openshock_integration.death_effect_duration")) or 500
	openshock.send_shock(death_effect_intensity, death_effect_duration)
end

local pain_handler = {
	update = update_pain_handler,
	set_enabled = set_enabled,
	set_pain_window_size = set_pain_window_size,
	set_effect_intensity_curve = set_effect_intensity_curve,
	handle_death = handle_death,
	enabled = false,
	pain_window = nil,
	effect_intensity_curve = nil,
	last_frame = -math.huge,
	last_shock_frame = -math.huge,
	last_hp = 0.0
}

_G.pain_handler = pain_handler

return pain_handler
