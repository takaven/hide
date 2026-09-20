--!strict

local NearMissPolicy = {}

function NearMissPolicy.qualifies(config: any, duration: number, closestDistance: number): boolean
	return duration >= config.Hunter.NearMissMinimumChaseDuration
		and closestDistance <= config.Hunter.NearMissMaximumClosestDistance
end

return NearMissPolicy
