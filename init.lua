dofile_once("mods/openshock_integration/files/lib/pollnet.lua")
dofile_once("mods/openshock_integration/files/lib/openshock.lua")
dofile_once("mods/openshock_integration/files/scripts/pain_handler.lua")


function OnWorldPostUpdate()
	pain_handler.update()
	openshock.update_reactor()
end

function OnPlayerSpawned()
	pain_handler.set_enabled(true)
end

function OnPausedChanged(is_paused, is_inventory_pause)
	if is_paused then
		pain_handler.set_enabled(false)
		openshock.send_stop()
	else
		pain_handler.set_enabled(true)
	end
end
