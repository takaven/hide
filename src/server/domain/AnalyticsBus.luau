--!strict

local AnalyticsBus = {}
AnalyticsBus.__index = AnalyticsBus

local ALLOWED_EVENTS = {
	round_started = true,
	round_completed = true,
	player_hid = true,
	shared_hiding_started = true,
	entry_requested = true,
	entry_accepted = true,
	entry_refused = true,
	silence_warning = true,
	silence_broken = true,
	hunter_investigated = true,
	hunter_found_player = true,
	player_downed = true,
	rescue_attempted = true,
	rescue_completed = true,
	player_eliminated = true,
	decoy_used = true,
	extraction_started = true,
	player_escaped = true,
	player_quit = true,
}

function AnalyticsBus.new(provider: any?)
	return setmetatable({ _provider = provider, _buffer = {} }, AnalyticsBus)
end

function AnalyticsBus:Emit(
	eventName: string,
	properties: any,
	timestamp: number
): (boolean, string?)
	if ALLOWED_EVENTS[eventName] ~= true then
		return false, "unknown analytics event"
	end
	local envelope = {
		name = eventName,
		properties = if type(properties) == "table" then table.clone(properties) else {},
		timestamp = timestamp,
		schemaVersion = 1,
	}
	if self._provider ~= nil then
		local ok, err = pcall(self._provider.Emit, self._provider, envelope)
		if not ok then
			return false, `analytics provider failed: {tostring(err)}`
		end
	else
		table.insert(self._buffer, envelope)
	end
	return true, nil
end

function AnalyticsBus:GetBuffered(): { any }
	return table.clone(self._buffer)
end

return AnalyticsBus
