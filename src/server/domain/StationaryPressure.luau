--!strict

local StationaryPressure = {}
StationaryPressure.__index = StationaryPressure

function StationaryPressure.new(config: any)
	return setmetatable({ _config = config, _players = {} }, StationaryPressure)
end

function StationaryPressure:ResetRound()
	self._players = {}
end

function StationaryPressure:Observe(
	playerId: string,
	now: number,
	isEligible: boolean,
	isMoving: boolean
): any?
	if not isEligible or isMoving then
		self._players[playerId] = nil
		return nil
	end
	local record = self._players[playerId]
	if record == nil then
		record = { stationarySince = now, lastEvidenceAt = -math.huge }
		self._players[playerId] = record
	end
	local duration = now - record.stationarySince
	if
		duration >= self._config.GraceSeconds
		and now - record.lastEvidenceAt >= self._config.EvidenceInterval
	then
		record.lastEvidenceAt = now
		return { duration = duration, magnitude = self._config.EvidenceMagnitude }
	end
	return nil
end

return StationaryPressure
