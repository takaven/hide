--!strict

local SharedSilence = {}

local function clamp(value: number, minimum: number, maximum: number): number
	return math.max(minimum, math.min(maximum, value))
end

function SharedSilence.evaluate(
	occupancy: number,
	recentNoise: number,
	movementFactor: number,
	heat: number,
	config: any
): any
	assert(occupancy >= 0 and occupancy % 1 == 0, "occupancy must be a non-negative integer")

	local occupancyRisk = if occupancy == 0
		then 0
		else config.BaseRisk + math.max(0, occupancy - 1) * config.AdditionalOccupantRisk
	local noiseRisk = clamp(recentNoise, 0, 1) * config.RecentNoiseWeight
	local movementRisk = clamp(movementFactor, 0, 1) * config.MovementRisk
	local heatRisk = clamp(heat, 0, 1) * config.HeatWeight
	local risk = clamp(occupancyRisk + noiseRisk + movementRisk + heatRisk, 0, 1)

	local state = "Safe"
	if risk >= config.BreakThreshold then
		state = "Broken"
	elseif risk >= config.UnstableThreshold then
		state = "Unstable"
	elseif risk >= config.WarningThreshold then
		state = "Warning"
	end

	return {
		risk = risk,
		state = state,
		occupancyRisk = occupancyRisk,
		noiseRisk = noiseRisk,
		movementRisk = movementRisk,
		heatRisk = heatRisk,
	}
end

return SharedSilence
