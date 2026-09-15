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
	return true, nil
end

return NavigationProvider
