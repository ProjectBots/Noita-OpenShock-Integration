if (_G.openshock) then
	return _G.openshock
end

local url = "https://api.openshock.app/2/shockers/control"

local json = dofile_once("mods/openshock_integration/files/lib/json.lua")

local reactor = netlib.Reactor()

--- updates the underlying reactor, should be called once per frame in the main loop to process any pending API requests
local function update_reactor()
	reactor:update()
end


--- recaches the config values from the mod settings into the openshock cache for faster access
local function recache_config()
	openshock.cache.api_token = ModSettingGet("openshock_integration.api_token") --[[@as string]]
	openshock.cache.devices = { nil, nil, nil, nil } -- reset device cache

	for i = 1, 4 do
		local device_id = ModSettingGet("openshock_integration.device_id_" .. i) --[[@as string]]
		if device_id and device_id ~= "" then
			openshock.cache.devices[i] = device_id
		end
	end

	local effect_shock = ModSettingGet("openshock_integration.effect_shock") --[[@as boolean]]
	openshock.cache.effect_type = effect_shock and "Shock" or "Vibrate"
	openshock.cache.effect_duration = ModSettingGet("openshock_integration.effect_duration") --[[@as number]]
end

--- sends a control signal to the OpenShock API
---@param type string The type of effect to send (e.g. "Shock", "Vibrate", "Stop")
---@param intensity number The intensity of the effect (0-100)
---@param duration number The duration of the effect in milliseconds
---@param exclusive boolean Whether this effect should be exclusive (i.e. stop any ongoing effects) or not
---@param shockers number[]? Optional list of shocker numbers (1-4) to send the signal to, if not specified, it will be sent to all configured shockers
local function send_control_signal(type, intensity, duration, exclusive, shockers)
	if not openshock.cache.api_token or openshock.cache.api_token == "" then
		return
	end

	if not shockers then
		shockers = { 1, 2, 3, 4 }
	end

	local shocker_ids = {}
	for _, shocker_num in ipairs(shockers) do
		local shocker_id = openshock.cache.devices[shocker_num]
		if shocker_id then
			table.insert(shocker_ids, shocker_id)
		end
	end
	if #shocker_ids == 0 then
		return
	end

	print(string.format("Sending control signal: type=%s, intensity=%d, duration=%d, exclusive=%s, ids=%s",
		type, intensity, duration, tostring(exclusive), table.concat(shocker_ids, ", ")))

	local shocks = {}
	for _, shocker_id in ipairs(shocker_ids) do
		table.insert(shocks, {
			id = shocker_id,
			type = type,
			intensity = math.floor(intensity),
			duration = duration,
			exclusive = exclusive or false
		})
	end

	local payload = json.encode({
		shocks = shocks
	})

	local req_sock = netlib.Socket():http_post(url, {
		["Content-Type"] = "application/json",
		["OpenShockToken"] = openshock.cache.api_token,
		["User-Agent"] = "Noita OpenShock Integration Mod"
	}, payload)

	reactor:run(function()
		local status, err = req_sock:await()
		if status then
			status = string.sub(status, 1, 3)
			if status == "200" then
				print("Shock signal sent successfully!")
			else
				print("OpenShock request failed with status:", status)
			end
		else
			print("OpenShock request failed:", err)
		end
	end)
end

--- sends a shock signal to the OpenShock API
---@param intensity number
---@param duration number?
local function send_shock(intensity, duration)
	duration = duration or openshock.cache.effect_duration or 500
	send_control_signal(openshock.cache.effect_type, intensity, duration, false)
end

--- sends a stop signal to the OpenShock API to stop any ongoing effects
local function send_stop()
	send_control_signal("Stop", 0, 1000, true)
end

local openshock = {
	update_reactor = update_reactor,
	send_shock = send_shock,
	send_stop = send_stop,
	recache_config = recache_config,
	cache = {
		api_token = nil,
		devices = {},
		effect_type = nil,
		effect_duration = nil,
	}
}

_G.openshock = openshock

return openshock
