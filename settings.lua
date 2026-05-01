dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "openshock_integration"

function mod_setting_change_callback(mod_id_, gui, in_main_menu, setting, old_value, new_value)
	print(tostring(new_value))
end

mod_settings_version = 1

mod_settings = {
	{
		ui_name = "The annoyingly long values can be set through the\n config override file inside the mod folder!",
		---@diagnostic disable-next-line: undefined-global
		ui_fn = mod_setting_title,
	},
	{
		id = "api_token",
		ui_name = "OpenShock API Token",
		ui_description = "Your OpenShock API token. You can find this in the OpenShock app under 'Api Tokens'.",
		value_default = "",
		text_max_length = 128,
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "hub_device_id",
		ui_name = "OpenShock Hub Device ID",
		ui_description =
		"The ID of the hub device that all your other devices are connected to. This is required for the mod to work. You can find this in the OpenShock app under 'Hubs > Device > Edit > Id'.",
		value_default = "",
		text_max_length = 50,
		allowed_characters = "0123456789abcdef-",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "device_id_1",
		ui_name = "OpenShock Device ID 1",
		ui_description =
		"The ID of the first device you want to control. You can find this in the OpenShock app under 'Shockers > Device > Edit > Id'.",
		value_default = "",
		text_max_length = 50,
		allowed_characters = "0123456789abcdef-",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "device_id_2",
		ui_name = "OpenShock Device ID 2",
		ui_description =
		"The ID of the second device you want to control. You can find this in the OpenShock app under 'Shockers > Device > Edit > Id'.",
		value_default = "",
		text_max_length = 50,
		allowed_characters = "0123456789abcdef-",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "device_id_3",
		ui_name = "OpenShock Device ID 3",
		ui_description =
		"The ID of the third device you want to control. You can find this in the OpenShock app under 'Shockers > Device > Edit > Id'.",
		value_default = "",
		text_max_length = 50,
		allowed_characters = "0123456789abcdef-",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "device_id_4",
		ui_name = "OpenShock Device ID 4",
		ui_description =
		"The ID of the fourth device you want to control. You can find this in the OpenShock app under 'Shockers > Device > Edit > Id'.",
		value_default = "",
		text_max_length = 50,
		allowed_characters = "0123456789abcdef-",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "effect_shock",
		ui_name = "Shock?",
		ui_description = "Wether to send shock or vibrate signals.",
		value_default = true,
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "effect_intensity_curve",
		ui_name = "Effect Intensity Curve",
		ui_description =
		"Defines how the intensity of the effect scales with the amount of pain. The first number in each pair is the pain (0-100) (%of hp lost in window) and the second number is the intensity (0-100). For example, '0,0; 0.5,50; 1,100' means that at 0% pain the effect is 0% intense, at 50% pain the effect is 50% intense, and at 100% pain the effect is 100% intense. You can add as many points as you want to create a custom curve. Points are interpolated linearly, so in the previous example 25% pain would result in 25% intensity.",
		value_default = "0,0; 1,0; 2,20; 30,50; 50,80; 90,100; 100,100",
		text_max_length = 1000,
		allowed_characters = "0123456789.,; ",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "pain_window_size",
		ui_name = "Pain Window Size (frames)",
		ui_description =
		"The number of frames over which to accumulate pain. A larger window will result in stronger effects for many small hits over time. It will also affect the duration of the effect, since pain in the window will continue to trigger the effect until it falls out of the window after the specified number of frames.",
		value_default = "30",
		text_max_length = 4,
		allowed_characters = "0123456789",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "death_effect_intensity",
		ui_name = "Death Effect Intensity",
		ui_description = "The intensity of the effect to trigger on death.",
		value_default = "100",
		text_max_length = 3,
		allowed_characters = "0123456789",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "death_effect_duration",
		ui_name = "Death Effect Duration (ms)",
		ui_description = "The duration of the effect to trigger on death in milliseconds.",
		value_default = "500",
		text_max_length = 10,
		allowed_characters = "0123456789",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	}
}

function ModSettingsUpdate(init_scope)
	---@diagnostic disable-next-line: undefined-global
	local old_version = mod_settings_get_version(mod_id)
	---@diagnostic disable-next-line: undefined-global
	mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
	---@diagnostic disable-next-line: undefined-global
	return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
	---@diagnostic disable-next-line: undefined-global
	mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end
