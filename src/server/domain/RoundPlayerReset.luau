--!strict

local RoundPlayerReset = {}

function RoundPlayerReset.plan(state: string?, characterAlive: boolean): any
	return {
		state = "Active",
		clearTerminalPresentation = state == "Eliminated"
			or state == "Escaped"
			or state == "Spectating",
		placement = if characterAlive then "ArrivalSpawn" else "ReloadCharacter",
		allowCaptureSideEffect = false,
	}
end

return RoundPlayerReset
