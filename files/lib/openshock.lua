if (_G.openshock) then
	return _G.openshock
end

local url = "https://api.openshock.app/2/shockers/control"


local json = dofile_once("mods/openshock_integration/files/lib/json.lua")

local reactor = netlib.Reactor()

local function get_shock_type()
	local shock = ModSettingGet("openshock_integration.effect_shock")
	return shock and "Shock" or "Vibrate"
end

local function update_reactor()
	reactor:update()
end

---comment
---@param type string
---@param intensity number
---@param duration number
---@param exclusive boolean
local function send_control_signal(type, intensity, duration, exclusive)
	local openShockToken = ModSettingGet("openshock_integration.api_token")
	local shocker_id = ModSettingGet("openshock_integration.device_id")
	print(string.format("Sending control signal: id=%s, type=%s, intensity=%d, duration=%d, exclusive=%s", shocker_id,
		type, intensity, duration, tostring(exclusive)))

	local payload = json.encode({
		shocks = { {
			id = shocker_id,
			type = type,
			intensity = math.floor(intensity),
			duration = duration,
			exclusive = exclusive or false
		} }
	})

	local req_sock = netlib.Socket():http_post(url, {
		["Content-Type"] = "application/json",
		["OpenShockToken"] = openShockToken,
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

---comment
---@param intensity number
local function send_shock(intensity)
	local type = get_shock_type()
	local duration = ModSettingGet("openshock_integration.effect_duration") --[[@as number]]
	send_control_signal(type, intensity, duration, false)
end

local function send_stop()
	send_control_signal("Stop", 0, 1000, true)
end

local openshock = {
	update_reactor = update_reactor,
	send_shock = send_shock,
	send_stop = send_stop
}

_G.openshock = openshock

return openshock
