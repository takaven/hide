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
		local previous = self._players[playerId]
		self._players[playerId] = nil
		return if previous ~= nil
			then { stage = "Clear", changed = true, duration = 0, emitEvidence = false }
			else nil
	end
	local record = self._players[playerId]
	if record == nil then
		record = { stationarySince = now, lastEvidenceAt = -math.huge, stage = "Settling" }
		self._players[playerId] = record
		return { stage = "Settling", changed = true, duration = 0, emitEvidence = false }
	end
	local duration = now - record.stationarySince
	local stage = if duration >= self._config.GraceSeconds
		then "Danger"
		elseif duration >= self._config.CueSeconds then "Exposed"
		else "Settling"
	local changed = stage ~= record.stage
	record.stage = stage
	local emitEvidence = stage == "Danger"
		and now - record.lastEvidenceAt >= self._config.EvidenceInterval
	if emitEvidence then
		record.lastEvidenceAt = now
	end
	return if changed or emitEvidence
		then {
			stage = stage,
			changed = changed,
			duration = duration,
			emitEvidence = emitEvidence,
			magnitude = if emitEvidence then self._config.EvidenceMagnitude else 0,
		}
		else nil
end

return StationaryPressure
