--!strict

local RescueSystem = {}
RescueSystem.__index = RescueSystem

local function rescuerEligible(state: string?): boolean
	return state == "Active" or state == "Rescued"
end

function RescueSystem.new(config: any)
	local self: any = setmetatable({ _config = config, _attempts = {}, _nextId = 0 }, RescueSystem)
	return self
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
	if not rescuerEligible(rescuerState) then
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
	local readyAt = now + self._config.Rescue.Duration
	local attempt = {
		id = `rescue-{self._nextId}`,
		rescuerId = rescuerId,
		targetId = targetId,
		startedAt = now,
		readyAt = readyAt,
		expiresAt = readyAt + self._config.Rescue.CompletionGraceSeconds,
		outOfRangeSince = nil,
		status = "InProgress",
	}
	self._attempts[attempt.id] = attempt
	return attempt, nil
end

function RescueSystem:_cancel(attempt: any, reason: string, now: number): any
	attempt.status = "Cancelled"
	attempt.cancelReason = reason
	attempt.cancelledAt = now
	return attempt
end

function RescueSystem:CancelByPlayer(playerId: string, reason: string, now: number): { any }
	local cancelled = {}
	for _, attempt in pairs(self._attempts) do
		if
			attempt.status == "InProgress"
			and (attempt.rescuerId == playerId or attempt.targetId == playerId)
		then
			table.insert(cancelled, self:_cancel(attempt, reason, now))
		end
	end
	return cancelled
end

function RescueSystem:Cancel(
	attemptId: string,
	rescuerId: string,
	reason: string,
	now: number
): boolean
	local attempt = self._attempts[attemptId]
	if attempt == nil or attempt.status ~= "InProgress" or attempt.rescuerId ~= rescuerId then
		return false
	end
	self:_cancel(attempt, reason, now)
	return true
end

function RescueSystem:Tick(now: number, statusProvider: (any) -> any): { any }
	local cancelled = {}
	for _, attempt in pairs(self._attempts) do
		if attempt.status == "InProgress" then
			local context = statusProvider(attempt)
			local reason = nil
			if context.rescuerConnected ~= true then
				reason = "rescuer disconnected"
			elseif context.targetConnected ~= true then
				reason = "target disconnected"
			elseif not rescuerEligible(context.rescuerState) then
				reason = "rescuer can no longer act"
			elseif context.targetState ~= "Downed" then
				reason = "target is no longer downed"
			elseif now > attempt.expiresAt then
				reason = "rescue completion window expired"
			elseif
				type(context.distance) ~= "number"
				or context.distance > self._config.Rescue.MaxDistance
			then
				if attempt.outOfRangeSince == nil then
					attempt.outOfRangeSince = now
				end
				if now - attempt.outOfRangeSince >= self._config.Rescue.RangeGraceSeconds then
					reason = "players remained too far apart"
				end
			else
				attempt.outOfRangeSince = nil
			end
			if reason ~= nil then
				table.insert(cancelled, self:_cancel(attempt, reason, now))
			end
		end
	end
	return cancelled
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
	if now > attempt.expiresAt then
		self:_cancel(attempt, "rescue completion window expired", now)
		return nil, "rescue completion window expired"
	end
	if distance > self._config.Rescue.MaxDistance then
		self:_cancel(attempt, "players moved too far apart", now)
		return nil, "players moved too far apart"
	end
	if not rescuerEligible(rescuerState) then
		self:_cancel(attempt, "rescuer can no longer act", now)
		return nil, "rescuer can no longer act"
	end
	if targetState ~= "Downed" then
		self:_cancel(attempt, "target is no longer downed", now)
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
