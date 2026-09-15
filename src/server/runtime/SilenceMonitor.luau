--!strict

local Players = game:GetService("Players")

local SilenceMonitor = {}
SilenceMonitor.__index = SilenceMonitor

function SilenceMonitor.new(hiding: any, noise: any, analytics: any)
	return setmetatable({
		_hiding = hiding,
		_noise = noise,
		_analytics = analytics,
		_lastStates = {},
	}, SilenceMonitor)
end

function SilenceMonitor:ResetRound()
	self._lastStates = {}
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
	for _, hidingId in ipairs(self._hiding:GetSpotIds()) do
		local spot = self._hiding:GetSpot(hidingId)
		local result = self._hiding:Tick(hidingId, elapsed, now, self:_movementFactor(hidingId))
		if spot ~= nil and result ~= nil then
			local previous = self._lastStates[hidingId]
			self._lastStates[hidingId] = result.state
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
