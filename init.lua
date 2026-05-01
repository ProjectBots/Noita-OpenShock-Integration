dofile_once("mods/openshock_integration/files/lib/pollnet.lua")
dofile_once("mods/openshock_integration/files/lib/openshock.lua")
dofile_once("mods/openshock_integration/files/scripts/pain_handler.lua")

local function apply_pain_window_size()
	local wsize = tonumber(ModSettingGet("openshock_integration.pain_window_size"))
	if not wsize then
		print("Invalid pain window size setting, using default (30)")
		wsize = 30
	end
	pain_handler.set_pain_window_size(wsize)
end

local function apply_pain_intensity_curve()
	local effect_intensity_curve = ModSettingGet("openshock_integration.effect_intensity_curve") --[[@as string]]
	local points = {}
	if effect_intensity_curve then
		for coord_pair in effect_intensity_curve:gmatch("[^;]+") do
			local x, y = coord_pair:match("(%d+),(%d+)")
			if x and y then
				table.insert(points, { x = tonumber(x), y = tonumber(y) })
			else
				print("Invalid coordinate pair in effect intensity curve: " .. coord_pair)
			end
		end
	end
	pain_handler.set_effect_intensity_curve(points)
end

local function apply_config_override()
	-- read config override from file, if it exists, and then reset it
	local config_file_path = "mods/openshock_integration/config_override.txt"
	local config_override_valid_keys = {
		["api_token"] = true,
		["hub_device_id"] = true,
		["device_id_1"] = true,
		["device_id_2"] = true,
		["device_id_3"] = true,
		["device_id_4"] = true,
		["effect_intensity_curve"] = true,
	}
	local file = io.open(config_file_path, "r")
	if file then
		local content = file:read("*a")
		-- split by lines and then by '=' to get key-value pairs
		for line in content:gmatch("[^\r\n]+") do
			local key, value = line:match("([^=]+)=([^=]+)")
			if key and value then
				key = key:match("^%s*(.-)%s*$") -- trim whitespace
				if not config_override_valid_keys[key] then
					print("Invalid config key in override file: " .. key)
					goto continue
				end
				key = "openshock_integration." .. key
				value = value:match("^%s*(.-)%s*$") -- trim whitespace
				print("Overriding config setting from file for " .. key)
				ModSettingSetNextValue(key, value, false)
			end
			::continue::
		end
		file:close()

		-- reset file
		file = io.open(config_file_path, "w")
		if file then
			for key, value in pairs(config_override_valid_keys) do
				file:write(key .. "=\n")
			end
			file:close()
		else
			print("Failed to clear config file.")
		end
	else
		print("No config file found, using default settings.")
	end
end

apply_config_override()

function OnModPreInit()
	apply_config_override()
end

function OnModPostInit()
	apply_pain_window_size()
	apply_pain_intensity_curve()
	openshock.recache_config()
end

function OnModSettingsChanged()
	apply_pain_window_size()
	apply_pain_intensity_curve()
	openshock.recache_config()
end

function OnWorldPostUpdate()
	local current_frame = GameGetFrameNum()
	pain_handler.update(current_frame)
	openshock.tick(current_frame)
end

function OnPlayerSpawned()
	pain_handler.set_enabled(true)
end

function OnPlayerDied()
	pain_handler.handle_death()
end

function OnPausedChanged(is_paused, is_inventory_pause)
	pain_handler.set_enabled(not is_paused)
end
