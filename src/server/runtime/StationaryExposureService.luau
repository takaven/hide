--!strict

local Players = game:GetService("Players")
local StationaryPressure = require(script.Parent.Parent.domain.StationaryPressure)

local StationaryExposureService = {}
StationaryExposureService.__index = StationaryExposureService

function StationaryExposureService.new(
	config: any,
	playerStates: any,
	noise: any,
	analytics: any,
	remotes: any
)
	return setmetatable({
		_config = config,
		_playerStates = playerStates,
		_noise = noise,
		_analytics = analytics,
		_remotes = remotes,
		_pressure = StationaryPressure.new(config.FreeformPressure),
	}, StationaryExposureService)
end

function StationaryExposureService:ResetRound()
	self._pressure:ResetRound()
	for _, player in ipairs(Players:GetPlayers()) do
		self._remotes.StateSnapshot:FireClient(player, {
			freeformPressure = { stage = "Clear", duration = 0 },
		})
	end
end

function StationaryExposureService:Tick(now: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local playerId = tostring(player.UserId)
		local state = self._playerStates:Get(playerId)
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local horizontal = Vector3.new(
				root.AssemblyLinearVelocity.X,
				0,
				root.AssemblyLinearVelocity.Z
			).Magnitude
			local pressure = self._pressure:Observe(
				playerId,
				now,
				state == "Active" or state == "Rescued",
				horizontal >= self._config.FreeformPressure.MovementThreshold
			)
			if pressure ~= nil then
				self._remotes.StateSnapshot:FireClient(player, {
					freeformPressure = {
						stage = pressure.stage,
						duration = pressure.duration,
					},
				})
				if pressure.emitEvidence then
					self._noise:Add({
						origin = root.Position,
						magnitude = pressure.magnitude,
						category = "Environment",
						sourcePlayerId = playerId,
						sourceId = `storm-exposure-{playerId}`,
						hunterRelevant = true,
					}, now)
				end
				self._analytics:Emit("freeform_stationary_pressure", {
					playerId = playerId,
					duration = pressure.duration,
					stage = pressure.stage,
					evidenceEmitted = pressure.emitEvidence,
				}, now)
			end
		end
	end
end

return StationaryExposureService
