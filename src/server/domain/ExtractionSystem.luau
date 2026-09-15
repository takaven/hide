--!strict

local ExtractionSystem = {}
ExtractionSystem.__index = ExtractionSystem

function ExtractionSystem.new(config: any)
	return setmetatable(
		{ _config = config, _points = {}, _openedAt = nil, _closedAt = nil },
		ExtractionSystem
	)
end

function ExtractionSystem:ResetRound()
	self._openedAt = nil
	self._closedAt = nil
end

function ExtractionSystem:Register(extractionId: string, position: any): (boolean, string?)
	if type(extractionId) ~= "string" or extractionId == "" then
		return false, "invalid extraction id"
	end
	if self._points[extractionId] ~= nil then
		return false, "extraction point already registered"
	end
	self._points[extractionId] = { id = extractionId, position = position }
	return true, nil
end

function ExtractionSystem:Get(extractionId: string): any?
	return self._points[extractionId]
end

function ExtractionSystem:Open(now: number)
	self._openedAt = now
	self._closedAt = now + self._config.Extraction.OpenDuration
end

function ExtractionSystem:IsOpen(now: number): boolean
	return self._openedAt ~= nil and now >= self._openedAt and now <= self._closedAt
end

function ExtractionSystem:Escape(
	playerId: string,
	extractionId: string,
	now: number,
	distance: number,
	playerState: string?
): (any?, string?)
	if not self:IsOpen(now) then
		return nil, "extraction is closed"
	end
	if self._points[extractionId] == nil then
		return nil, "unknown extraction point"
	end
	if playerState ~= "Active" and playerState ~= "Rescued" then
		return nil, "player cannot escape from current state"
	end
	if distance > self._config.Extraction.MaxDistance then
		return nil, "extraction point is too far away"
	end
	return { status = "Escaped", playerId = playerId, extractionId = extractionId }, nil
end

return ExtractionSystem
