--!strict

local PrototypeRecap = {}
PrototypeRecap.__index = PrototypeRecap

function PrototypeRecap.new()
	return setmetatable({ _events = {} }, PrototypeRecap)
end

function PrototypeRecap:ResetRound()
	self._events = {}
end

function PrototypeRecap:Observe(envelope: any)
	local properties = envelope.properties or {}
	local breakDuration = tonumber(properties.timeToFirstBreak)
	local function participant(value: any): string
		return if value ~= nil then `Player {tostring(value)}` else "A survivor"
	end
	local message = if envelope.name == "entry_accepted"
		then `{participant(properties.admittedBy)} let {participant(properties.playerId)} in.`
		elseif
			envelope.name == "entry_refused"
		then `{participant(properties.refusedBy)} refused {participant(
			properties.playerId
		)}.`
		elseif
			envelope.name == "volunteered_out"
		then `{participant(properties.playerId)} volunteered to run.`
		elseif
			envelope.name == "forced_exit"
		then `{participant(properties.evictedBy)} forced {participant(
			properties.evictedPlayerId
		)} out.`
		elseif
			envelope.name == "draw_used"
		then `{participant(properties.playerId)} drew The Listener away.`
		elseif
			envelope.name == "breath_broken"
			and breakDuration ~= nil
			and breakDuration > 0
		then `A shelter broke after {math.floor(breakDuration)} seconds.`
		elseif
			envelope.name == "player_escaped"
		then `{participant(properties.playerId)} escaped the storm.`
		elseif
			envelope.name == "player_eliminated"
		then `{participant(properties.playerId)} was left behind.`
		else nil
	if message ~= nil then
		table.insert(self._events, message)
	end
end

function PrototypeRecap:BuildLines(): { string }
	local lines = {}
	for index = math.max(1, #self._events - 4), #self._events do
		if self._events[index] ~= nil then
			table.insert(lines, self._events[index])
		end
	end
	if #lines == 0 then
		table.insert(lines, "The shelters held. This time.")
	end
	return lines
end

return PrototypeRecap
