# Noita OpenShock Integration

A small mod integration for Noita that provides a more immersive experience for players with OpenShock devices by sending shock/vibrate commands to the OpenShock API when certain events happen in the game, such as taking damage or dying.

## Installation

1. Download the latest release from the releases tab
2. Copy the contents of the zip file to your Noita mods folder (usually located at `C:\Program Files (x86)\Steam\steamapps\common\Noita\mods`)
3. Start Noita and enable the "OpenShock Integration" mod in the mod menu

## Notes

Edit `config_override.txt` to skip Noita's limited mod settings UI and set the config values directly. This is recommended since some of the config values are quite long and unwieldy to edit through the in-game UI.

## Build from source

1. Clone the repository
2. Run `copy-project.ps1 -Destination "Path/To/Noita/mods/openshock_integration"` to copy the project files to your Noita mods folder (respects .copyignore)
3. Start Noita and enable the "OpenShock Integration" mod in the mod menu

## Credits
- ProjectBots - Coding
- Conga Lyne - Project Template (Fungal Pain mod)
- probable-basilisk - pollnet (Lua library for networking)

## License

See [LICENSE](LICENSE)
