--!strict

local ParticipantMetrics = {}

function ParticipantMetrics.kind(participantId: string): string
	if string.sub(participantId, 1, 9) == "ai-guest-" then
		return "AI"
	end
	return "Human"
end

function ParticipantMetrics.countResults(
	participantIds: { string },
	getState: (string) -> string?
): { [string]: number }
	local counts = {
		escaped = 0,
		eliminated = 0,
		survivors = 0,
		aiEscaped = 0,
		aiEliminated = 0,
		aiSurvivors = 0,
	}

	for _, participantId in ipairs(participantIds) do
		local state = getState(participantId)
		local prefix = if ParticipantMetrics.kind(participantId) == "AI" then "ai" else ""
		if state == "Escaped" then
			local key = if prefix == "ai" then "aiEscaped" else "escaped"
			counts[key] += 1
		elseif state == "Eliminated" then
			local key = if prefix == "ai" then "aiEliminated" else "eliminated"
			counts[key] += 1
		elseif state ~= "Spectating" then
			local key = if prefix == "ai" then "aiSurvivors" else "survivors"
			counts[key] += 1
		end
	end

	return counts
end

return ParticipantMetrics
