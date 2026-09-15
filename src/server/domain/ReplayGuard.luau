--!strict

local ReplayGuard = {}
ReplayGuard.__index = ReplayGuard

function ReplayGuard.new(windowSeconds: number)
	return setmetatable({ _windowSeconds = windowSeconds, _seen = {} }, ReplayGuard)
end

function ReplayGuard:Accept(subjectId: string, requestId: string, now: number): (boolean, string?)
	local records = self._seen[subjectId] or {}
	for id, timestamp in pairs(records) do
		if now - timestamp > self._windowSeconds then
			records[id] = nil
		end
	end
	if records[requestId] ~= nil then
		return false, "duplicate request"
	end
	records[requestId] = now
	self._seen[subjectId] = records
	return true, nil
end

return ReplayGuard
