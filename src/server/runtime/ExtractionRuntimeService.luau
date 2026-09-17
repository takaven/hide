--!strict

local Players = game:GetService("Players")

local ExtractionRuntimeService = {}
ExtractionRuntimeService.__index = ExtractionRuntimeService

function ExtractionRuntimeService.new(
	hiding: any,
	playerStates: any,
	presentation: any,
	remotes: any
)
	return setmetatable({
		_hiding = hiding,
		_playerStates = playerStates,
		_presentation = presentation,
		_remotes = remotes,
	}, ExtractionRuntimeService)
end

function ExtractionRuntimeService:BeginExtraction(now: number)
	for _, hidingId in ipairs(self._hiding:GetSpotIds()) do
		for _, playerId in ipairs(self._hiding:GetOccupants(hidingId)) do
			self._presentation:RevealById(playerId, hidingId)
			self._hiding:Exit(playerId, hidingId)
			self._playerStates:Transition(playerId, "Active", "extraction forced relocation", now)
			local player = Players:GetPlayerByUserId(tonumber(playerId) or 0)
			if player ~= nil then
				self._remotes.StateSnapshot:FireClient(player, {
					state = "Active",
					clearContext = true,
					forceExtraction = true,
				})
			end
		end
	end
end

return ExtractionRuntimeService
