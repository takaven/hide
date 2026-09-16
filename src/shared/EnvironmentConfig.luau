--!strict

local EnvironmentConfig = {}

function EnvironmentConfig.resolve(
	config: any,
	requestedName: any,
	humanOnlyOverride: boolean?
): (string, any)
	local profiles = config.Environment.Profiles
	local name = if type(requestedName) == "string" and profiles[requestedName] ~= nil
		then requestedName
		else config.Environment.Default
	local profile = table.clone(profiles[name])
	if humanOnlyOverride == true then
		profile.AIGuestsEnabled = false
		profile.HumanOnly = true
	end
	return name, profile
end

return EnvironmentConfig
