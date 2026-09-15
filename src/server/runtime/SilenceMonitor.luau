--!strict

local Players = game:GetService("Players")

local SilenceMonitor = {}
SilenceMonitor.__index = SilenceMonitor

function SilenceMonitor.new(hiding: any, noise: any, analytics: any, remotes: any?)
	return setmetatable({
		_hiding = hiding,
		_noise = noise,
		_analytics = analytics,
		_lastStates = {},
		_lastRisk = {},
		_remotes = remotes,
	}, SilenceMonitor)
end

function SilenceMonitor:ResetRound()
	self._lastStates = {}
	self._lastRisk = {}
end

function SilenceMonitor:_movementFactor(hidingId: string): number
	local maximum = 0
	for _, playerId in ipairs(self._hiding:GetOccupants(hidingId)) do
		local userId = tonumber(playerId)
		local player = if userId then Players:GetPlayerByUserId(userId) else nil
		local character = if player then player.Character else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			maximum = math.max(maximum, math.min(1, root.AssemblyLinearVelocity.Magnitude / 12))
		end
	end
	return maximum
end

function SilenceMonitor:Tick(elapsed: number, now: number)
	for _, request in ipairs(self._hiding:PruneExpired(now)) do
		self._analytics:Emit("entry_request_expired", {
			playerId = request.playerId,
			hidingId = request.hidingId,
		}, now)
	end
	for _, hidingId in ipairs(self._hiding:GetSpotIds()) do
		local spot = self._hiding:GetSpot(hidingId)
		local result = self._hiding:Tick(hidingId, elapsed, now, self:_movementFactor(hidingId))
		if spot ~= nil and result ~= nil then
			local previous = self._lastStates[hidingId]
			local previousRisk = self._lastRisk[hidingId]
			self._lastStates[hidingId] = result.state
			self._lastRisk[hidingId] = result.risk
			if
				self._remotes ~= nil
				and (
					previous ~= result.state
					or previousRisk == nil
					or math.abs(previousRisk - result.risk) >= 0.04
				)
			then
				for _, occupantId in ipairs(self._hiding:GetOccupants(hidingId)) do
					local userId = tonumber(occupantId)
					local occupant = if userId then Players:GetPlayerByUserId(userId) else nil
					if occupant ~= nil then
						self._remotes.StateSnapshot:FireClient(occupant, {
							silence = {
								state = result.state,
								risk = result.risk,
								occupancy = self._hiding:GetOccupancy(hidingId),
								capacity = spot.capacity,
								heat = self._hiding:GetHeat(hidingId, now),
								exposed = self._hiding:IsExposed(hidingId, now),
							},
						})
					end
				end
			end
			if
				(result.state == "Warning" or result.state == "Unstable")
				and previous ~= "Warning"
				and previous ~= "Unstable"
				and previous ~= "Broken"
			then
				self._analytics:Emit(
					"silence_warning",
					{ hidingId = hidingId, risk = result.risk },
					now
				)
			elseif result.state == "Broken" and previous ~= "Broken" then
				self._hiding:ApplySilenceState(hidingId, result.state, previous, now)
				self._noise:Add({
					origin = spot.position,
					magnitude = 1,
					category = "FailedSilence",
					sourceId = hidingId,
					hunterRelevant = true,
				}, now)
				self._analytics:Emit(
					"silence_broken",
					{ hidingId = hidingId, risk = result.risk },
					now
				)
			end
		end
	end
end

return SilenceMonitor
