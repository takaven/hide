--!strict

local HighlightTracker = {}
HighlightTracker.__index = HighlightTracker

local SCORE = {
	near_miss = 8,
	rescue_completed = 7,
	silence_broken = 6,
	entry_refused = 3,
	player_downed = 5,
	brace_door_used = 4,
	player_escaped = 7,
	movie_moment = 4,
	hiding_exited = 2,
}

local LABEL = {
	near_miss = "Closest Call",
	rescue_completed = "Best Rescue",
	silence_broken = "Most Crowded Hide",
	entry_refused = "Hard Choice",
	player_downed = "The Listener Found Them",
	brace_door_used = "Door Hero",
	player_escaped = "Final Escape",
	movie_moment = "Movie Moment",
	hiding_exited = "Longest Hidden",
}

local POSITIVE_AWARDS = {
	["Closest Call"] = true,
	["Best Rescue"] = true,
	["Door Hero"] = true,
	["Final Escape"] = true,
	["Longest Hidden"] = true,
}

function HighlightTracker.new()
	local self: any = setmetatable({ _moments = {}, _sequence = 0 }, HighlightTracker)
	return self
end

function HighlightTracker:ResetRound()
	self._moments = {}
	self._sequence = 0
end

function HighlightTracker:Observe(envelope: any)
	local score = SCORE[envelope.name]
	if score == nil then
		return
	end
	self._sequence += 1
	table.insert(self._moments, {
		kind = envelope.name,
		label = LABEL[envelope.name],
		score = score,
		sequence = self._sequence,
		properties = table.clone(envelope.properties),
	})
end

function HighlightTracker:MomentOfRound(): any?
	local best: any? = nil
	for _, moment in ipairs(self._moments) do
		if
			best == nil
			or moment.score > best.score
			or (moment.score == best.score and moment.sequence > best.sequence)
		then
			best = moment
		end
	end
	return if best then table.clone(best) else nil
end

function HighlightTracker:BuildAwards(): { any }
	local awards = {}
	local seen = {}
	for _, moment in ipairs(self._moments) do
		local playerId = moment.properties.playerId or moment.properties.rescuerId
		if playerId ~= nil and POSITIVE_AWARDS[moment.label] and seen[moment.label] == nil then
			seen[moment.label] = true
			table.insert(awards, { title = moment.label, playerId = tostring(playerId) })
		end
	end
	return awards
end

return HighlightTracker
