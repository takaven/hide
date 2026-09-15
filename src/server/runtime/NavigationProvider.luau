--!strict

local NavigationProvider = {}

function NavigationProvider.validate(provider: any): (boolean, string?)
	if type(provider) ~= "table" then
		return false, "navigation provider must be a table"
	end
	for _, method in ipairs({ "MoveTo", "Cancel", "GetStatus" }) do
		if type(provider[method]) ~= "function" then
			return false, `navigation provider is missing {method}`
		end
	end
	local ok, status, generation = pcall(provider.GetStatus, provider)
	if not ok or type(status) ~= "string" or type(generation) ~= "number" then
		return false, "navigation provider status must include a numeric movement generation"
	end
	return true, nil
end

return NavigationProvider
