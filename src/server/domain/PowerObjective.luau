--!strict

local PowerObjective = {}
PowerObjective.__index = PowerObjective

function PowerObjective.new(config: any)
	return setmetatable({
		_config = config,
		_state = "Stable",
		_completedBy = nil,
		_completedAt = nil,
	}, PowerObjective)
end

function PowerObjective:GetState(): string
	return self._state
end

function PowerObjective:BeginBlackout(): boolean
	if self._state ~= "Stable" then
		return false
	end
	self._state = "Blackout"
	return true
end

function PowerObjective:Complete(playerId: string, now: number): (any?, string?)
	if self._state ~= "Blackout" then
		return nil, "fuse is not active"
	end
	self._state = "Emergency"
	self._completedBy = playerId
	self._completedAt = now
	return {
		state = self._state,
		playerId = playerId,
		noiseMagnitude = self._config.Fuse.NoiseMagnitude,
	},
		nil
end

function PowerObjective:GetCompletion(): any?
	if self._completedBy == nil then
		return nil
	end
	return { playerId = self._completedBy, completedAt = self._completedAt }
end

function PowerObjective:ResetRound()
	self._state = "Stable"
	self._completedBy = nil
	self._completedAt = nil
end

return PowerObjective
