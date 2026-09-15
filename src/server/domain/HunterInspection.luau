--!strict

local HunterInspection = {}

function HunterInspection.Inspect(
	hiding: any,
	capture: any,
	hidingId: string,
	now: number
): { string }
	local discovered = {}
	for _, playerId in ipairs(hiding:GetDiscoverableOccupants(hidingId, now)) do
		local captured = capture:Down(playerId, now, "spot_inspection")
		if captured then
			table.insert(discovered, playerId)
		end
	end
	return discovered
end

return HunterInspection
