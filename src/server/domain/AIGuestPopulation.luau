--!strict

local AIGuestPopulation = {}

function AIGuestPopulation.desiredCount(config: any, profile: any, humanCount: number): number
	if profile.AIGuestsEnabled ~= true or profile.HumanOnly == true then
		return 0
	end
	local shortfall = math.max(0, config.AIGuests.TargetParticipants - humanCount)
	return math.min(config.AIGuests.MaximumGuests, shortfall)
end

function AIGuestPopulation.participantKind(participantId: string): string
	return if string.sub(participantId, 1, 9) == "ai-guest-" then "AI" else "Human"
end

return AIGuestPopulation
