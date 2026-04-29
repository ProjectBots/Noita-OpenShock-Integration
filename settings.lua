dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "openshock_integration"

function mod_setting_change_callback(mod_id, gui, in_main_menu, setting, old_value, new_value)
	print(tostring(new_value))
end

mod_settings_version = 1

mod_settings = {
	{
		id = "api_token",
		ui_name = "OpenShock API Token",
		ui_description = "Your OpenShock API token. You can find this in the OpenShock app under 'Api Tokens'.",
		value_default = "",
		text_max_length = 128,
		allowed_characters = "0123456789abcdefABCDEFGHIJKLMNOPQRSTUVWXYZ",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "device_id",
		ui_name = "OpenShock Device ID",
		ui_description =
		"The ID of the device you want to control. You can find this in the OpenShock app under 'Shockers > Device > Edit > Id'.",
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
		id = "effect_duration",
		ui_name = "Effect Duration (ms)",
		ui_description = "The duration of the effect in milliseconds.",
		value_default = "500",
		value_display_formatting = " $0 ms",
		text_max_length = 10,
		allowed_characters = "0123456789",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "effect_intensity_min",
		ui_name = "Minimum Effect Intensity",
		ui_description = "The minimum intensity of the effect (0-100).",
		value_default = "10",
		value_display_formatting = " $0%",
		text_max_length = 3,
		allowed_characters = "0123456789",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "effect_intensity_max",
		ui_name = "Maximum Effect Intensity",
		ui_description = "The maximum intensity of the effect (0-100).",
		value_default = "70",
		value_display_formatting = " $0%",
		text_max_length = 3,
		allowed_characters = "0123456789",
		---@diagnostic disable-next-line: undefined-global
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "effect_intensity_50",
		ui_name = "Intensity at loosing 50% HP",
		ui_description = "The intensity of the effect when loosing 50% HP (0-100).",
		value_default = "50",
		value_display_formatting = " $0%",
		text_max_length = 3,
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
