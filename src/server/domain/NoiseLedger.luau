--!strict

local NoiseLedger = {}
NoiseLedger.__index = NoiseLedger

local function copyPosition(position: any): any
	if type(position) == "table" then
		return { x = position.x, y = position.y, z = position.z }
	end
	return position
end

local function finiteNonNegative(value: any): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

function NoiseLedger.new(config: any)
	return setmetatable({
		_config = config,
		_events = {},
		_nextId = 0,
	}, NoiseLedger)
end

function NoiseLedger:Add(input: any, now: number): (any?, string?)
	if type(input) ~= "table" then
		return nil, "noise input must be a table"
	end
	if self._config.Categories[input.category] == nil then
		return nil, "unknown noise category"
	end
	if not finiteNonNegative(input.magnitude) or input.magnitude > 1 then
		return nil, "magnitude must be between 0 and 1"
	end
	if input.origin == nil then
		return nil, "origin is required"
	end

	local decay = input.decaySeconds or self._config.DefaultDecaySeconds
	if not finiteNonNegative(decay) or decay <= 0 then
		return nil, "decaySeconds must be positive"
	end

	self._nextId += 1
	local event = {
		id = `noise-{self._nextId}`,
		origin = copyPosition(input.origin),
		magnitude = input.magnitude,
		category = input.category,
		timestamp = now,
		decaySeconds = decay,
		sourcePlayerId = input.sourcePlayerId,
		sourceId = input.sourceId,
		falseEvidence = input.falseEvidence == true,
		hunterRelevant = input.hunterRelevant ~= false,
	}
	table.insert(self._events, event)
	return event, nil
end

function NoiseLedger.DecayedMagnitude(event: any, now: number): number
	local age = math.max(0, now - event.timestamp)
	if age >= event.decaySeconds then
		return 0
	end
	return event.magnitude * (1 - age / event.decaySeconds)
end

function NoiseLedger:GetEvidence(now: number): { any }
	local output = {}
	local retained = {}

	for _, event in ipairs(self._events) do
		local age = math.max(0, now - event.timestamp)
		if age <= self._config.MaxAgeSeconds then
			table.insert(retained, event)
			local magnitude = NoiseLedger.DecayedMagnitude(event, now)
			if event.hunterRelevant and magnitude > 0 then
				table.insert(output, {
					id = event.id,
					origin = copyPosition(event.origin),
					magnitude = magnitude,
					category = event.category,
					timestamp = event.timestamp,
					falseEvidence = event.falseEvidence,
					score = magnitude * self._config.Categories[event.category],
				})
			end
		end
	end

	self._events = retained
	return output
end

return NoiseLedger
