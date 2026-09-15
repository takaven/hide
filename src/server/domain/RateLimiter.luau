--!strict

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(rules: any)
	return setmetatable({ _rules = rules, _events = {} }, RateLimiter)
end

function RateLimiter:Allow(subjectId: string, action: string, now: number): (boolean, string?)
	local rule = self._rules[action]
	if rule == nil then
		return false, "action has no rate-limit policy"
	end
	local key = `{subjectId}:{action}`
	local previous = self._events[key] or {}
	local retained = {}
	for _, timestamp in ipairs(previous) do
		if now - timestamp < rule.WindowSeconds then
			table.insert(retained, timestamp)
		end
	end
	if #retained >= rule.Limit then
		self._events[key] = retained
		return false, "rate limit exceeded"
	end
	table.insert(retained, now)
	self._events[key] = retained
	return true, nil
end

return RateLimiter
