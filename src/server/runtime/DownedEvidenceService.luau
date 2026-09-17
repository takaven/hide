--!strict

local Players = game:GetService("Players")

local DownedEvidenceService = {}
DownedEvidenceService.__index = DownedEvidenceService

function DownedEvidenceService.new(config: any, playerStates: any, noise: any)
	return setmetatable({
		_config = config,
		_playerStates = playerStates,
		_noise = noise,
		_lastEmission = {},
	}, DownedEvidenceService)
end

function DownedEvidenceService:Tick(now: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local playerId = tostring(player.UserId)
		if self._playerStates:Get(playerId) == "Downed" then
			local previous = self._lastEmission[playerId] or -math.huge
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if
				root ~= nil
				and root:IsA("BasePart")
				and now - previous >= self._config.Rescue.DownedEvidenceInterval
			then
				self._noise:Add({
					origin = root.Position,
					magnitude = self._config.Rescue.DownedEvidenceMagnitude,
					category = "Environment",
					sourcePlayerId = playerId,
					sourceId = `downed-{playerId}`,
					hunterRelevant = true,
				}, now)
				self._lastEmission[playerId] = now
			end
		else
			self._lastEmission[playerId] = nil
		end
	end
end

function DownedEvidenceService:ResetRound()
	table.clear(self._lastEmission)
end

return DownedEvidenceService
