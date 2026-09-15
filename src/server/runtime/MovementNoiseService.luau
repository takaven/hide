--!strict

local Players = game:GetService("Players")

local MovementNoiseService = {}
MovementNoiseService.__index = MovementNoiseService

function MovementNoiseService.new(config: any, playerStates: any, noise: any, analytics: any)
	return setmetatable({
		_config = config,
		_playerStates = playerStates,
		_noise = noise,
		_analytics = analytics,
		_lastEmission = {},
	}, MovementNoiseService)
end

function MovementNoiseService:_surfaceMultiplier(humanoid: Humanoid): number
	local name = humanoid.FloorMaterial.Name
	return self._config.MovementNoise.SurfaceMultipliers[name]
		or self._config.MovementNoise.SurfaceMultipliers.Default
end

function MovementNoiseService:Tick(now: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local playerId = tostring(player.UserId)
		local state = self._playerStates:Get(playerId)
		if state == "Active" or state == "Rescued" then
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if root and root:IsA("BasePart") and humanoid then
				local horizontal = Vector3.new(
					root.AssemblyLinearVelocity.X,
					0,
					root.AssemblyLinearVelocity.Z
				).Magnitude
				local interval = self._config.MovementNoise.EmissionInterval
				local previous = self._lastEmission[playerId] or -math.huge
				if
					horizontal >= self._config.MovementNoise.MinimumSpeed
					and now - previous >= interval
				then
					local sprintAlpha = math.clamp(
						(horizontal - self._config.MovementNoise.MinimumSpeed)
							/ (
								self._config.MovementNoise.SpeedForMaximum
								- self._config.MovementNoise.MinimumSpeed
							),
						0,
						1
					)
					local magnitude = (
						self._config.MovementNoise.BaseMagnitude
						+ sprintAlpha * self._config.MovementNoise.SpeedMagnitude
					) * self:_surfaceMultiplier(humanoid)
					self._noise:Add({
						origin = root.Position,
						magnitude = magnitude,
						category = "Footstep",
						sourcePlayerId = playerId,
						sourceId = `movement-{playerId}`,
						hunterRelevant = true,
					}, now)
					self._lastEmission[playerId] = now
				end
			end
		end
	end
end

function MovementNoiseService:ResetRound()
	table.clear(self._lastEmission)
end

return MovementNoiseService
