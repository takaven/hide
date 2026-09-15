--!strict

local WeightedChoice = {}

function WeightedChoice.select(
	weights: { [string]: number },
	roll: number,
	excluded: string?
): string?
	local total = 0
	for name, weight in pairs(weights) do
		if name ~= excluded and weight > 0 then
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local cursor = math.clamp(roll, 0, 0.999999) * total
	local names = {}
	for name in pairs(weights) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local weight = if name == excluded then 0 else weights[name]
		if weight > 0 then
			if cursor < weight then
				return name
			end
			cursor -= weight
		end
	end
	return nil
end

return WeightedChoice
