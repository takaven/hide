--!strict

local BreathPressure = {}

function BreathPressure.rateForOccupancy(occupancy: number, config: any): number
	if occupancy <= 0 then
		return 0
	end
	local index = math.min(occupancy, #config.OccupancyMultipliers)
	return config.BaseRatePerSecond * config.OccupancyMultipliers[index]
end

function BreathPressure.state(level: number, config: any): string
	if level >= config.Maximum then
		return "Broken"
	elseif level >= config.CriticalThreshold then
		return "Critical"
	elseif level >= config.WarningThreshold then
		return "Warning"
	end
	return "Calm"
end

function BreathPressure.advance(
	level: number,
	occupancy: number,
	elapsed: number,
	pressureMultiplier: number,
	config: any
): any
	local baseRate = BreathPressure.rateForOccupancy(occupancy, config)
	local rate = baseRate * math.max(1, pressureMultiplier)
	local nextLevel = if occupancy > 0
		then math.min(config.Maximum, level + rate * math.max(0, elapsed))
		else math.max(0, level - config.EmptyDecayPerSecond * math.max(0, elapsed))
	return {
		level = nextLevel,
		rate = rate,
		state = BreathPressure.state(nextLevel, config),
	}
end

return BreathPressure
