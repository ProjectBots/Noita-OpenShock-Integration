if (_G.pain_handler) then
	return _G.pain_handler
end

local utils = dofile_once("mods/openshock_integration/files/lib/utils.lua")

local PAIN_WINDOW_SIZE = 60      -- rolling window of pain in the last 60 frames (1 second)
local shock_cooldown_frames = 30 -- just to avoid spamming the API


local function set_enabled(enabled)
	pain_handler.enabled = enabled
end


local function new_pain_window()
	local window = {}
	for i = 1, PAIN_WINDOW_SIZE do
		window[i] = 0.0
	end
	return window
end


local function advance_pain_window(current_frame)
	local delta = current_frame - pain_handler.last_frame
	if delta <= 0 then
		return
	end

	if delta >= PAIN_WINDOW_SIZE then
		delta = PAIN_WINDOW_SIZE
	end

	for i = 1, PAIN_WINDOW_SIZE - delta do
		pain_handler.pain_window[i] = pain_handler.pain_window[i + delta] or 0.0
	end
	for i = PAIN_WINDOW_SIZE - delta + 1, PAIN_WINDOW_SIZE do
		pain_handler.pain_window[i] = 0.0
	end
end

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


local function calc_intensity(pain)
	if pain <= 0.01 then
		return 0.0
	end

	local intensity_min = tonumber(ModSettingGet("openshock_integration.effect_intensity_min"))
	local intensity_max = tonumber(ModSettingGet("openshock_integration.effect_intensity_max"))
	local intensity_50 = tonumber(ModSettingGet("openshock_integration.effect_intensity_50"))

	if pain >= 1.0 then
		return intensity_max
	end

	if pain >= 0.5 then
		return utils.interpolate(0.5, intensity_50, 1.0, intensity_max, pain)
	end

	return utils.interpolate(0.0, intensity_min, 0.5, intensity_50, pain)
end

local function update_pain_handler()
	if not pain_handler.enabled then
		return
	end

	local current_frame = GameGetFrameNum()
	if current_frame - pain_handler.last_shock_frame < shock_cooldown_frames then
		return
	end

	advance_pain_window(current_frame)

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

local pain_handler = {
	update = update_pain_handler,
	set_enabled = set_enabled,
	enabled = false,
	pain_window = new_pain_window(),
	last_frame = 0,
	last_shock_frame = -math.huge,
	last_hp = 0.0
}

_G.pain_handler = pain_handler

return pain_handler
