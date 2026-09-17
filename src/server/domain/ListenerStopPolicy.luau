--!strict

local ListenerStopPolicy = {}

function ListenerStopPolicy.canStart(input: any): boolean
	return input.brainState ~= "CHASE"
		and input.now >= input.drawCommitUntil
		and input.occupancy > 0
		and input.distance <= input.radius
		and input.now >= input.cooldownUntil
end

return ListenerStopPolicy
