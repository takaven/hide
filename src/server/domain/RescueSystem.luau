--!strict

local RescueSystem = {}
RescueSystem.__index = RescueSystem

function RescueSystem.new(config: any)
	return setmetatable({ _config = config, _attempts = {}, _nextId = 0 }, RescueSystem)
end

function RescueSystem:ResetRound()
	self._attempts = {}
	self._nextId = 0
end

function RescueSystem:Get(attemptId: string): any?
	return self._attempts[attemptId]
end

function RescueSystem:Start(
	rescuerId: string,
	targetId: string,
	now: number,
	distance: number,
	rescuerState: string?,
	targetState: string?
): (any?, string?)
	if rescuerId == targetId then
		return nil, "players cannot rescue themselves"
	end
	if rescuerState ~= "Active" and rescuerState ~= "Rescued" then
		return nil, "rescuer is not able to act"
	end
	if targetState ~= "Downed" then
		return nil, "target is not downed"
	end
	if distance > self._config.Rescue.MaxDistance then
		return nil, "target is too far away"
	end
	for _, attempt in pairs(self._attempts) do
		if attempt.targetId == targetId and attempt.status == "InProgress" then
			return nil, "target already has a rescue in progress"
		end
	end

	self._nextId += 1
	local attempt = {
		id = `rescue-{self._nextId}`,
		rescuerId = rescuerId,
		targetId = targetId,
		startedAt = now,
		readyAt = now + self._config.Rescue.Duration,
		status = "InProgress",
	}
	self._attempts[attempt.id] = attempt
	return attempt, nil
end

function RescueSystem:Complete(
	rescuerId: string,
	attemptId: string,
	now: number,
	distance: number,
	rescuerState: string?,
	targetState: string?
): (any?, string?)
	local attempt = self._attempts[attemptId]
	if attempt == nil or attempt.status ~= "InProgress" then
		return nil, "rescue is not in progress"
	end
	if attempt.rescuerId ~= rescuerId then
		return nil, "only the original rescuer can complete this rescue"
	end
	if now < attempt.readyAt then
		return nil, "rescue duration has not elapsed"
	end
	if distance > self._config.Rescue.MaxDistance then
		attempt.status = "Cancelled"
		return nil, "players moved too far apart"
	end
	if rescuerState ~= "Active" and rescuerState ~= "Rescued" then
		attempt.status = "Cancelled"
		return nil, "rescuer can no longer act"
	end
	if targetState ~= "Downed" then
		attempt.status = "Cancelled"
		return nil, "target is no longer downed"
	end

	attempt.status = "Completed"
	return {
		status = "Completed",
		rescueId = attemptId,
		targetId = attempt.targetId,
		noiseMagnitude = self._config.Rescue.Noise,
	},
		nil
end

return RescueSystem
