if (_G.openshock) then
	return _G.openshock
end

local url = "https://api.openshock.app/"

local json = dofile_once("mods/openshock_integration/files/lib/json.lua")

local reactor = netlib.Reactor()

--- updates the reactor, should be called every frame from the main mod loop
local function update_reactor()
	reactor:update()
end


--- awaits the socket, ensuring that the request was successful and that the response body can be read, returns the body or nil if there was an error
---@param socket table netlib.Socket
---@return string|nil
local function ensure_success_code(socket)
	local status, err1 = socket:await()
	if err1 then
		print("OpenShock request failed:", err1)
		return nil
	end

	status = string.sub(status, 1, 3)
	if status ~= "200" then
		print("OpenShock request failed with status:", status)
		return nil
	end

	local _, err2 = socket:await() -- ignore headers
	if err2 then
		print("Failed to read OpenShock response headers:", err2)
		return nil
	end

	local body, err3 = socket:await()
	if err3 then
		print("Failed to read OpenShock response body:", err3)
		return nil
	end

	return body or ""
end

--- sends a control signal to the OpenShock API
---@param type string The type of effect to send (e.g. "Shock", "Vibrate", "Stop")
---@param intensity number The intensity of the effect (0-100)
---@param duration number The duration of the effect in milliseconds
---@param exclusive boolean Whether this effect should be exclusive (i.e. stop any ongoing effects) or not
local function send_control_signal(type, intensity, duration, exclusive)
	if not openshock.cache.api_token or openshock.cache.api_token == "" then
		return
	end
	local shocker_ids = openshock.cache.devices
	if #shocker_ids == 0 then
		return
	end

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

	local req_sock = netlib.Socket():http_post(url .. "2/shockers/control", {
		["Content-Type"] = "application/json",
		["OpenShockToken"] = openshock.cache.api_token,
		["User-Agent"] = "Noita OpenShock Integration Mod"
	}, payload)

	reactor:run(function()
		local status, err = req_sock:await()
		if status then
			status = string.sub(status, 1, 3)
			if status ~= "200" then
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
	local effect_type = openshock.cache.effect_type
	-- capitalize first letter to match API expectations
	effect_type = effect_type:gsub("^%l", string.upper)
	send_control_signal(effect_type, intensity, duration, false)
end

--- fetches the lcg info for the hub from the OpenShock API and caches it
local function lcg()
	if not openshock.cache.api_token or openshock.cache.api_token == "" or not openshock.cache.hub_device_id or openshock.cache.hub_device_id == "" then
		print("API token or hub device ID not set, skipping OpenShock gateway fetch")
		return
	end

	local req_sock = netlib.Socket():http_get(url .. "1/devices/" .. openshock.cache.hub_device_id .. "/lcg", {
		["OpenShockToken"] = openshock.cache.api_token,
		["User-Agent"] = "Noita OpenShock Integration Mod"
	})

	reactor:run(function()
		local body = ensure_success_code(req_sock)
		if not body then
			return
		end
		local data = json.decode(body)
		local gateway = data and data.data and data.data.gateway
		if not gateway then
			print("Failed to get gateway from OpenShock response")
			return
		end

		if gateway ~= openshock.cache.gateway then
			print("Openshock Gateway changed to " .. gateway)
			openshock.cache.gateway = gateway
		end
	end)
end

--- opens the live control websocket connection to the OpenShock API and starts listening for messages, should be called when the mod is initialized or when the API token or hub device ID changes
local function open_live_control()
	if not openshock.cache.api_token or openshock.cache.api_token == "" then
		print("Cannot open live control page, API token not set")
		return
	end
	if not openshock.cache.hub_device_id or openshock.cache.hub_device_id == "" then
		print("Cannot open live control page, hub device ID not set")
		return
	end

	if openshock.cache.live_socket then
		print("Live control websocket already open")
		return
	end

	lcg()

	reactor:run(function()
		while true do
			if openshock.cache.gateway then
				break
			end
			coroutine.yield()
		end

		local sock = netlib.Socket():open_ws(
			"wss://" .. openshock.cache.gateway .. "/1/ws/live/" .. openshock.cache.hub_device_id, {
				["OpenShockToken"] = openshock.cache.api_token,
				["User-Agent"] = "Noita OpenShock Integration Mod"
			})

		openshock.cache.live_socket = sock

		while true do
			local msg, err = sock:await()
			if err then
				print("Live control websocket error:", err)
				break
			end

			local data = json.decode(msg)
			if not data or not data.ResponseType then
				print("Received invalid message on live control websocket:", msg)
				goto continue
			end
			local response_type = data.ResponseType

			if response_type == "TPS" then
				local tps = data.Data.Client
				print("Websocket: TPS update:", "" .. tps)
				openshock.cache.tps = tps
			elseif response_type == "DeviceConnected" then
				print("Websocket: Device connected")
			elseif response_type == "Ping" then
				local timestamp = data.Data.Timestamp
				local pong_msg = json.encode({ RequestType = "Pong", Data = { Timestamp = timestamp } })
				local ok, resp_err = pcall(function() sock:send(pong_msg) end)
				if not ok then
					print("Websocket: Failed to send Pong message over live websocket: " .. resp_err)
				end
			elseif response_type == "LatencyAnnounce" then
				local deviceLatency = data.Data.DeviceLatency
				local ownLatency = data.Data.OwnLatency
				print(string.format(
					"Websocket: Latency announcement received. Device latency: %d ms, Own latency: %d ms", deviceLatency,
					ownLatency))
			else
				print("Websocket: Received message with unknown ResponseType: " .. msg)
			end

			::continue::
		end

		-- clear stored socket when loop ends for any reason
		openshock.cache.live_socket = nil
	end)
end

--- closes the live control websocket from outside the reactor loop
local function close_live_control()
	local sock = openshock.cache.live_socket
	if not sock then
		print("No live control websocket to close")
		return
	end

	local ok, err = pcall(function() sock:close() end)
	if not ok then
		print("Failed to close live websocket:", err)
	else
		print("Closed live control websocket")
	end
end

--- sends a message over the live control websocket, if it's open, from outside the reactor loop
---@param message string The message to send, should be a JSON string in the format expected by the OpenShock live control API
local function send_live_control_message(message)
	local sock = openshock.cache.live_socket
	if not sock then
		print("No live control websocket to send message to")
		return
	end

	local ok, err = pcall(function() sock:send(message) end)
	if not ok then
		print("Failed to send message over live websocket:", err)
	end
end

--- sets the effect intensity for the live control
---@param intensity number The intensity to set, between 0 and 100
local function set_live_control_effect_intensity(intensity)
	intensity = math.floor(intensity)
	intensity = math.max(0, math.min(100, intensity))
	openshock.cache.current_intensity = intensity
end

--- updates the underlying reactor and websocket connection, should be called every frame from the main mod loop
--- will transmit the current effect intensity to the live control websocket if it's open, throttled by TPS to avoid spamming
--- @param current_frame number The current frame number
local function tick(current_frame)
	local tps = openshock.cache.tps
	local intensity = openshock.cache.current_intensity
	-- intensity = 0 is equal to the absence of messages
	if openshock.cache.live_socket and intensity > 0 and tps > 0 and (current_frame - openshock.cache.last_shock_frame) * tps > 60 then
		for i = 1, #openshock.cache.devices do
			local device_id = openshock.cache.devices[i]
			if device_id then
				send_live_control_message(json.encode({
					RequestType = "Frame",
					Data = {
						Shocker = device_id,
						Intensity = intensity,
						Type = openshock.cache.effect_type
					}
				}))
			end
		end
	end

	update_reactor()
end

--- caches the config values from the mod settings into the openshock cache
local function recache_config()
	openshock.cache.api_token = ModSettingGet("openshock_integration.api_token") --[[@as string]]
	openshock.cache.hub_device_id = ModSettingGet("openshock_integration.hub_device_id") --[[@as string]]
	openshock.cache.devices = {} -- reset device cache

	for i = 1, 4 do
		local device_id = ModSettingGet("openshock_integration.device_id_" .. i) --[[@as string]]
		if device_id and device_id ~= "" then
			table.insert(openshock.cache.devices, device_id)
		end
	end

	local effect_shock = ModSettingGet("openshock_integration.effect_shock") --[[@as boolean]]
	openshock.cache.effect_type = effect_shock and "shock" or "vibrate"
end

local openshock = {
	update_reactor = update_reactor,
	tick = tick,
	recache_config = recache_config,
	send_shock = send_shock,
	open_live_control = open_live_control,
	close_live_control = close_live_control,
	set_live_control_effect_intensity = set_live_control_effect_intensity,
	cache = {
		api_token = nil,
		devices = {},
		effect_type = nil,
		hub_device_id = nil,
		gateway = nil,
		live_socket = nil,
		tps = -1,
		current_intensity = 0,
		last_shock_frame = -math.huge,
	}
}

_G.openshock = openshock

return openshock
