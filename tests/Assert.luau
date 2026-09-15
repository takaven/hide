--!strict

local Assert = {}

function Assert.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`,
			2
		)
	end
end

function Assert.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function Assert.falsy(value: any, message: string?)
	if value then
		error(message or "expected a falsy value", 2)
	end
end

function Assert.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{message or "values are not near"}: expected {expected}, got {actual}`, 2)
	end
end

function Assert.contains(value: string?, fragment: string, message: string?)
	if value == nil or string.find(value, fragment, 1, true) == nil then
		error(
			`{message or "string missing fragment"}: expected {tostring(value)} to contain {fragment}`,
			2
		)
	end
end

return Assert
