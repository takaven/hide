--!strict

local RematchCoordinator = {}
RematchCoordinator.__index = RematchCoordinator

function RematchCoordinator.new(config: any)
	local self: any =
		setmetatable({ _config = config, _requests = {}, _restartAt = nil }, RematchCoordinator)
	return self
end

function RematchCoordinator:ResetRound()
	self._requests = {}
	self._restartAt = nil
end

function RematchCoordinator:Request(playerId: string, now: number): (any?, string?)
	if self._requests[playerId] then
		return nil, "rematch already requested"
	end
	self._requests[playerId] = true
	if self:GetRequestCount() >= self._config.Rematch.MinimumRequests then
		self._restartAt = self._restartAt or now + self._config.Rematch.ResultsRestartDelay
	end
	return { status = "Requested", restartAt = self._restartAt }, nil
end

function RematchCoordinator:GetRequestCount(): number
	local count = 0
	for _ in pairs(self._requests) do
		count += 1
	end
	return count
end

function RematchCoordinator:ShouldRestart(now: number): boolean
	return self._restartAt ~= nil and now >= self._restartAt
end

return RematchCoordinator
